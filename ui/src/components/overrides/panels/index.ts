/**
 * Panel Override Registration
 * 
 * Registers NeXT panel overrides to replace DWC's default panels.
 * This allows NeXT to control the CNC machine dashboard layout.
 */

import Vue from 'vue'

// Import NeXT panel overrides
import CNCContainerPanel from './CNCContainerPanel.vue'

// Register CNCContainerPanel override
// This replaces DWC's default CNC mode dashboard with NeXT's custom version
Vue.component('cnc-container-panel', CNCContainerPanel)

console.log('NeXT UI: CNCContainerPanel override registered')