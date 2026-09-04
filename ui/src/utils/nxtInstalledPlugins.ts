/** Companion DWC plugin ids detected from the machine / settings store. */

export const NXT_FOURTH_AXIS_PLUGIN_ID = 'MosFourthAxis'
export const NXT_ATC_PLUGIN_ID = 'MosAtc'
export const NXT_ARBORCTL_PLUGIN_ID = 'ArborCTL'

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

/**
 * True when MosAtc is installed (magazine / job-sequence UI).
 * Firmware init macros load from nxt.g when global.nxtFeatureAtc is also true.
 */
export function isAtcPluginInstalled(opts: {
  modelPlugins?: Map<string, unknown> | Record<string, DwcPluginEntry> | null
  settingsPlugins?: Record<string, DwcPluginEntry> | null
  /** @deprecated pass modelPlugins / settingsPlugins */
  plugins?: Record<string, DwcPluginEntry>
}): boolean {
  if (pluginMapHasId(opts.modelPlugins, NXT_ATC_PLUGIN_ID)) return true
  if (pluginMapHasId(opts.settingsPlugins, NXT_ATC_PLUGIN_ID)) return true
  if (pluginMapHasId(opts.plugins, NXT_ATC_PLUGIN_ID)) return true
  return false
}

/**
 * True when ArborCTL DWC plugin is installed (VFD / Modbus spindle control).
 */
export function isArborCtlPluginInstalled(opts: {
  modelPlugins?: Map<string, unknown> | Record<string, DwcPluginEntry> | null
  settingsPlugins?: Record<string, DwcPluginEntry> | null
  /** @deprecated pass modelPlugins / settingsPlugins */
  plugins?: Record<string, DwcPluginEntry>
}): boolean {
  if (pluginMapHasId(opts.modelPlugins, NXT_ARBORCTL_PLUGIN_ID)) return true
  if (pluginMapHasId(opts.settingsPlugins, NXT_ARBORCTL_PLUGIN_ID)) return true
  if (pluginMapHasId(opts.plugins, NXT_ARBORCTL_PLUGIN_ID)) return true
  return false
}

/**
 * True when ArborCTL firmware globals are live (macros loaded) even if the DWC
 * plugin ZIP is not started — secondary signal for showing the VFD tab.
 */
export function isArborCtlFirmwareLive(global: unknown): boolean {
  if (global == null) return false
  const read = (key: string): unknown => {
    if (global instanceof Map) {
      return global.get(key)
    }
    if (typeof global === 'object') {
      return (global as Record<string, unknown>)[key]
    }
    return undefined
  }
  if (read('arborctlLdd') === true) return true
  const cfg = read('arborVFDConfig')
  return Array.isArray(cfg) && cfg.length > 0
}
