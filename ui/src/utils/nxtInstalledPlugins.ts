/** Companion DWC plugin ids detected from the machine store. */

export const NXT_FOURTH_AXIS_PLUGIN_ID = 'MosFourthAxis'

export type DwcPluginEntry = { started?: boolean }

/** True when MosFourthAxis is present in the DWC machine store (installed; started when field exists). */
export function isFourthAxisPluginInstalled(machineState: {
  plugins?: Record<string, DwcPluginEntry>
}): boolean {
  const p = machineState.plugins?.[NXT_FOURTH_AXIS_PLUGIN_ID]
  if (!p) {
    return false
  }
  return p.started !== false
}
