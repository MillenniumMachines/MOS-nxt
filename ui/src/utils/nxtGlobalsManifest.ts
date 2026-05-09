/**
 * Expected NeXT `global.*` keys (base install: nxt.g / nxt-vars.g).
 * Used by Configuration panel snapshot; keep aligned with macros/system/nxt-vars.g and nxt.g.
 */
import { readFirmwareGlobal } from './nxtToolChangerOm'

export type NxtGlobalManifestEntry = { key: string; description: string }

export const NXT_GLOBAL_MANIFEST: NxtGlobalManifestEntry[] = [
  { key: 'nxtVersion', description: 'NeXT build/version (set in nxt.g)' },
  { key: 'nxtVarsLoaded', description: 'True after nxt-vars.g has been run once' },
  { key: 'nxtFeatureTouchProbe', description: 'Feature: touch probe' },
  { key: 'nxtFeatureToolSetter', description: 'Feature: tool setter' },
  { key: 'nxtFeatureCoolantControl', description: 'Feature: coolant control' },
  { key: 'nxtProbeToolID', description: 'RRF tool index for probe' },
  { key: 'nxtTouchProbeID', description: 'Touch probe sensor ID' },
  { key: 'nxtToolSetterID', description: 'Tool setter sensor ID' },
  { key: 'nxtError', description: 'Last NeXT error message' },
  { key: 'nxtLoaded', description: 'NeXT boot completed successfully' },
  { key: 'nxtDeltaMachine', description: 'Static datum Z (toolsetter ↔ reference)' },
  { key: 'nxtProbeResults', description: 'Last probe results table (vector)' },
  { key: 'nxtToolCache', description: 'Per-tool cache (vector)' },
  { key: 'nxtLastProbeResult', description: 'Last single probe result' },
  { key: 'nxtProbeTipRadius', description: 'Probe tip radius (mm)' },
  { key: 'nxtProbeDeflection', description: 'Probe deflection compensation (mm)' },
  { key: 'nxtToolSetterPos', description: 'Toolsetter position [X,Y,Z]' },
  { key: 'nxtToolChangeState', description: 'Tool-change macro state' },
  { key: 'nxtCoolantAirID', description: 'Coolant air GP out ID' },
  { key: 'nxtCoolantMistID', description: 'Coolant mist GP out ID' },
  { key: 'nxtCoolantFloodID', description: 'Coolant flood GP out ID' },
  { key: 'nxtPinStates', description: 'gpOut snapshot vector' },
  { key: 'nxtSpindleID', description: 'Default spindle ID' },
  { key: 'nxtSpindleAccelSec', description: 'Spindle accel time (s)' },
  { key: 'nxtSpindleDecelSec', description: 'Spindle decel time (s)' },
  { key: 'nxtCannedCycle', description: 'Active canned cycle state vector' },
  { key: 'nxtCannedRetractMode', description: 'G98/G99 retract mode' },
  { key: 'nxtCannedZi', description: 'Canned cycle scratch: Z axis index' },
  { key: 'nxtPlatformProfile', description: 'Machine platform (v1.5 / v1.6_v2 / atlas); selects nxt/config path for kit M98' },
  { key: 'nxtBoardKitKey', description: 'Selected LDO kit (fly_cdyv3 / scylla_24 / scylla_48)' },
  { key: 'nxtScyllaMotorVoltage', description: 'Scylla motor supply hint (24 or 48)' },
  { key: 'nxtBoardBootstrapMode', description: 'Board bootstrap preference (off|auto); SD sentinel enables load' },
  { key: 'nxtUserToolsFilePresent', description: 'True if 0:/sys/nxt-user-tools.g existed at last nxt.g boot load' },
  { key: 'nxtUserToolsDaemonReload', description: 'If true, daemon reloads nxt-user-tools.g when reload sentinel exists' }
]

/** Human-readable value from RRF object model global (may be Map or plain object). */
export function formatOmGlobalValue(val: unknown): string {
  if (val === undefined) {
    return '—'
  }
  if (val === null) {
    return 'null'
  }
  if (typeof val === 'boolean' || typeof val === 'number') {
    return String(val)
  }
  if (typeof val === 'string') {
    return val.length > 160 ? `${val.slice(0, 157)}…` : val
  }
  if (Array.isArray(val)) {
    if (val.length === 0) {
      return '[]'
    }
    if (val.length > 8) {
      const head = val
        .slice(0, 4)
        .map((x) => formatOmGlobalValue(x))
        .join(', ')
      return `[${val.length} items] ${head}…`
    }
    try {
      return JSON.stringify(val)
    } catch {
      return `[${val.length} items]`
    }
  }
  if (typeof val === 'object') {
    try {
      const s = JSON.stringify(val)
      return s.length > 280 ? `${s.slice(0, 277)}…` : s
    } catch {
      return String(val)
    }
  }
  return String(val)
}

export function snapshotNxtGlobals(globalVal: unknown): Array<{
  key: string
  description: string
  raw: unknown
  valueText: string
  missing: boolean
}> {
  return NXT_GLOBAL_MANIFEST.map(({ key, description }) => {
    const raw = readFirmwareGlobal(globalVal, key)
    const missing = raw === undefined
    return {
      key,
      description,
      raw,
      valueText: missing ? '(not in object model)' : formatOmGlobalValue(raw),
      missing
    }
  })
}
