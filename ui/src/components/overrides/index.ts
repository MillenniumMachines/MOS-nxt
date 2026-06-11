/**
 * Override Components Registration
 * 
 * Central entry point for registering all UI overrides within nxt.
 * This enables nxt to customize the default DWC user interface.
 */

import Vue from 'vue'

// Import dialog override
import MessageBoxDialog from './MessageBoxDialog.vue'

// Import panel and route overrides
import './panels'
import './routes'

// Register MessageBoxDialog component override
// This replaces DWC's built-in MessageBoxDialog with our custom version
Vue.component('message-box-dialog', MessageBoxDialog)

console.log('nxt UI: Override components loaded (dialog, panels, and routes)')
console.log('nxt UI: MessageBoxDialog override registered - persistent dialogs enabled')