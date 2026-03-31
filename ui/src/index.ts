/**
 * NeXT UI Plugin Entry Point (DuetWebControl plugin)
 *
 * This file registers the NeXT plugin routes, localization, and plugin data
 * for the DuetWebControl plugin integration.
 */

import { Menu } from '@/routes'
import Vue from 'vue'
import { registerRoute, Routes } from '@/routes'
import { registerPluginLocalization } from '@/i18n'
import { registerPluginData, PluginDataType } from '@/store'

// Import main components
import NeXT from './NeXT.vue'
import {
  MachineStatusPanel,
  ConfigurationPanel,
  StockPreparationPanel,
  GCodeViewer3D,
  ProbingPanel,
  ToolLibraryPanel
} from './components/panels'

// Import and register component modules
import './components/base'
import './components/inputs'
import './components/panels'
import './components/overrides'

// Import localization
import en from './locales/en.json'

// Register plugin localization
registerPluginLocalization('next', 'en', en)

// Register plugin-specific data in the machine cache
registerPluginData('NeXT', PluginDataType.machineCache, 'nxtUiState', {
  ready: false,
  dialogActive: false,
  dialogMessage: null,
  dialogResponse: null,
  lastProbeResults: [],
  selectedResultIndex: 0
})



async function registerNeXTRoutes() {
  // Machine Status under Control with caption 'NeXT'
  await registerRoute(MachineStatusPanel, {
    Control: {
      NeXT: {
        icon: 'mdi-information-outline',
        caption: 'plugins.next.name',
        path: '/NeXT/Status'
      }
    }
  })

  // Probing under Control
  await registerRoute(ProbingPanel, {
    Control: {
      NeXT_Probing: {
        icon: 'mdi-target-variant',
        caption: 'plugins.next.panels.probing.caption',
        path: '/NeXT/Probing'
      }
    }
  })

  // Stock Preparation under Job
  await registerRoute(StockPreparationPanel, {
    Job: {
      NeXT_StockPreparation: {
        icon: 'mdi-cube-outline',
        caption: 'plugins.next.panels.stockPreparation.caption',
        path: '/NeXT/StockPreparation'
      }
    }
  })

  // Configuration under Settings with caption 'NeXT'
  await registerRoute(ConfigurationPanel, {
    Settings: {
      NeXT_Configuration: {
        icon: 'mdi-cog',
        caption: 'plugins.next.name',
        path: '/NeXT/Configuration'
      }
    }
  })

  // ATC tool library (mos-atc persistent globals + M878/M879 on firmware)
  await registerRoute(ToolLibraryPanel, {
    Control: {
      NeXT_ToolLibrary: {
        icon: 'mdi-bookshelf',
        caption: 'plugins.next.panels.toolLibrary.caption',
        path: '/NeXT/ToolLibrary'
      }
    }
  })
}

registerNeXTRoutes().catch((err) => console.error('NeXT: failed to register routes', err))

// Set nxtUiReady flag when plugin loads
Vue.nextTick(() => {
  try {
    const store = Vue.prototype.$store
    if (store) {
      store.dispatch('machine/sendCode', 'set global.nxtUiReady = true')
        .then(() => {
          console.log('NeXT UI: Plugin loaded and ready')
        })
        .catch((error: any) => {
          console.error('NeXT UI: Failed to set ready flag', error)
        })
    }
  } catch (err) {
    console.error('NeXT: failed to set ready flag', err)
  }
})

export default NeXT