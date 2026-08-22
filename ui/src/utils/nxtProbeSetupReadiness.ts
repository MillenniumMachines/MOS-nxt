/**
 * Probe / toolsetter setup readiness for Calibration Phase 0.
 * Surfaces config + OM conditions that block or fake-stall M5016 / T{probe}.
 */

import { NXT_PROBE_TOOL_ID } from './nxtProbeToolId'
import { readFirmwareGlobal } from './nxtToolChangerOm'
import { getProbeByIndex } from './nxtProbeOm'
import { readConfigBool, readConfigNumber, readConfigVector } from './nxtUserVarsPersistence'

export type NxtProbeReadinessSeverity = 'error' | 'warning'

export type NxtProbeReadinessItem = {
  id: string
  ok: boolean
  severity: NxtProbeReadinessSeverity
  /** Locale key under plugins.nxt.panels.calibration.* */
  messageKey: string
}

export type NxtProbeReadinessResult = {
  items: NxtProbeReadinessItem[]
  /** Hard fails that should disable Run M5016 */
  blockM5016: boolean
  /** Hard fails + missing G6511 preflight that should disable Enable Probe */
  blockEnableProbe: boolean
  /** messageKey values for items blocking Enable Probe (for UI list) */
  blockEnableProbeReasons: string[]
}

const DELTA_CONSISTENCY_MM = 0.05

function isTouchProbeType(type: unknown): boolean {
  const n = typeof type === 'number' ? type : Number(type)
  return Number.isFinite(n) && n >= 5 && n <= 8
}

function probeAt(probes: unknown, id: number): { type?: unknown } | null {
  const p = getProbeByIndex(probes as Parameters<typeof getProbeByIndex>[0], id)
  return p != null ? (p as { type?: unknown }) : null
}

function toolExists(tools: unknown, id: number): boolean {
  if (tools == null || id < 0) return false
  if (Array.isArray(tools)) {
    return tools[id] != null
  }
  if (typeof tools === 'object' && tools !== null && 'at' in tools) {
    const at = (tools as { at: (i: number) => unknown }).at
    if (typeof at === 'function') {
      return at.call(tools, id) != null
    }
  }
  const o = tools as Record<string, unknown>
  return (o[String(id)] ?? o[id as unknown as string]) != null
}

function axesAllHomed(axes: unknown): boolean | null {
  if (!Array.isArray(axes) || axes.length === 0) return null
  for (let i = 0; i < axes.length; i++) {
    const a = axes[i] as { homed?: boolean; visible?: boolean } | null
    if (a == null) continue
    if (a.visible === false) continue
    if (a.homed !== true) return false
  }
  return true
}

function finiteVec3(v: number[] | null): boolean {
  return (
    v != null &&
    v.length >= 3 &&
    Number.isFinite(v[0]) &&
    Number.isFinite(v[1]) &&
    Number.isFinite(v[2])
  )
}

export type NxtProbeReadinessInput = {
  globalOm: unknown
  probes?: unknown
  tools?: unknown
  axes?: unknown
}

/**
 * Build ordered readiness checklist. Callers translate messageKey via i18n.
 */
export function assessNxtProbeSetupReadiness(input: NxtProbeReadinessInput): NxtProbeReadinessResult {
  const g = input.globalOm
  const items: NxtProbeReadinessItem[] = []

  const featTp = readConfigBool(readFirmwareGlobal(g, 'nxtFeatureTouchProbe'))
  const featTs = readConfigBool(readFirmwareGlobal(g, 'nxtFeatureToolSetter'))
  items.push({
    id: 'featureTouchProbe',
    ok: featTp,
    severity: 'error',
    messageKey: featTp ? 'readyFeatureTouchProbeOk' : 'readyFeatureTouchProbeFail'
  })
  items.push({
    id: 'featureToolSetter',
    ok: featTs,
    severity: 'error',
    messageKey: featTs ? 'readyFeatureToolSetterOk' : 'readyFeatureToolSetterFail'
  })

  const touchId = readConfigNumber(readFirmwareGlobal(g, 'nxtTouchProbeID'))
    ?? readConfigNumber(readFirmwareGlobal(g, 'nxtTPID'))
  const setterId = readConfigNumber(readFirmwareGlobal(g, 'nxtToolSetterID'))
    ?? readConfigNumber(readFirmwareGlobal(g, 'nxtTSID'))
  const touchProbe = touchId != null ? probeAt(input.probes, touchId) : null
  const setterProbe = setterId != null ? probeAt(input.probes, setterId) : null

  // M5016 aborts if nxtTouchProbeID is null, but does not use the tip sensor.
  const touchIdConfigured = touchId != null
  items.push({
    id: 'touchProbeId',
    ok: touchIdConfigured,
    severity: 'error',
    messageKey: touchIdConfigured ? 'readyTouchProbeIdOk' : 'readyTouchProbeIdFail'
  })

  // Live tip slot / type are Enable Probe + tip-wait only (after datum).
  const touchSlotOk = touchIdConfigured && touchProbe != null
  items.push({
    id: 'touchProbeSlot',
    ok: touchSlotOk,
    severity: 'error',
    messageKey: touchSlotOk ? 'readyTouchProbeSlotOk' : 'readyTouchProbeSlotFail'
  })
  if (touchSlotOk) {
    const typeOk = isTouchProbeType(touchProbe!.type)
    items.push({
      id: 'touchProbeType',
      ok: typeOk,
      severity: 'error',
      messageKey: typeOk ? 'readyTouchProbeTypeOk' : 'readyTouchProbeTypeFail'
    })
  }

  const setterIdOk = setterId != null && setterProbe != null
  items.push({
    id: 'toolSetterId',
    ok: setterIdOk,
    severity: 'error',
    messageKey: setterIdOk ? 'readyToolSetterIdOk' : 'readyToolSetterIdFail'
  })
  if (setterIdOk) {
    const typeOk = isTouchProbeType(setterProbe!.type)
    items.push({
      id: 'toolSetterType',
      ok: typeOk,
      severity: 'warning',
      messageKey: typeOk ? 'readyToolSetterTypeOk' : 'readyToolSetterTypeFail'
    })
  }

  // Probe tool slot index (T{nxtProbeToolID}) — row may be created on first sync/T.
  const probeToolId =
    readConfigNumber(readFirmwareGlobal(g, 'nxtProbeToolID'))
    ?? readConfigNumber(readFirmwareGlobal(g, 'mosPTID'))
    ?? NXT_PROBE_TOOL_ID
  const probeToolIdOk = probeToolId === NXT_PROBE_TOOL_ID
  items.push({
    id: 'probeToolId',
    ok: probeToolIdOk,
    severity: 'error',
    messageKey: probeToolIdOk ? 'readyProbeToolIdOk' : 'readyProbeToolIdFail'
  })
  if (probeToolIdOk) {
    const probeRowOk = toolExists(input.tools, NXT_PROBE_TOOL_ID)
    items.push({
      id: 'probeToolRow',
      ok: probeRowOk,
      severity: 'warning',
      messageKey: probeRowOk ? 'readyProbeToolRowOk' : 'readyProbeToolRowFail'
    })
  }

  const setterPos = readConfigVector(readFirmwareGlobal(g, 'nxtToolSetterPos'))
  const refPos = readConfigVector(readFirmwareGlobal(g, 'nxtTouchProbeRefPos'))
  const delta = readConfigNumber(readFirmwareGlobal(g, 'nxtDeltaMachine'))
  const virt = readConfigNumber(readFirmwareGlobal(g, 'nxtProbeVirtualTsZ'))

  const setterPosOk = finiteVec3(setterPos)
  const refPosOk = finiteVec3(refPos)
  const deltaOk = delta != null
  const virtOk = virt != null

  items.push({
    id: 'toolSetterPos',
    ok: setterPosOk,
    severity: 'warning',
    messageKey: setterPosOk ? 'readyToolSetterPosOk' : 'readyToolSetterPosFail'
  })
  items.push({
    id: 'touchProbeRefPos',
    ok: refPosOk,
    severity: 'warning',
    messageKey: refPosOk ? 'readyTouchProbeRefPosOk' : 'readyTouchProbeRefPosFail'
  })
  items.push({
    id: 'deltaMachine',
    ok: deltaOk,
    severity: 'warning',
    messageKey: deltaOk ? 'readyDeltaMachineOk' : 'readyDeltaMachineFail'
  })
  items.push({
    id: 'probeVirtualTsZ',
    ok: virtOk,
    severity: 'warning',
    messageKey: virtOk ? 'readyProbeVirtualOk' : 'readyProbeVirtualFail'
  })

  if (setterPosOk && refPosOk && deltaOk) {
    const expected = refPos![2] - setterPos![2]
    const mismatch = Math.abs(expected - (delta as number)) > DELTA_CONSISTENCY_MM
    items.push({
      id: 'deltaConsistency',
      ok: !mismatch,
      severity: 'warning',
      messageKey: mismatch ? 'readyDeltaConsistencyFail' : 'readyDeltaConsistencyOk'
    })
  }

  const tcCancel = readFirmwareGlobal(g, 'nxtToolChangeCancelled')
  const tcCancelOn = tcCancel === true || tcCancel === 1
  items.push({
    id: 'toolChangeCancelled',
    ok: !tcCancelOn,
    severity: 'error',
    messageKey: tcCancelOn ? 'readyToolChangeCancelledFail' : 'readyToolChangeCancelledOk'
  })

  const tcState = readFirmwareGlobal(g, 'nxtToolChangeState')
  const tcIdle = tcState == null || tcState === undefined
  items.push({
    id: 'toolChangeState',
    ok: tcIdle,
    severity: 'error',
    messageKey: tcIdle ? 'readyToolChangeStateOk' : 'readyToolChangeStateFail'
  })

  const homed = axesAllHomed(input.axes)
  if (homed !== null) {
    items.push({
      id: 'axesHomed',
      ok: homed,
      severity: 'error',
      messageKey: homed ? 'readyAxesHomedOk' : 'readyAxesHomedFail'
    })
  }

  items.push({
    id: 'liveSensorHint',
    ok: true,
    severity: 'warning',
    messageKey: 'readyLiveSensorHint'
  })

  const hardError = (id: string): boolean => {
    const it = items.find((x: NxtProbeReadinessItem) => x.id === id)
    return it != null && !it.ok && it.severity === 'error'
  }

  // M5016: features, configured touch ID, live toolsetter, axes/TC idle.
  // Tip slot/type and probe tool are not used until Enable Probe after datum.
  const blockM5016 =
    hardError('featureTouchProbe') ||
    hardError('featureToolSetter') ||
    hardError('touchProbeId') ||
    hardError('toolSetterId') ||
    hardError('toolChangeCancelled') ||
    hardError('toolChangeState') ||
    hardError('axesHomed')

  const g6511Ready = refPosOk && deltaOk
  const blockEnableProbe =
    hardError('featureTouchProbe') ||
    hardError('touchProbeId') ||
    hardError('touchProbeSlot') ||
    hardError('touchProbeType') ||
    hardError('probeToolId') ||
    hardError('toolChangeCancelled') ||
    hardError('toolChangeState') ||
    hardError('axesHomed') ||
    !g6511Ready

  const blockEnableProbeReasons: string[] = []
  for (const it of items) {
    if (it.ok) continue
    if (it.severity === 'error') {
      const blocks =
        (it.id === 'featureTouchProbe') ||
        (it.id === 'touchProbeId') ||
        (it.id === 'touchProbeSlot') ||
        (it.id === 'touchProbeType') ||
        (it.id === 'probeToolId') ||
        (it.id === 'toolChangeCancelled') ||
        (it.id === 'toolChangeState') ||
        (it.id === 'axesHomed')
      if (blocks) blockEnableProbeReasons.push(it.messageKey)
    }
  }
  if (!g6511Ready) {
    blockEnableProbeReasons.push('readyDatumG6511Fail')
  }

  return { items, blockM5016, blockEnableProbe, blockEnableProbeReasons }
}
