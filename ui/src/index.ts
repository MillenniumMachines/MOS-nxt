/**
 * NeXT UI Plugin Entry Point (DuetWebControl plugin)
 *
 * This file registers the NeXT plugin routes, localization, and plugin data
 * for the DuetWebControl plugin integration.
 *
 * Compatibility: `plugin.json` uses `dwcVersion: "auto"` (exact DWC version at build) and `rrfVersion: "auto-major"`. Rebuild the plugin ZIP when the host DWC version changes. Dev reference: **3.6.2** — `docs/RRF_REFERENCE.md`.
 * Building or running the plugin inside a much older or newer DWC tree can cause opaque
 * webpack/runtime errors at plugin start (e.g. `undefined is not an object (evaluating '…​.call')`)
 * if chunk loading or the plugin host API does not match.
 *
 * Routes use **static** panel imports so the NeXT chunk does not rely on async `import()`
 * sub-chunks (which can fail on some embedded / cached deployments).
 *
 * Route/i18n registration stays synchronous so /NeXT exists as soon as the chunk evaluates.
 */

import { registerRoute } from '@/routes'
import { registerPluginLocalization } from '@/i18n'
import { registerPluginData, PluginDataType } from '@/store'
import store from '@/store'

// Import main components
import NeXT from './NeXT.vue'
import ToolManagementPanel from './components/panels/ToolManagementPanel.vue'

// Import and register component modules
import './components/base'
import './components/inputs'
// Side-effect: registers kebab-case tags used inside NeXT.vue.
import './components/panels'
// Overrides (CNC dashboard + MessageBoxDialog) — re-enable after plugin starts reliably.
import './components/overrides'

// Import localization
import en from './locales/en.json'

const NE_ROUTE_PATH = '/NeXT'

function registerNeXTSideEffects(): void {
  try {
    try {
      registerPluginLocalization('next', 'en', en)
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err)
      if (!msg.includes('already exists')) {
        throw err
      }
      console.warn('[NeXT] Skipping duplicate plugin i18n registration')
    }

    registerPluginData('NeXT', PluginDataType.globalSetting, 'nxtUiState', {
      ready: false,
      dialogActive: false,
      dialogMessage: null,
      dialogResponse: null,
      lastProbeResults: [],
      selectedResultIndex: 0
    })

    registerPluginData('NeXT', PluginDataType.globalSetting, 'nxtRgbUiState', {
      r: 255,
      g: 255,
      b: 255,
      brightness: 100,
      on: true
    })

    registerRoute(NeXT, {
      Control: {
        NeXT: {
          icon: 'mdi-wrench',
          caption: 'plugins.next.name',
          path: NE_ROUTE_PATH
        }
      }
    })

    registerRoute(ToolManagementPanel, {
      Control: {
        NeXTToolLibrary: {
          icon: 'mdi-bookshelf',
          caption: 'plugins.next.panels.toolManagement.caption',
          path: `${NE_ROUTE_PATH}/ToolLibrary`
        }
      }
    })
  } catch (err) {
    console.error('[NeXT] Plugin registration failed:', err)
  }
}

registerNeXTSideEffects()

export default NeXT
