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
  { key: 'nxtFeatureRgbLight', description: 'Feature: RGB work light (M150)' },
  { key: 'nxtRgbLedIndex', description: 'M150 LED strip index (P parameter)' },
  { key: 'nxtProbeToolID', description: 'RRF tool index for probe' },
  { key: 'nxtTouchProbeID', description: 'Touch probe sensor ID' },
  { key: 'nxtToolSetterID', description: 'Tool setter sensor ID' },
  { key: 'nxtError', description: 'Last NeXT error message' },
  { key: 'nxtLoaded', description: 'NeXT boot completed successfully' },
  { key: 'nxtUserVarsPresent', description: 'True after nxt-user-vars.g was loaded from SD (nxt.g)' },
  { key: 'nxtConfigPending', description: 'True when nxt-user-vars.g is missing — complete setup in Configuration UI' },
  { key: 'nxtDeltaMachine', description: 'Static datum Z (toolsetter ↔ reference)' },
  { key: 'nxtProbeResults', description: 'Last probe results table (vector)' },
  { key: 'nxtToolCache', description: 'Per-tool cache (vector)' },
  { key: 'nxtLastProbeResult', description: 'Last single probe result' },
  { key: 'nxtProbeTipRadius', description: 'Probe tip radius (mm)' },
  { key: 'nxtProbeDeflection', description: 'Probe deflection compensation (mm)' },
  { key: 'nxtProbeInnerSampleCount', description: 'G6512 inner samples when R omitted (default nxt-vars.g; override nxt-user-overrides.g)' },
  { key: 'nxtProbeMaxSampleSpreadMm', description: 'G6512 max consecutive-pair deviation (mm); 0 disables (default 0.0075 in nxt-vars.g)' },
  { key: 'nxtProbeSampleOuterRetries', description: 'G6512 extra sample blocks after failed spread (default nxt-vars.g)' },
  { key: 'nxtTouchProbeInnerSampleCount', description: 'Touch probe G6512 inner samples (tpost touch-probe path)' },
  { key: 'nxtTouchProbeMaxSampleSpreadMm', description: 'Touch probe pair spread limit (mm); 0 disables tolerance' },
  { key: 'nxtTouchProbeSampleOuterRetries', description: 'Touch probe extra 3-touch retry cycles' },
  { key: 'nxtToolSetterInnerSampleCount', description: 'Toolsetter G6512 inner samples (tpost enforces minimum 2)' },
  { key: 'nxtToolSetterMaxSampleSpreadMm', description: 'Toolsetter pair spread limit (mm); 0 disables tolerance' },
  { key: 'nxtToolSetterSampleOuterRetries', description: 'Toolsetter extra 3-touch retry cycles' },
  { key: 'nxtToolSetterPos', description: 'Toolsetter position [X,Y,Z]' },
  { key: 'nxtToolSetterProbeTravelMm', description: 'Downward travel from toolsetter Z for tool-length probing (mm)' },
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
  { key: 'nxtPlatformProfile', description: 'Machine profile (v1.5 / v1.6_v2); nxt-config/machine/<id>/ motion pack at boot' },
  { key: 'nxtBoardShortNameOverride', description: 'Optional RRF boards[0].shortName override; null uses object model primary board' },
  { key: 'nxtBoardKitKey', description: 'Legacy kit key (deprecated; use shortName + nxtBoardMotorVoltage)' },
  { key: 'nxtBoardMotorVoltage', description: 'Motor supply 24 or 48 V for motor-24v/48v board packs' },
  { key: 'nxtScyllaMotorVoltage', description: 'Deprecated — use nxtBoardMotorVoltage' },
  { key: 'nxtBoardPackExpectedEntry', description: 'Saved expected pack entry path (Configuration Save)' },
  { key: 'nxtBoardSysDeployPlatform', description: 'Platform whose home*.g were last deployed to 0:/sys/' },
  { key: 'nxtBoardPackEntry', description: 'Runtime: last resolved board pack entry path (nxt-board-pack-loader.g)' },
  { key: 'nxtBoardPackResolveBrd', description: 'Scratch board shortName passed loader → pack resolver (M98)' },
  { key: 'nxtBoardBootstrapMode', description: 'Pack load preference (off|auto); SD sentinel enables load' },
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
