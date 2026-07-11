/** Companion DWC plugin ids detected from the machine / settings store. */

export const NXT_FOURTH_AXIS_PLUGIN_ID = 'MosFourthAxis'

export type DwcPluginEntry = { started?: boolean; id?: string }

function pluginMapHasId(
  plugins: Map<string, unknown> | Record<string, DwcPluginEntry> | null | undefined,
  id: string
): boolean {
  if (plugins == null) return false
  if (plugins instanceof Map) {
    return plugins.has(id)
  }
  if (typeof plugins === 'object') {
    const p = (plugins as Record<string, DwcPluginEntry>)[id]
    if (!p) return false
    return p.started !== false
  }
  return false
}

/**
 * True when MosFourthAxis is installed.
 * Checks OM `model.plugins` (Map) and settings `plugins` record.
 */
export function isFourthAxisPluginInstalled(opts: {
  modelPlugins?: Map<string, unknown> | Record<string, DwcPluginEntry> | null
  settingsPlugins?: Record<string, DwcPluginEntry> | null
  /** @deprecated pass modelPlugins / settingsPlugins */
  plugins?: Record<string, DwcPluginEntry>
}): boolean {
  if (pluginMapHasId(opts.modelPlugins, NXT_FOURTH_AXIS_PLUGIN_ID)) return true
  if (pluginMapHasId(opts.settingsPlugins, NXT_FOURTH_AXIS_PLUGIN_ID)) return true
  if (pluginMapHasId(opts.plugins, NXT_FOURTH_AXIS_PLUGIN_ID)) return true
  return false
}
