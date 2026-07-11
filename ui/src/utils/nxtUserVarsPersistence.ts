/**
 * nxt Configuration panel — nxt-user-vars.g persistence helpers.
 */
import { migratePlatformProfileId } from './nxtBoardManifest'
import { readFirmwareGlobal } from './nxtToolChangerOm'

export type NxtUserConfigDraft = {
  nxtFeatureTouchProbe: boolean
  nxtFeatureToolSetter: boolean
  nxtFeatureCoolantControl: boolean
  nxtFeatureRgbLight: boolean
  nxtFeatureFourthAxis: boolean
  nxtRgbLedIndex: number | null
  nxtProbeToolID: number | null
  nxtDeltaMachine: number | null
  nxtSpindleID: number | null
  nxtSpindleAccelSec: number | null
  nxtSpindleDecelSec: number | null
  nxtTouchProbeID: number | null
  nxtTouchProbeInvert: boolean
  nxtProbeTipRadius: number | null
  nxtProbeDeflection: number | null
  nxtToolSetterID: number | null
  nxtToolSetterInvert: boolean
  nxtToolSetterPos: number[] | null
  nxtTouchProbeRefPos: number[] | null
  nxtCoolantAirID: number | null
  nxtCoolantMistID: number | null
  nxtCoolantFloodID: number | null
  nxtCoolantMistPulseEnabled: boolean
  nxtCoolantFloodPulseEnabled: boolean
  nxtCoolantPulseOnSec: number
  nxtCoolantPulseOffSec: number
  nxtRelayID: number | null
  nxtAux1ID: number | null
  nxtAux2ID: number | null
  nxtAux3ID: number | null
  nxtPlatformProfile: string | null
  nxtBoardShortNameOverride: string | null
  nxtBoardKitKey: string | null
  nxtBoardMotorVoltage: number | null
  nxtBoardBootstrapMode: string
  nxtBoardPackExpectedEntry: string | null
  nxtBoardSysDeployPlatform: string | null
  nxtCustomXMin: number | null
  nxtCustomXMax: number | null
  nxtCustomYMin: number | null
  nxtCustomYMax: number | null
  nxtCustomZMin: number | null
  nxtCustomZMax: number | null
  nxtCustomXSteps: number | null
  nxtCustomYSteps: number | null
  nxtCustomZSteps: number | null
  nxtCustomASteps: number | null
  nxtCustomXHomeAt: number | null
  nxtCustomYHomeAt: number | null
  nxtCustomZHomeAt: number | null
  nxtCustomXEndstopPin: string | null
  nxtCustomYEndstopPin: string | null
  nxtCustomZEndstopPin: string | null
  nxtCustomXDrives: string | null
  nxtCustomYDrives: string | null
  nxtCustomZDrives: string | null
  nxtCustomXCurrent: number | null
  nxtCustomYCurrent: number | null
  nxtCustomZCurrent: number | null
  nxtCustomDriveDirs: string | null
  nxtCustomXBacklash: number | null
  nxtCustomYBacklash: number | null
  nxtCustomZBacklash: number | null
  nxtCustomABacklash: number | null
}

export const NXT_USER_VARS_PERSISTED_KEYS = [
  'nxtFeatureTouchProbe',
  'nxtFeatureToolSetter',
  'nxtFeatureCoolantControl',
  'nxtFeatureRgbLight',
  'nxtFeatureFourthAxis',
  'nxtRgbLedIndex',
  'nxtProbeToolID',
  'nxtDeltaMachine',
  'nxtSpindleID',
  'nxtSpindleAccelSec',
  'nxtSpindleDecelSec',
  'nxtTouchProbeID',
  'nxtTouchProbeInvert',
  'nxtProbeTipRadius',
  'nxtProbeDeflection',
  'nxtToolSetterID',
  'nxtToolSetterInvert',
  'nxtToolSetterPos',
  'nxtTouchProbeRefPos',
  'nxtCoolantAirID',
  'nxtCoolantMistID',
  'nxtCoolantFloodID',
  'nxtCoolantMistPulseEnabled',
  'nxtCoolantFloodPulseEnabled',
  'nxtCoolantPulseOnSec',
  'nxtCoolantPulseOffSec',
  'nxtRelayID',
  'nxtAux1ID',
  'nxtAux2ID',
  'nxtAux3ID',
  'nxtPlatformProfile',
  'nxtBoardShortNameOverride',
  'nxtBoardKitKey',
  'nxtBoardMotorVoltage',
  'nxtBoardBootstrapMode',
  'nxtBoardPackExpectedEntry',
  'nxtBoardSysDeployPlatform',
  'nxtCustomXMin',
  'nxtCustomXMax',
  'nxtCustomYMin',
  'nxtCustomYMax',
  'nxtCustomZMin',
  'nxtCustomZMax',
  'nxtCustomXSteps',
  'nxtCustomYSteps',
  'nxtCustomZSteps',
  'nxtCustomASteps',
  'nxtCustomXHomeAt',
  'nxtCustomYHomeAt',
  'nxtCustomZHomeAt',
  'nxtCustomXEndstopPin',
  'nxtCustomYEndstopPin',
  'nxtCustomZEndstopPin',
  'nxtCustomXDrives',
  'nxtCustomYDrives',
  'nxtCustomZDrives',
  'nxtCustomXCurrent',
  'nxtCustomYCurrent',
  'nxtCustomZCurrent',
  'nxtCustomDriveDirs',
  'nxtCustomXBacklash',
  'nxtCustomYBacklash',
  'nxtCustomZBacklash',
  'nxtCustomABacklash'
] as const

export type MachineListContext = {
  spindles: Array<{ id: number }>
  probes: Array<{ id: number; type: number }>
}

export function readConfigBool(value: unknown): boolean {
  return value === true || value === 1
}

export function readConfigNumber(value: unknown): number | null {
  if (value === null || value === undefined || value === '') {
    return null
  }
  const n = typeof value === 'number' ? value : Number(value)
  return Number.isFinite(n) ? n : null
}

export function readConfigString(value: unknown): string | null {
  if (value === null || value === undefined) {
    return null
  }
  const s = String(value).trim()
  return s.length ? s : null
}

export function readConfigVector(value: unknown): number[] | null {
  if (value == null) {
    return null
  }
  if (Array.isArray(value)) {
    return value.length ? value.map((v) => Number(v)) : null
  }
  if (value instanceof Map) {
    const parts: number[] = []
    for (let i = 0; i < 16; i++) {
      if (!value.has(i) && !value.has(String(i))) {
        break
      }
      parts.push(Number(value.get(i) ?? value.get(String(i))))
    }
    return parts.length ? parts : null
  }
  if (typeof value === 'object') {
    const o = value as Record<string, unknown>
    const keys = Object.keys(o)
      .filter((k) => /^\d+$/.test(k))
      .sort((a, b) => Number(a) - Number(b))
    if (keys.length) {
      return keys.map((k) => Number(o[k]))
    }
  }
  return null
}

export function emptyConfigDraft(): NxtUserConfigDraft {
  return {
    nxtFeatureTouchProbe: false,
    nxtFeatureToolSetter: false,
    nxtFeatureCoolantControl: false,
    nxtFeatureRgbLight: false,
    nxtFeatureFourthAxis: false,
    nxtRgbLedIndex: 0,
    nxtProbeToolID: null,
    nxtDeltaMachine: null,
    nxtSpindleID: null,
    nxtSpindleAccelSec: null,
    nxtSpindleDecelSec: null,
    nxtTouchProbeID: null,
    nxtTouchProbeInvert: true,
    nxtProbeTipRadius: null,
    nxtProbeDeflection: null,
    nxtToolSetterID: null,
    nxtToolSetterInvert: false,
    nxtToolSetterPos: null,
    nxtTouchProbeRefPos: null,
    nxtCoolantAirID: null,
    nxtCoolantMistID: null,
    nxtCoolantFloodID: null,
    nxtCoolantMistPulseEnabled: false,
    nxtCoolantFloodPulseEnabled: false,
    nxtCoolantPulseOnSec: 5,
    nxtCoolantPulseOffSec: 25,
    nxtRelayID: null,
    nxtAux1ID: null,
    nxtAux2ID: null,
    nxtAux3ID: null,
    nxtPlatformProfile: null,
    nxtBoardShortNameOverride: null,
    nxtBoardKitKey: null,
    nxtBoardMotorVoltage: null,
    nxtBoardBootstrapMode: 'off',
    nxtBoardPackExpectedEntry: null,
    nxtBoardSysDeployPlatform: null,
    nxtCustomXMin: null,
    nxtCustomXMax: null,
    nxtCustomYMin: null,
    nxtCustomYMax: null,
    nxtCustomZMin: null,
    nxtCustomZMax: null,
    nxtCustomXSteps: null,
    nxtCustomYSteps: null,
    nxtCustomZSteps: null,
    nxtCustomASteps: null,
    nxtCustomXHomeAt: null,
    nxtCustomYHomeAt: null,
    nxtCustomZHomeAt: null,
    nxtCustomXEndstopPin: null,
    nxtCustomYEndstopPin: null,
    nxtCustomZEndstopPin: null,
    nxtCustomXDrives: null,
    nxtCustomYDrives: null,
    nxtCustomZDrives: null,
    nxtCustomXCurrent: null,
    nxtCustomYCurrent: null,
    nxtCustomZCurrent: null,
    nxtCustomDriveDirs: null,
    nxtCustomXBacklash: null,
    nxtCustomYBacklash: null,
    nxtCustomZBacklash: null,
    nxtCustomABacklash: null
  }
}

/** Prefer nxtBoardMotorVoltage; fall back to deprecated nxtScyllaMotorVoltage from OM. */
export function readBoardMotorVoltageFromOm(globalVal: unknown): number | null {
  const v = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtBoardMotorVoltage'))
  if (v === 24 || v === 48) {
    return v
  }
  const legacy = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtScyllaMotorVoltage'))
  if (legacy === 24 || legacy === 48) {
    return legacy
  }
  return null
}

function isDraftFieldUnset(draft: NxtUserConfigDraft, key: keyof NxtUserConfigDraft): boolean {
  const v = draft[key]
  if (key === 'nxtBoardBootstrapMode') {
    return v === 'off'
  }
  if (typeof v === 'boolean') {
    return v === false
  }
  if (Array.isArray(v)) {
    return v === null
  }
  return v === null || v === undefined
}

function mergeDefinedIntoDraft(target: NxtUserConfigDraft, source: Partial<NxtUserConfigDraft>): void {
  for (const key of NXT_USER_VARS_PERSISTED_KEYS) {
    const v = source[key]
    if (v === undefined) {
      continue
    }
    if (key === 'nxtBoardBootstrapMode') {
      target.nxtBoardBootstrapMode = v === 'auto' ? 'auto' : 'off'
      continue
    }
    if (typeof v === 'boolean') {
      ;(target as Record<string, unknown>)[key] = v
      continue
    }
    if (v !== null) {
      ;(target as Record<string, unknown>)[key] = v
    }
  }
}

export function snapshotConfigFromOm(globalVal: unknown): NxtUserConfigDraft {
  const draft = emptyConfigDraft()
  draft.nxtFeatureTouchProbe = readConfigBool(readFirmwareGlobal(globalVal, 'nxtFeatureTouchProbe'))
  draft.nxtFeatureToolSetter = readConfigBool(readFirmwareGlobal(globalVal, 'nxtFeatureToolSetter'))
  draft.nxtFeatureCoolantControl = readConfigBool(readFirmwareGlobal(globalVal, 'nxtFeatureCoolantControl'))
  draft.nxtFeatureRgbLight = readConfigBool(readFirmwareGlobal(globalVal, 'nxtFeatureRgbLight'))
  draft.nxtFeatureFourthAxis = readConfigBool(readFirmwareGlobal(globalVal, 'nxtFeatureFourthAxis'))
  draft.nxtRgbLedIndex = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtRgbLedIndex'))
  draft.nxtProbeToolID = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtProbeToolID'))
  draft.nxtDeltaMachine = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtDeltaMachine'))
  draft.nxtSpindleID = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtSpindleID'))
  draft.nxtSpindleAccelSec = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtSpindleAccelSec'))
  draft.nxtSpindleDecelSec = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtSpindleDecelSec'))
  draft.nxtTouchProbeID = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtTouchProbeID'))
  {
    const inv = readFirmwareGlobal(globalVal, 'nxtTouchProbeInvert')
    draft.nxtTouchProbeInvert = inv === undefined ? true : readConfigBool(inv)
  }
  draft.nxtProbeTipRadius = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtProbeTipRadius'))
  draft.nxtProbeDeflection = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtProbeDeflection'))
  draft.nxtToolSetterID = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtToolSetterID'))
  {
    const inv = readFirmwareGlobal(globalVal, 'nxtToolSetterInvert')
    draft.nxtToolSetterInvert = inv === undefined ? false : readConfigBool(inv)
  }
  draft.nxtToolSetterPos = readConfigVector(readFirmwareGlobal(globalVal, 'nxtToolSetterPos'))
  draft.nxtTouchProbeRefPos = readConfigVector(readFirmwareGlobal(globalVal, 'nxtTouchProbeRefPos'))
  draft.nxtCoolantAirID = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCoolantAirID'))
  draft.nxtCoolantMistID = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCoolantMistID'))
  draft.nxtCoolantFloodID = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCoolantFloodID'))
  draft.nxtCoolantMistPulseEnabled = readConfigBool(
    readFirmwareGlobal(globalVal, 'nxtCoolantMistPulseEnabled')
  )
  draft.nxtCoolantFloodPulseEnabled = readConfigBool(
    readFirmwareGlobal(globalVal, 'nxtCoolantFloodPulseEnabled')
  )
  const pulseOn = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCoolantPulseOnSec'))
  draft.nxtCoolantPulseOnSec = pulseOn !== null && pulseOn >= 1 ? pulseOn : 5
  const pulseOff = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCoolantPulseOffSec'))
  draft.nxtCoolantPulseOffSec = pulseOff !== null && pulseOff >= 1 ? pulseOff : 25
  draft.nxtRelayID = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtRelayID'))
  draft.nxtAux1ID = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtAux1ID'))
  draft.nxtAux2ID = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtAux2ID'))
  draft.nxtAux3ID = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtAux3ID'))
  draft.nxtPlatformProfile = migratePlatformProfileId(
    readConfigString(readFirmwareGlobal(globalVal, 'nxtPlatformProfile'))
  )
  draft.nxtBoardShortNameOverride = readConfigString(readFirmwareGlobal(globalVal, 'nxtBoardShortNameOverride'))
  draft.nxtBoardKitKey = readConfigString(readFirmwareGlobal(globalVal, 'nxtBoardKitKey'))
  draft.nxtBoardMotorVoltage = readBoardMotorVoltageFromOm(globalVal)
  const bootMode = readConfigString(readFirmwareGlobal(globalVal, 'nxtBoardBootstrapMode'))
  draft.nxtBoardBootstrapMode = bootMode === 'auto' ? 'auto' : 'off'
  draft.nxtBoardPackExpectedEntry = readConfigString(
    readFirmwareGlobal(globalVal, 'nxtBoardPackExpectedEntry')
  )
  draft.nxtBoardSysDeployPlatform = migratePlatformProfileId(
    readConfigString(readFirmwareGlobal(globalVal, 'nxtBoardSysDeployPlatform'))
  )
  draft.nxtCustomXMin = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCustomXMin'))
  draft.nxtCustomXMax = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCustomXMax'))
  draft.nxtCustomYMin = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCustomYMin'))
  draft.nxtCustomYMax = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCustomYMax'))
  draft.nxtCustomZMin = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCustomZMin'))
  draft.nxtCustomZMax = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCustomZMax'))
  draft.nxtCustomXSteps = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCustomXSteps'))
  draft.nxtCustomYSteps = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCustomYSteps'))
  draft.nxtCustomZSteps = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCustomZSteps'))
  draft.nxtCustomASteps = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCustomASteps'))
  draft.nxtCustomXHomeAt = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCustomXHomeAt'))
  draft.nxtCustomYHomeAt = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCustomYHomeAt'))
  draft.nxtCustomZHomeAt = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCustomZHomeAt'))
  draft.nxtCustomXEndstopPin = readConfigString(readFirmwareGlobal(globalVal, 'nxtCustomXEndstopPin'))
  draft.nxtCustomYEndstopPin = readConfigString(readFirmwareGlobal(globalVal, 'nxtCustomYEndstopPin'))
  draft.nxtCustomZEndstopPin = readConfigString(readFirmwareGlobal(globalVal, 'nxtCustomZEndstopPin'))
  draft.nxtCustomXDrives = readConfigString(readFirmwareGlobal(globalVal, 'nxtCustomXDrives'))
  draft.nxtCustomYDrives = readConfigString(readFirmwareGlobal(globalVal, 'nxtCustomYDrives'))
  draft.nxtCustomZDrives = readConfigString(readFirmwareGlobal(globalVal, 'nxtCustomZDrives'))
  draft.nxtCustomXCurrent = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCustomXCurrent'))
  draft.nxtCustomYCurrent = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCustomYCurrent'))
  draft.nxtCustomZCurrent = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCustomZCurrent'))
  draft.nxtCustomDriveDirs = readConfigString(readFirmwareGlobal(globalVal, 'nxtCustomDriveDirs'))
  draft.nxtCustomXBacklash = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCustomXBacklash'))
  draft.nxtCustomYBacklash = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCustomYBacklash'))
  draft.nxtCustomZBacklash = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCustomZBacklash'))
  draft.nxtCustomABacklash = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCustomABacklash'))
  return draft
}

/** Mirror nxt-mos-import.g — fill only where draft field is still unset. */
export function mapMosGlobalsToConfig(globalVal: unknown, draft: NxtUserConfigDraft): void {
  const mosBool = (key: string) => readFirmwareGlobal(globalVal, key)
  if (isDraftFieldUnset(draft, 'nxtFeatureTouchProbe') && mosBool('mosFeatTouchProbe') !== undefined) {
    draft.nxtFeatureTouchProbe = readConfigBool(mosBool('mosFeatTouchProbe'))
  }
  if (isDraftFieldUnset(draft, 'nxtFeatureToolSetter') && mosBool('mosFeatToolSetter') !== undefined) {
    draft.nxtFeatureToolSetter = readConfigBool(mosBool('mosFeatToolSetter'))
  }
  if (isDraftFieldUnset(draft, 'nxtFeatureCoolantControl') && mosBool('mosFeatCoolantControl') !== undefined) {
    draft.nxtFeatureCoolantControl = readConfigBool(mosBool('mosFeatCoolantControl'))
  }
  if (isDraftFieldUnset(draft, 'nxtFeatureFourthAxis') && mosBool('mosFAE') !== undefined) {
    const raw = mosBool('mosFAE')
    draft.nxtFeatureFourthAxis = raw === true || raw === 1 || (typeof raw === 'number' && raw !== 0)
  }
  const mosNum = (mosKey: string, draftKey: keyof NxtUserConfigDraft) => {
    if (!isDraftFieldUnset(draft, draftKey)) {
      return
    }
    const raw = readFirmwareGlobal(globalVal, mosKey)
    if (raw !== undefined) {
      ;(draft as Record<string, unknown>)[draftKey] = readConfigNumber(raw)
    }
  }
  mosNum('mosPTID', 'nxtProbeToolID')
  mosNum('mosSID', 'nxtSpindleID')
  mosNum('mosSAS', 'nxtSpindleAccelSec')
  mosNum('mosSDS', 'nxtSpindleDecelSec')
  mosNum('mosTPID', 'nxtTouchProbeID')
  mosNum('mosTPR', 'nxtProbeTipRadius')
  mosNum('mosTPD', 'nxtProbeDeflection')
  mosNum('mosTSID', 'nxtToolSetterID')
  mosNum('mosCAID', 'nxtCoolantAirID')
  mosNum('mosCMID', 'nxtCoolantMistID')
  mosNum('mosCFID', 'nxtCoolantFloodID')
  mosNum('mosRelayID', 'nxtRelayID')

  if (isDraftFieldUnset(draft, 'nxtToolSetterPos') && readFirmwareGlobal(globalVal, 'mosTSP') !== undefined) {
    draft.nxtToolSetterPos = readConfigVector(readFirmwareGlobal(globalVal, 'mosTSP'))
  }
}

export function applySingletonDefaults(draft: NxtUserConfigDraft, ctx: MachineListContext): void {
  if (draft.nxtSpindleID === null && ctx.spindles.length === 1) {
    draft.nxtSpindleID = ctx.spindles[0].id
  }
  const touchProbes = ctx.probes.filter((p) => p.type >= 5 && p.type <= 8)
  if (draft.nxtTouchProbeID === null && touchProbes.length === 1) {
    draft.nxtTouchProbeID = touchProbes[0].id
  }
  if (draft.nxtToolSetterID === null && touchProbes.length === 1) {
    draft.nxtToolSetterID = touchProbes[0].id
  }
}

/**
 * Bootstrap form when nxt-user-vars.g is absent: MOS globals, then singleton picks.
 * Does not copy nxt-vars.g factory defaults (e.g. touch probe ID 0) into the form.
 */
/** Values from macros/system/nxt-vars.g — not treated as user config when bootstrapping the form. */
const NXT_VARS_FACTORY_SENTINELS: Partial<Record<keyof NxtUserConfigDraft, number>> = {
  nxtTouchProbeID: 0,
  nxtToolSetterID: 1,
  nxtProbeTipRadius: 0,
  nxtProbeDeflection: 0
}

function clearNxtVarsFactoryDefaults(draft: NxtUserConfigDraft): void {
  for (const key of Object.keys(NXT_VARS_FACTORY_SENTINELS) as Array<keyof NxtUserConfigDraft>) {
    const sentinel = NXT_VARS_FACTORY_SENTINELS[key]
    if (sentinel !== undefined && draft[key] === sentinel) {
      ;(draft as Record<string, unknown>)[key] = null
    }
  }
}

export function buildInitialConfigDraft(globalVal: unknown, ctx: MachineListContext): NxtUserConfigDraft {
  const draft = snapshotConfigFromOm(globalVal)
  clearNxtVarsFactoryDefaults(draft)
  mapMosGlobalsToConfig(globalVal, draft)
  applySingletonDefaults(draft, ctx)
  return draft
}

export function nxtUserVarsPresentInOm(globalVal: unknown): boolean {
  return readConfigBool(readFirmwareGlobal(globalVal, 'nxtUserVarsPresent'))
}

export function nxtConfigPendingInOm(globalVal: unknown): boolean {
  return readConfigBool(readFirmwareGlobal(globalVal, 'nxtConfigPending'))
}

export function formatPersistedBool(value: unknown): string {
  return readConfigBool(value) ? 'true' : 'false'
}

export function formatPersistedVector(value: unknown): string {
  const vec = readConfigVector(value)
  if (vec == null) {
    return 'null'
  }
  return `{${vec.join(', ')}}`
}

function formatPersistedNumber(value: number | null | undefined): string {
  return value !== null && value !== undefined ? String(value) : 'null'
}

/** Last tool index when the Configuration UI has no probe-tool field (matches nxt-vars.g / nxt-boot.g). */
export function formatPersistedProbeToolID(value: number | null | undefined): string {
  return value !== null && value !== undefined ? String(value) : '{ limits.tools - 1 }'
}

function formatPersistedString(value: string | null | undefined): string {
  if (value == null || value === '') {
    return 'null'
  }
  return `"${String(value).replace(/"/g, '')}"`
}

export function buildNxtUserVarsGcode(config: NxtUserConfigDraft): string {
  const lines = [
    '; nxt User Configuration',
    '; Auto-generated - Do not edit manually',
    '; Last updated: ' + new Date().toISOString(),
    '',
    '; Feature Flags',
    `set global.nxtFeatureTouchProbe = ${formatPersistedBool(config.nxtFeatureTouchProbe)}`,
    `set global.nxtFeatureToolSetter = ${formatPersistedBool(config.nxtFeatureToolSetter)}`,
    `set global.nxtFeatureCoolantControl = ${formatPersistedBool(config.nxtFeatureCoolantControl)}`,
    `set global.nxtFeatureRgbLight = ${formatPersistedBool(config.nxtFeatureRgbLight)}`,
    `set global.nxtFeatureFourthAxis = ${formatPersistedBool(config.nxtFeatureFourthAxis)}`,
    '',
    '; RGB work light (M150)',
    `set global.nxtRgbLedIndex = ${formatPersistedNumber(config.nxtRgbLedIndex)}`,
    '',
    '; Probe tool index (null in UI → last tool at load) and static datum (touch probe calibration)',
    `set global.nxtProbeToolID = ${formatPersistedProbeToolID(config.nxtProbeToolID)}`,
    `set global.nxtDeltaMachine = ${formatPersistedNumber(config.nxtDeltaMachine)}`,
    '',
    '; Spindle Configuration',
    `set global.nxtSpindleID = ${formatPersistedNumber(config.nxtSpindleID)}`,
    `set global.nxtSpindleAccelSec = ${formatPersistedNumber(config.nxtSpindleAccelSec)}`,
    `set global.nxtSpindleDecelSec = ${formatPersistedNumber(config.nxtSpindleDecelSec)}`,
    '',
    '; Touch Probe Configuration',
    `set global.nxtTouchProbeID = ${formatPersistedNumber(config.nxtTouchProbeID)}`,
    `set global.nxtTouchProbeInvert = ${formatPersistedBool(config.nxtTouchProbeInvert)}`,
    `set global.nxtProbeTipRadius = ${formatPersistedNumber(config.nxtProbeTipRadius)}`,
    `set global.nxtProbeDeflection = ${formatPersistedNumber(config.nxtProbeDeflection)}`,
    '; Probe repeatability: defaults in nxt-vars.g; optional 0:/sys/nxt-user-overrides.g',
    '',
    '; Tool Setter Configuration',
    `set global.nxtToolSetterID = ${formatPersistedNumber(config.nxtToolSetterID)}`,
    `set global.nxtToolSetterInvert = ${formatPersistedBool(config.nxtToolSetterInvert)}`,
    `set global.nxtToolSetterPos = ${formatPersistedVector(config.nxtToolSetterPos)}`,
    `set global.nxtTouchProbeRefPos = ${formatPersistedVector(config.nxtTouchProbeRefPos)}`,
    '',
    '; Coolant / output roles',
    `set global.nxtCoolantAirID = ${formatPersistedNumber(config.nxtCoolantAirID)}`,
    `set global.nxtCoolantMistID = ${formatPersistedNumber(config.nxtCoolantMistID)}`,
    `set global.nxtCoolantFloodID = ${formatPersistedNumber(config.nxtCoolantFloodID)}`,
    `set global.nxtCoolantMistPulseEnabled = ${formatPersistedBool(config.nxtCoolantMistPulseEnabled)}`,
    `set global.nxtCoolantFloodPulseEnabled = ${formatPersistedBool(config.nxtCoolantFloodPulseEnabled)}`,
    `set global.nxtCoolantPulseOnSec = ${Math.max(1, config.nxtCoolantPulseOnSec ?? 5)}`,
    `set global.nxtCoolantPulseOffSec = ${Math.max(1, config.nxtCoolantPulseOffSec ?? 25)}`,
    `set global.nxtRelayID = ${formatPersistedNumber(config.nxtRelayID)}`,
    `set global.nxtAux1ID = ${formatPersistedNumber(config.nxtAux1ID)}`,
    `set global.nxtAux2ID = ${formatPersistedNumber(config.nxtAux2ID)}`,
    `set global.nxtAux3ID = ${formatPersistedNumber(config.nxtAux3ID)}`,
    '',
    '; --- Board pack (Configuration panel) ---',
    `; Bootstrap: ${config.nxtBoardBootstrapMode === 'auto' ? 'auto (syncs nxt-board-bootstrap.requested on Save)' : 'off'}`,
    `; Platform: ${config.nxtPlatformProfile ?? 'null'} | Board override: ${config.nxtBoardShortNameOverride ?? 'auto'}`,
    `; Motor supply: ${config.nxtBoardMotorVoltage != null ? config.nxtBoardMotorVoltage + ' V' : 'n/a'}`,
    config.nxtBoardPackExpectedEntry
      ? `; Expected pack entry: ${config.nxtBoardPackExpectedEntry}`
      : '; Expected pack entry: (incomplete — set motor voltage / board)',
    config.nxtBoardSysDeployPlatform
      ? `; Homing sys deploy platform: ${config.nxtBoardSysDeployPlatform}`
      : '; Homing sys deploy platform: (not recorded — use Apply platform sys files)',
    `set global.nxtPlatformProfile = ${formatPersistedString(config.nxtPlatformProfile)}`,
    `set global.nxtBoardShortNameOverride = ${formatPersistedString(config.nxtBoardShortNameOverride)}`,
    `set global.nxtBoardMotorVoltage = ${formatPersistedNumber(config.nxtBoardMotorVoltage)}`,
    `set global.nxtBoardBootstrapMode = "${config.nxtBoardBootstrapMode === 'auto' ? 'auto' : 'off'}"`,
    `set global.nxtBoardPackExpectedEntry = ${formatPersistedString(config.nxtBoardPackExpectedEntry)}`,
    `set global.nxtBoardSysDeployPlatform = ${formatPersistedString(config.nxtBoardSysDeployPlatform)}`
  ]

  // Omit null optional keys — each `set global.foo = null` recreates an OM entry and
  // can push the SBC `global` JSON over the 8KB SPI limit.
  if (config.nxtBoardKitKey != null && config.nxtBoardKitKey !== '') {
    lines.push(`set global.nxtBoardKitKey = ${formatPersistedString(config.nxtBoardKitKey)}`)
  }

  const customPairs: Array<[string, number | string | null | undefined]> = [
    ['nxtCustomXMin', config.nxtCustomXMin],
    ['nxtCustomXMax', config.nxtCustomXMax],
    ['nxtCustomYMin', config.nxtCustomYMin],
    ['nxtCustomYMax', config.nxtCustomYMax],
    ['nxtCustomZMin', config.nxtCustomZMin],
    ['nxtCustomZMax', config.nxtCustomZMax],
    ['nxtCustomXSteps', config.nxtCustomXSteps],
    ['nxtCustomYSteps', config.nxtCustomYSteps],
    ['nxtCustomZSteps', config.nxtCustomZSteps],
    ['nxtCustomASteps', config.nxtCustomASteps],
    ['nxtCustomXHomeAt', config.nxtCustomXHomeAt],
    ['nxtCustomYHomeAt', config.nxtCustomYHomeAt],
    ['nxtCustomZHomeAt', config.nxtCustomZHomeAt],
    ['nxtCustomXEndstopPin', config.nxtCustomXEndstopPin],
    ['nxtCustomYEndstopPin', config.nxtCustomYEndstopPin],
    ['nxtCustomZEndstopPin', config.nxtCustomZEndstopPin],
    ['nxtCustomXDrives', config.nxtCustomXDrives],
    ['nxtCustomYDrives', config.nxtCustomYDrives],
    ['nxtCustomZDrives', config.nxtCustomZDrives],
    ['nxtCustomXCurrent', config.nxtCustomXCurrent],
    ['nxtCustomYCurrent', config.nxtCustomYCurrent],
    ['nxtCustomZCurrent', config.nxtCustomZCurrent],
    ['nxtCustomDriveDirs', config.nxtCustomDriveDirs],
    ['nxtCustomXBacklash', config.nxtCustomXBacklash],
    ['nxtCustomYBacklash', config.nxtCustomYBacklash],
    ['nxtCustomZBacklash', config.nxtCustomZBacklash],
    ['nxtCustomABacklash', config.nxtCustomABacklash]
  ]
  const customLines = customPairs
    .filter(([, v]) => v != null && v !== '')
    .map(([k, v]) =>
      typeof v === 'number'
        ? `set global.${k} = ${formatPersistedNumber(v)}`
        : `set global.${k} = ${formatPersistedString(v as string)}`
    )
  if (customLines.length) {
    lines.push('', '; Custom platform (only non-null values — keeps OM global under SBC 8KB)')
    lines.push(...customLines)
  }

  return lines.join('\n')
}

/** Self-test for node --test runner (see ui/scripts/run-user-vars-persistence-tests.mjs). */
export function runNxtUserVarsPersistenceSelfTest(): void {
  const gcode = buildNxtUserVarsGcode(emptyConfigDraft())
  if (
    gcode.includes('nxtProbeInnerSampleCount') ||
    gcode.includes('nxtProbeMaxSampleSpreadMm') ||
    gcode.includes('nxtProbeSampleOuterRetries')
  ) {
    throw new Error('nxt-user-vars.g must not persist probe repeatability (use nxt-user-overrides.g)')
  }
  if (gcode.includes('set global.nxtCustomXMin = null')) {
    throw new Error('nxt-user-vars.g must not persist null custom platform keys (OM size)')
  }
  if (gcode.includes('set global.nxtBoardKitKey = null')) {
    throw new Error('nxt-user-vars.g must not persist null nxtBoardKitKey (OM size)')
  }
  const draft = buildInitialConfigDraft(
    { mosSID: 0, mosTPID: 1, mosFeatTouchProbe: true },
    { spindles: [{ id: 0 }], probes: [{ id: 1, type: 5 }] }
  )
  if (draft.nxtSpindleID !== 0) {
    throw new Error('MOS spindle mapping failed')
  }
  if (draft.nxtTouchProbeID !== 1) {
    throw new Error('MOS touch probe mapping failed')
  }
  if (!draft.nxtFeatureTouchProbe) {
    throw new Error('MOS feature flag mapping failed')
  }
}
