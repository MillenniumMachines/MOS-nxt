/**
 * Panel Override Registration
 * 
 * Registers nxt panel overrides to replace DWC's default panels.
 * This allows nxt to control the CNC machine dashboard layout.
 */

import Vue from 'vue'

// Import nxt panel overrides
import CNCContainerPanel from './CNCContainerPanel.vue'

// Register CNCContainerPanel override
// This replaces DWC's default CNC mode dashboard with nxt's custom version
Vue.component('cnc-container-panel', CNCContainerPanel)

console.log('nxt UI: CNCContainerPanel override registered')