/**
 * MOS Fourth Axis (MosFourthAxis) calibration helpers for nxt Calibration tab.
 * Macros live in sibling repo mos-fourth-axis (M4806/M4807/M4910/M4912).
 *
 * Firmware flag global.nxtFeatureFourthAxis enables Scylla board pack axis-a.g
 * (drive 3 / M584 A3). Calibration UI still needs the MosFourthAxis DWC plugin
 * for M4806/M4807/M4910/M4912 and a visible A axis in the OM.
 */
import {
  isFourthAxisPluginInstalled,
  NXT_FOURTH_AXIS_PLUGIN_ID
} from './nxtInstalledPlugins'
import { readFirmwareGlobal } from './nxtToolChangerOm'
import { readConfigBool } from './nxtUserVarsPersistence'

/** @deprecated Prefer NXT_FOURTH_AXIS_PLUGIN_ID — same value. */
export const NXT_ROTARY_CALIBRATION_PLUGIN_ID = NXT_FOURTH_AXIS_PLUGIN_ID

export { isFourthAxisPluginInstalled, NXT_FOURTH_AXIS_PLUGIN_ID }

export function hasVisibleAAxis(axes: Array<{ letter?: string; visible?: boolean }> | null | undefined): boolean {
  if (!Array.isArray(axes)) return false
  return axes.some((a) => {
    const letter = (a?.letter ?? '').toUpperCase()
    if (letter !== 'A') return false
    return a.visible !== false
  })
}

/** True when nxtFeatureFourthAxis is enabled (boolean in firmware; OM may also expose 1). */
export function isNxtFourthAxisFeatureEnabled(globalVal: unknown): boolean {
  return readConfigBool(readFirmwareGlobal(globalVal, 'nxtFeatureFourthAxis'))
}

export function isRotaryCalibrationAvailable(opts: {
  modelPlugins?: Map<string, unknown> | Record<string, { started?: boolean }> | null
  settingsPlugins?: Record<string, { started?: boolean }> | null
  machineState?: { plugins?: Record<string, { started?: boolean }> }
  axes: Array<{ letter?: string; visible?: boolean }> | null | undefined
}): boolean {
  const installed = isFourthAxisPluginInstalled({
    modelPlugins: opts.modelPlugins,
    settingsPlugins: opts.settingsPlugins,
    plugins: opts.machineState?.plugins
  })
  return installed && hasVisibleAAxis(opts.axes)
}

/** Mirror MosFourthAxisControl.vue M-code map. */
export const ROTARY_M = {
  setStepsPerMm: 4806,
  applyY0ToWcs: 4807,
  probeRotaryYCenter: 4910,
  probeYFlatnessRotary: 4912
} as const

export function cmdM4806SetSteps(steps: number): string {
  return `M${ROTARY_M.setStepsPerMm} V${steps}`
}

export function cmdM4806Report(): string {
  return `M${ROTARY_M.setStepsPerMm}`
}

export function cmdM4912ProbeYFlatness(): string {
  return `M${ROTARY_M.probeYFlatnessRotary}`
}

export function cmdM4910ProbeYCenter(): string {
  return `M${ROTARY_M.probeRotaryYCenter}`
}

/** WCS codes: 54–59, 591–593 for G59.1–G59.3 style used by M4807. */
export function cmdM4807ApplyY0(wcsCode: number): string {
  return `M${ROTARY_M.applyY0ToWcs} W${wcsCode}`
}
