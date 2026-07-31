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
  nxtFeatureAtc: boolean
  /** NeoPixel LEDs on the strip (M950 U / M150 S). */
  nxtRGBCount: number | null
  /** M950 T: 1=RGB NeoPixel, 2=RGBW NeoPixel. */
  nxtRGBType: number | null
  /** M950 K colour order: 0=BGR … 5=GRB (NeoPixel default). */
  nxtRGBOrder: number | null
  nxtProbeToolID: number | null
  nxtDeltaMachine: number | null
  nxtSpindleID: number | null
  nxtSpindleAccelSec: number | null
  nxtSpindleDecelSec: number | null
  nxtTouchProbeID: number | null
  nxtTouchProbeInvert: boolean
  nxtProbeTipRadius: number | null
  /** Touch-probe deflection {X, Y, Z} mm; null = unset. Legacy scalar/{X,Y} normalize to XYZ. */
  nxtProbeDeflection: number[] | null
  nxtToolSetterID: number | null
  nxtToolSetterInvert: boolean
  nxtToolSetterPos: number[] | null
  /** V2.0 toolsetter fixed ref-pad geometry. */
  nxtToolSetterV2: boolean
  /** V2 ref pad side of platen: 0=+X 1=-X 2=+Y 3=-Y. */
  nxtToolSetterRefDir: number
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
  /** Pin aliases created as M950 F instead of J (e.g. aux0). null = board voltage default on pack load. */
  nxtBoardFanPins: string[] | null
  /** 0=off 1=PanelDue 2=BTT TFT 3=pendant — Scylla UART PD8/PD9 */
  nxtUartDevice: number
  nxtUartBaud: number
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
  nxtCustomAMin: number | null
  nxtCustomAMax: number | null
  nxtCustomXSteps: number | null
  nxtCustomYSteps: number | null
  nxtCustomZSteps: number | null
  nxtCustomASteps: number | null
  nxtCustomXHomeAt: number | null
  nxtCustomYHomeAt: number | null
  nxtCustomZHomeAt: number | null
  nxtCustomAHomeAt: number | null
  nxtCustomXEndstopPin: string | null
  nxtCustomYEndstopPin: string | null
  nxtCustomZEndstopPin: string | null
  nxtCustomAEndstopPin: string | null
  nxtCustomXDrives: string | null
  nxtCustomYDrives: string | null
  nxtCustomZDrives: string | null
  nxtCustomADrives: string | null
  nxtCustomXCurrent: number | null
  nxtCustomYCurrent: number | null
  nxtCustomZCurrent: number | null
  nxtCustomACurrent: number | null
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
  'nxtFeatureAtc',
  'nxtRGBCount',
  'nxtRGBType',
  'nxtRGBOrder',
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
  'nxtToolSetterV2',
  'nxtToolSetterRefDir',
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
  'nxtBoardFanPins',
  'nxtUartDevice',
  'nxtUartBaud',
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
  'nxtCustomAMin',
  'nxtCustomAMax',
  'nxtCustomXSteps',
  'nxtCustomYSteps',
  'nxtCustomZSteps',
  'nxtCustomASteps',
  'nxtCustomXHomeAt',
  'nxtCustomYHomeAt',
  'nxtCustomZHomeAt',
  'nxtCustomAHomeAt',
  'nxtCustomXEndstopPin',
  'nxtCustomYEndstopPin',
  'nxtCustomZEndstopPin',
  'nxtCustomAEndstopPin',
  'nxtCustomXDrives',
  'nxtCustomYDrives',
  'nxtCustomZDrives',
  'nxtCustomADrives',
  'nxtCustomXCurrent',
  'nxtCustomYCurrent',
  'nxtCustomZCurrent',
  'nxtCustomACurrent',
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

/**
 * Probe deflection as {X,Y,Z} positive magnitudes.
 * Legacy: scalar / {n} → [n,n,n]; {x,y} → [x,y,x] (Z falls back to X).
 */
export function readConfigDeflectionXY(value: unknown): number[] | null {
  if (value == null) {
    return null
  }
  if (typeof value === 'number' && Number.isFinite(value)) {
    return [value, value, value]
  }
  const vec = readConfigVector(value)
  if (!vec || vec.length === 0) {
    return null
  }
  if (vec.length === 1) {
    return [vec[0], vec[0], vec[0]]
  }
  if (vec.length === 2) {
    return [vec[0], vec[1], vec[0]]
  }
  return [vec[0], vec[1], vec[2]]
}

/** @deprecated Alias — use readConfigDeflectionXY (now returns XYZ). */
export const readConfigDeflectionXYZ = readConfigDeflectionXY

export function isFactoryZeroDeflection(value: number[] | null | undefined): boolean {
  return (
    value != null &&
    value.length >= 3 &&
    value[0] === 0 &&
    value[1] === 0 &&
    value[2] === 0
  )
}

/** String vector from OM (e.g. nxtBoardFanPins). Empty array = explicitly none; null = unset. */
export function readConfigStringVector(value: unknown): string[] | null {
  if (value == null) {
    return null
  }
  // CSV string persist form, or legacy scalar "none" / single alias
  if (typeof value === 'string') {
    const s = value.trim()
    if (s.length === 0 || s === 'none') {
      return []
    }
    return s.split(',').map((p) => p.trim()).filter((p) => p.length > 0 && p !== 'none')
  }
  const raw: unknown[] = []
  if (Array.isArray(value)) {
    raw.push(...value)
  } else if (value instanceof Map) {
    for (let i = 0; i < 16; i++) {
      if (!value.has(i) && !value.has(String(i))) {
        break
      }
      raw.push(value.get(i) ?? value.get(String(i)))
    }
  } else if (typeof value === 'object') {
    const o = value as Record<string, unknown>
    const keys = Object.keys(o)
      .filter((k) => /^\d+$/.test(k))
      .sort((a, b) => Number(a) - Number(b))
    for (const k of keys) {
      raw.push(o[k])
    }
  } else {
    return null
  }
  return raw.map((v) => String(v).trim()).filter((s) => s.length > 0)
}

export function formatPersistedStringVector(value: string[] | null | undefined): string {
  if (value == null) {
    return 'null'
  }
  if (value.length === 0) {
    // Explicit none as empty string (gpio treats "" / "none" as no fans)
    return '""'
  }
  // CSV string — avoids RRF non-array indexing on string/"none" sentinels
  return `"${value.map((s) => String(s).replace(/"/g, '').trim()).filter(Boolean).join(',')}"`
}

/**
 * Live / file G-code to assign a global that may not exist yet (pre-reboot installs).
 * RRF requires `global name = …` before `set global.name = …`.
 * Returns a single multi-line block (if/else) for file persist, or use
 * {@link gcodeEnsureGlobalLines} for stepwise DWC sendCode.
 */
export function gcodeEnsureSetGlobal(name: string, rhs: string): string {
  return gcodeEnsureGlobalLines(name, rhs).join('\n')
}

/** Two short if-blocks so DWC can send them as separate rr_gcode calls if needed. */
export function gcodeEnsureGlobalLines(name: string, rhs: string): string[] {
  const key = name.replace(/^global\./, '')
  return [
    `if { !exists(global.${key}) }`,
    `    global ${key} = ${rhs}`,
    `if { exists(global.${key}) }`,
    `    set global.${key} = ${rhs}`
  ]
}

export function emptyConfigDraft(): NxtUserConfigDraft {
  return {
    nxtFeatureTouchProbe: false,
    nxtFeatureToolSetter: false,
    nxtFeatureCoolantControl: false,
    nxtFeatureRgbLight: false,
    nxtFeatureFourthAxis: false,
    nxtFeatureAtc: false,
    nxtRGBCount: 1,
    nxtRGBType: 1,
    nxtRGBOrder: 5,
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
    nxtToolSetterV2: false,
    nxtToolSetterRefDir: 0,
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
    nxtBoardFanPins: null,
    nxtUartDevice: 0,
    nxtUartBaud: 57600,
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
    nxtCustomAMin: null,
    nxtCustomAMax: null,
    nxtCustomXSteps: null,
    nxtCustomYSteps: null,
    nxtCustomZSteps: null,
    nxtCustomASteps: null,
    nxtCustomXHomeAt: null,
    nxtCustomYHomeAt: null,
    nxtCustomZHomeAt: null,
    nxtCustomAHomeAt: null,
    nxtCustomXEndstopPin: null,
    nxtCustomYEndstopPin: null,
    nxtCustomZEndstopPin: null,
    nxtCustomAEndstopPin: null,
    nxtCustomXDrives: null,
    nxtCustomYDrives: null,
    nxtCustomZDrives: null,
    nxtCustomADrives: null,
    nxtCustomXCurrent: null,
    nxtCustomYCurrent: null,
    nxtCustomZCurrent: null,
    nxtCustomACurrent: null,
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
  draft.nxtFeatureAtc = readConfigBool(readFirmwareGlobal(globalVal, 'nxtFeatureAtc'))
  draft.nxtRGBCount = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtRGBCount')) ?? 1
  draft.nxtRGBType = normalizeNxtRgbType(readConfigNumber(readFirmwareGlobal(globalVal, 'nxtRGBType')))
  draft.nxtRGBOrder = normalizeNxtRgbOrder(readConfigNumber(readFirmwareGlobal(globalVal, 'nxtRGBOrder')))
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
  draft.nxtProbeDeflection = readConfigDeflectionXY(readFirmwareGlobal(globalVal, 'nxtProbeDeflection'))
  draft.nxtToolSetterID = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtToolSetterID'))
  {
    const inv = readFirmwareGlobal(globalVal, 'nxtToolSetterInvert')
    draft.nxtToolSetterInvert = inv === undefined ? false : readConfigBool(inv)
  }
  draft.nxtToolSetterPos = readConfigVector(readFirmwareGlobal(globalVal, 'nxtToolSetterPos'))
  draft.nxtToolSetterV2 = readConfigBool(readFirmwareGlobal(globalVal, 'nxtToolSetterV2'))
  draft.nxtToolSetterRefDir = normalizeNxtToolSetterRefDir(
    readConfigNumber(readFirmwareGlobal(globalVal, 'nxtToolSetterRefDir'))
  )
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
  {
    const fansRaw = readFirmwareGlobal(globalVal, 'nxtBoardFanPins')
    draft.nxtBoardFanPins =
      fansRaw === null || fansRaw === undefined
        ? null
        : (readConfigStringVector(fansRaw) ?? []).filter((s) => s !== 'none')
  }
  draft.nxtUartDevice = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtUartDevice')) ?? 0
  draft.nxtUartBaud = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtUartBaud')) ?? 57600
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
  draft.nxtCustomAMin = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCustomAMin'))
  draft.nxtCustomAMax = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCustomAMax'))
  draft.nxtCustomXSteps = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCustomXSteps'))
  draft.nxtCustomYSteps = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCustomYSteps'))
  draft.nxtCustomZSteps = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCustomZSteps'))
  draft.nxtCustomASteps = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCustomASteps'))
  draft.nxtCustomXHomeAt = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCustomXHomeAt'))
  draft.nxtCustomYHomeAt = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCustomYHomeAt'))
  draft.nxtCustomZHomeAt = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCustomZHomeAt'))
  draft.nxtCustomAHomeAt = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCustomAHomeAt'))
  draft.nxtCustomXEndstopPin = readConfigString(readFirmwareGlobal(globalVal, 'nxtCustomXEndstopPin'))
  draft.nxtCustomYEndstopPin = readConfigString(readFirmwareGlobal(globalVal, 'nxtCustomYEndstopPin'))
  draft.nxtCustomZEndstopPin = readConfigString(readFirmwareGlobal(globalVal, 'nxtCustomZEndstopPin'))
  draft.nxtCustomAEndstopPin = readConfigString(readFirmwareGlobal(globalVal, 'nxtCustomAEndstopPin'))
  draft.nxtCustomXDrives = readConfigString(readFirmwareGlobal(globalVal, 'nxtCustomXDrives'))
  draft.nxtCustomYDrives = readConfigString(readFirmwareGlobal(globalVal, 'nxtCustomYDrives'))
  draft.nxtCustomZDrives = readConfigString(readFirmwareGlobal(globalVal, 'nxtCustomZDrives'))
  draft.nxtCustomADrives = readConfigString(readFirmwareGlobal(globalVal, 'nxtCustomADrives'))
  draft.nxtCustomXCurrent = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCustomXCurrent'))
  draft.nxtCustomYCurrent = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCustomYCurrent'))
  draft.nxtCustomZCurrent = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCustomZCurrent'))
  draft.nxtCustomACurrent = readConfigNumber(readFirmwareGlobal(globalVal, 'nxtCustomACurrent'))
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
  mosNum('mosTSID', 'nxtToolSetterID')
  mosNum('mosCAID', 'nxtCoolantAirID')
  mosNum('mosCMID', 'nxtCoolantMistID')
  mosNum('mosCFID', 'nxtCoolantFloodID')
  mosNum('mosRelayID', 'nxtRelayID')

  if (isDraftFieldUnset(draft, 'nxtProbeDeflection')) {
    const mosTpd = readFirmwareGlobal(globalVal, 'mosTPD')
    if (mosTpd !== undefined) {
      draft.nxtProbeDeflection = readConfigDeflectionXY(mosTpd)
    }
  }

  if (isDraftFieldUnset(draft, 'nxtToolSetterPos') && readFirmwareGlobal(globalVal, 'mosTSP') !== undefined) {
    draft.nxtToolSetterPos = readConfigVector(readFirmwareGlobal(globalVal, 'mosTSP'))
  }
}

export function applySingletonDefaults(draft: NxtUserConfigDraft, ctx: MachineListContext): void {
  if (draft.nxtSpindleID === null && ctx.spindles.length === 1) {
    draft.nxtSpindleID = ctx.spindles[0].id
  }
  const touchProbes = ctx.probes.filter((p) => p.type >= 5 && p.type <= 8)
  const hasProbe = (id: number): boolean => touchProbes.some((p) => p.id === id)

  // Prefer documented Scylla defaults (K0 touch / K1 toolsetter); never dual-assign.
  if (draft.nxtTouchProbeID === null) {
    if (hasProbe(0)) {
      draft.nxtTouchProbeID = 0
    } else if (touchProbes.length === 1) {
      draft.nxtTouchProbeID = touchProbes[0].id
    }
  }
  if (draft.nxtToolSetterID === null) {
    if (hasProbe(1) && draft.nxtTouchProbeID !== 1) {
      draft.nxtToolSetterID = 1
    } else {
      const remaining = touchProbes.filter((p) => p.id !== draft.nxtTouchProbeID)
      if (remaining.length === 1) {
        draft.nxtToolSetterID = remaining[0].id
      }
    }
  }
}

/**
 * Bootstrap form when nxt-user-vars.g is absent: MOS globals, then singleton picks.
 * Probe role IDs 0/1 are valid RRF indices (not "unset") — do not clear them.
 */
/** Tip radius 0 from nxt-vars.g is not a measured user value when bootstrapping the form. */
const NXT_VARS_FACTORY_SENTINELS: Partial<Record<keyof NxtUserConfigDraft, number>> = {
  nxtProbeTipRadius: 0
}

function clearNxtVarsFactoryDefaults(draft: NxtUserConfigDraft): void {
  for (const key of Object.keys(NXT_VARS_FACTORY_SENTINELS) as Array<keyof NxtUserConfigDraft>) {
    const sentinel = NXT_VARS_FACTORY_SENTINELS[key]
    if (sentinel !== undefined && draft[key] === sentinel) {
      ;(draft as Record<string, unknown>)[key] = null
    }
  }
  // nxt-vars.g default {0.0, 0.0, 0.0} — not a measured user value
  if (isFactoryZeroDeflection(draft.nxtProbeDeflection)) {
    draft.nxtProbeDeflection = null
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

/** M950 T: 1=RGB, 2=RGBW. Legacy T3 (old docs) → 2. */
export function normalizeNxtRgbType(value: number | null | undefined): number {
  if (value === 3) {
    return 2
  }
  if (value === 1 || value === 2) {
    return value
  }
  return 1
}

/** M950 K: 0=BGR … 5=GRB (NeoPixel default). */
export function normalizeNxtRgbOrder(value: number | null | undefined): number {
  if (value !== null && value !== undefined && value >= 0 && value <= 5) {
    return value
  }
  return 5
}

/** V2 toolsetter ref pad side: 0=+X 1=-X 2=+Y 3=-Y. */
export function normalizeNxtToolSetterRefDir(value: number | null | undefined): number {
  if (value !== null && value !== undefined && value >= 0 && value <= 3) {
    return value
  }
  return 0
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
    `set global.nxtFeatureAtc = ${formatPersistedBool(config.nxtFeatureAtc)}`,
    '',
    '; RGB work light (M950 T / K / U)',
    `set global.nxtRGBCount = ${formatPersistedNumber(config.nxtRGBCount ?? 1)}`,
    `set global.nxtRGBType = ${formatPersistedNumber(normalizeNxtRgbType(config.nxtRGBType))}`,
    `set global.nxtRGBOrder = ${formatPersistedNumber(normalizeNxtRgbOrder(config.nxtRGBOrder))}`,
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
    // Omit null probe role IDs — keep nxt-vars.g defaults (0 / 1) instead of forcing null.
    ...(config.nxtTouchProbeID !== null && config.nxtTouchProbeID !== undefined
      ? [`set global.nxtTouchProbeID = ${formatPersistedNumber(config.nxtTouchProbeID)}`]
      : []),
    `set global.nxtTouchProbeInvert = ${formatPersistedBool(config.nxtTouchProbeInvert)}`,
    `set global.nxtProbeTipRadius = ${formatPersistedNumber(config.nxtProbeTipRadius)}`,
    `set global.nxtProbeDeflection = ${formatPersistedVector(config.nxtProbeDeflection)}`,
    '; Probe repeatability: defaults in nxt-vars.g; optional 0:/sys/nxt-user-overrides.g',
    '',
    '; Tool Setter Configuration',
    ...(config.nxtToolSetterID !== null && config.nxtToolSetterID !== undefined
      ? [`set global.nxtToolSetterID = ${formatPersistedNumber(config.nxtToolSetterID)}`]
      : []),
    `set global.nxtToolSetterInvert = ${formatPersistedBool(config.nxtToolSetterInvert)}`,
    `set global.nxtToolSetterPos = ${formatPersistedVector(config.nxtToolSetterPos)}`,
    `set global.nxtToolSetterV2 = ${formatPersistedBool(config.nxtToolSetterV2)}`,
    `set global.nxtToolSetterRefDir = ${formatPersistedNumber(normalizeNxtToolSetterRefDir(config.nxtToolSetterRefDir))}`,
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
    gcodeEnsureSetGlobal('nxtBoardFanPins', formatPersistedStringVector(config.nxtBoardFanPins)),
    gcodeEnsureSetGlobal('nxtUartDevice', formatPersistedNumber(config.nxtUartDevice)),
    gcodeEnsureSetGlobal('nxtUartBaud', formatPersistedNumber(config.nxtUartBaud)),
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
    gcodeEnsureSetGlobal(
      'nxtBoardBootstrapMode',
      `"${config.nxtBoardBootstrapMode === 'auto' ? 'auto' : 'off'}"`
    ),
    gcodeEnsureSetGlobal(
      'nxtPlatformProfile',
      formatPersistedString(config.nxtPlatformProfile)
    ),
    gcodeEnsureSetGlobal(
      'nxtBoardShortNameOverride',
      formatPersistedString(config.nxtBoardShortNameOverride)
    ),
    gcodeEnsureSetGlobal(
      'nxtBoardMotorVoltage',
      formatPersistedNumber(config.nxtBoardMotorVoltage)
    ),
    gcodeEnsureSetGlobal(
      'nxtBoardPackExpectedEntry',
      formatPersistedString(config.nxtBoardPackExpectedEntry)
    ),
    gcodeEnsureSetGlobal(
      'nxtBoardSysDeployPlatform',
      formatPersistedString(config.nxtBoardSysDeployPlatform)
    )
  ]

  // Omit null optional keys — each `set global.foo = null` recreates an OM entry and
  // can push the SBC `global` JSON over the 8KB SPI limit.
  if (config.nxtBoardKitKey != null && config.nxtBoardKitKey !== '') {
    lines.push(
      gcodeEnsureSetGlobal('nxtBoardKitKey', formatPersistedString(config.nxtBoardKitKey))
    )
  }

  const customPairs: Array<[string, number | string | null | undefined]> = [
    ['nxtCustomXMin', config.nxtCustomXMin],
    ['nxtCustomXMax', config.nxtCustomXMax],
    ['nxtCustomYMin', config.nxtCustomYMin],
    ['nxtCustomYMax', config.nxtCustomYMax],
    ['nxtCustomZMin', config.nxtCustomZMin],
    ['nxtCustomZMax', config.nxtCustomZMax],
    ['nxtCustomAMin', config.nxtCustomAMin],
    ['nxtCustomAMax', config.nxtCustomAMax],
    ['nxtCustomXSteps', config.nxtCustomXSteps],
    ['nxtCustomYSteps', config.nxtCustomYSteps],
    ['nxtCustomZSteps', config.nxtCustomZSteps],
    ['nxtCustomASteps', config.nxtCustomASteps],
    ['nxtCustomXHomeAt', config.nxtCustomXHomeAt],
    ['nxtCustomYHomeAt', config.nxtCustomYHomeAt],
    ['nxtCustomZHomeAt', config.nxtCustomZHomeAt],
    ['nxtCustomAHomeAt', config.nxtCustomAHomeAt],
    ['nxtCustomXEndstopPin', config.nxtCustomXEndstopPin],
    ['nxtCustomYEndstopPin', config.nxtCustomYEndstopPin],
    ['nxtCustomZEndstopPin', config.nxtCustomZEndstopPin],
    ['nxtCustomAEndstopPin', config.nxtCustomAEndstopPin],
    ['nxtCustomXDrives', config.nxtCustomXDrives],
    ['nxtCustomYDrives', config.nxtCustomYDrives],
    ['nxtCustomZDrives', config.nxtCustomZDrives],
    ['nxtCustomADrives', config.nxtCustomADrives],
    ['nxtCustomXCurrent', config.nxtCustomXCurrent],
    ['nxtCustomYCurrent', config.nxtCustomYCurrent],
    ['nxtCustomZCurrent', config.nxtCustomZCurrent],
    ['nxtCustomACurrent', config.nxtCustomACurrent],
    ['nxtCustomDriveDirs', config.nxtCustomDriveDirs],
    ['nxtCustomXBacklash', config.nxtCustomXBacklash],
    ['nxtCustomYBacklash', config.nxtCustomYBacklash],
    ['nxtCustomZBacklash', config.nxtCustomZBacklash],
    ['nxtCustomABacklash', config.nxtCustomABacklash]
  ]
  const customLines: string[] = []
  for (const [k, v] of customPairs) {
    if (v == null || v === '') continue
    // Declare happens in nxt.g via nxt-custom-globals.g — user-vars only overlays with set.
    customLines.push(
      typeof v === 'number'
        ? `set global.${k} = ${formatPersistedNumber(v)}`
        : `set global.${k} = ${formatPersistedString(v as string)}`
    )
  }
  if (customLines.length) {
    lines.push('', '; Custom platform (set overlay — declared in nxt-custom-globals.g at boot)')
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
  if (gcode.includes('set global.nxtTouchProbeID = null')) {
    throw new Error('nxt-user-vars.g must not persist null nxtTouchProbeID (keep nxt-vars default)')
  }
  if (gcode.includes('set global.nxtToolSetterID = null')) {
    throw new Error('nxt-user-vars.g must not persist null nxtToolSetterID (keep nxt-vars default)')
  }

  const keepZero = buildInitialConfigDraft(
    { nxtTouchProbeID: 0, nxtToolSetterID: 1, nxtProbeTipRadius: 0 },
    { spindles: [], probes: [{ id: 0, type: 5 }, { id: 1, type: 8 }] }
  )
  if (keepZero.nxtTouchProbeID !== 0) {
    throw new Error('bootstrap must keep nxtTouchProbeID 0 (valid probe index, not a sentinel)')
  }
  if (keepZero.nxtToolSetterID !== 1) {
    throw new Error('bootstrap must keep nxtToolSetterID 1 (valid probe index, not a sentinel)')
  }
  if (keepZero.nxtProbeTipRadius !== null) {
    throw new Error('bootstrap should clear tip-radius factory sentinel 0')
  }

  const dual = emptyConfigDraft()
  applySingletonDefaults(dual, {
    spindles: [],
    probes: [
      { id: 0, type: 5 },
      { id: 1, type: 8 }
    ]
  })
  if (dual.nxtTouchProbeID !== 0 || dual.nxtToolSetterID !== 1) {
    throw new Error('applySingletonDefaults should assign touch=0 and toolsetter=1')
  }

  const sole = emptyConfigDraft()
  applySingletonDefaults(sole, { spindles: [], probes: [{ id: 2, type: 5 }] })
  if (sole.nxtTouchProbeID !== 2) {
    throw new Error('applySingletonDefaults should assign sole probe to touch')
  }
  if (sole.nxtToolSetterID !== null) {
    throw new Error('applySingletonDefaults must not dual-assign the sole probe to toolsetter')
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
