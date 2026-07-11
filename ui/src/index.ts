/**
 * nxt UI Plugin Entry Point (DuetWebControl plugin)
 *
 * This file registers the nxt plugin routes, localization, and plugin data
 * for the DuetWebControl plugin integration.
 *
 * Compatibility: `plugin.json` uses `dwcVersion: "auto"` (exact DWC version at build) and `rrfVersion: "auto-major"`. Rebuild the plugin ZIP when the host DWC version changes. Dev reference (branch `v0.7.0`): **3.7.0-beta.1** — `docs/RRF_REFERENCE.md`, `docs/VERSIONING.md`.
 * Building or running the plugin inside a much older or newer DWC tree can cause opaque
 * runtime errors at plugin start if the plugin host API does not match.
 *
 * DWC 3.7 external plugins are precompiled IIFE bundles: `@/plugins`, `@/composables/*` and
 * `@/stores/*` imports are externalised at build time to a flat `window.DWC` global (see
 * DuetWebControl/scripts/build-plugin.js). `registerRoute` / `registerPluginMessages` come from
 * `@/plugins`; plugin-scoped persisted settings go through the settings Pinia store
 * (`@/compat/dwcStore`'s `registerPluginData`/`setPluginData` shim over `useSettingsStore()`).
 *
 * Routes use **static** panel imports so the nxt chunk does not rely on async `import()`
 * sub-chunks (which can fail on some embedded / cached deployments).
 *
 * Route/i18n registration stays synchronous so /nxt exists as soon as the chunk evaluates.
 */

import { registerRoute, registerPluginMessages } from '@/plugins'
import { registerPluginData, PluginDataType } from './compat/dwcStore'

// Import main components
import nxt from './nxt.vue'
import ToolManagementPanel from './components/panels/ToolManagementPanel.vue'

// Import component modules for their side effects (utility registrations only - Vue 3 has no
// global `Vue.component`, so panels used inside nxt.vue's template are imported locally there)
import './components/base'
import './components/inputs'
import './components/panels'
// Overrides (CNC dashboard + MessageBoxDialog) replace core DWC components. DWC's own templates
// import those components directly, so a plugin can't override them via global registration in
// Vue 3 - see components/overrides/index.ts for details. Left imported (inert) so the override
// components stay compiled/available if a future DWC version exposes an override hook.
import './components/overrides'

// Import localization
import en from './locales/en.json'

const NXT_ROUTE_PATH = '/nxt'

function registerNxtSideEffects(): void {
  try {
    registerPluginMessages('nxt', { en })

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
