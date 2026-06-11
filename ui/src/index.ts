/**
 * nxt UI Plugin Entry Point (DuetWebControl plugin)
 *
 * This file registers the nxt plugin routes, localization, and plugin data
 * for the DuetWebControl plugin integration.
 *
 * Compatibility: `plugin.json` uses `dwcVersion: "auto"` (exact DWC version at build) and `rrfVersion: "auto-major"`. Rebuild the plugin ZIP when the host DWC version changes. Dev reference: **3.6.2** — `docs/RRF_REFERENCE.md`.
 * Building or running the plugin inside a much older or newer DWC tree can cause opaque
 * webpack/runtime errors at plugin start (e.g. `undefined is not an object (evaluating '…​.call')`)
 * if chunk loading or the plugin host API does not match.
 *
 * Routes use **static** panel imports so the nxt chunk does not rely on async `import()`
 * sub-chunks (which can fail on some embedded / cached deployments).
 *
 * Route/i18n registration stays synchronous so /nxt exists as soon as the chunk evaluates.
 */

import { registerRoute } from '@/routes'
import { registerPluginLocalization } from '@/i18n'
import { registerPluginData, PluginDataType } from '@/store'
import store from '@/store'

// Import main components
import nxt from './nxt.vue'
import ToolManagementPanel from './components/panels/ToolManagementPanel.vue'

// Import and register component modules
import './components/base'
import './components/inputs'
// Side-effect: registers kebab-case tags used inside nxt.vue.
import './components/panels'
// Overrides (CNC dashboard + MessageBoxDialog) — re-enable after plugin starts reliably.
import './components/overrides'

// Import localization
import en from './locales/en.json'

const NXT_ROUTE_PATH = '/nxt'

function registerNxtSideEffects(): void {
  try {
    try {
      registerPluginLocalization('nxt', 'en', en)
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err)
      if (!msg.includes('already exists')) {
        throw err
      }
      console.warn('[nxt] Skipping duplicate plugin i18n registration')
    }

    registerPluginData('nxt', PluginDataType.globalSetting, 'nxtUiState', {
      ready: false,
      dialogActive: false,
      dialogMessage: null,
      dialogResponse: null,
      lastProbeResults: [],
      selectedResultIndex: 0
    })

    registerPluginData('nxt', PluginDataType.globalSetting, 'nxtRgbUiState', {
      r: 255,
      g: 255,
      b: 255,
      brightness: 100,
      on: true
    })

    registerRoute(nxt, {
      Control: {
        nxt: {
          icon: 'mdi-wrench',
          caption: 'plugins.nxt.name',
          path: NXT_ROUTE_PATH
        }
      }
    })

    registerRoute(ToolManagementPanel, {
      Control: {
        nxtToolLibrary: {
          icon: 'mdi-bookshelf',
          caption: 'plugins.nxt.panels.toolManagement.caption',
          path: `${NXT_ROUTE_PATH}/ToolLibrary`
        }
      }
    })
  } catch (err) {
    console.error('[nxt] Plugin registration failed:', err)
  }
}

registerNxtSideEffects()

export default nxt
