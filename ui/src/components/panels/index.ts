/**
 * Panel Components Registration
 *
 * Registers all NeXT panel components globally for use in templates
 */

import Vue from 'vue'
import StatusWidget from './StatusWidget.vue'
import ActionConfirmationWidget from './ActionConfirmationWidget.vue'
import MachineStatusPanel from './MachineStatusPanel.vue'
import ConfigurationPanel from './ConfigurationPanel.vue'
import StockPreparationPanel from './StockPreparationPanel.vue'
import GCodeViewer3D from './GCodeViewer3D.vue'
import ProbingPanel from './ProbingPanel.vue'
import ToolLibraryPanel from './ToolLibraryPanel.vue'

// Register panel components
Vue.component('nxt-status-widget', StatusWidget)
Vue.component('nxt-action-confirmation-widget', ActionConfirmationWidget)
Vue.component('nxt-machine-status-panel', MachineStatusPanel)
Vue.component('nxt-configuration-panel', ConfigurationPanel)
Vue.component('nxt-stock-preparation-panel', StockPreparationPanel)
Vue.component('g-code-viewer-3-d', GCodeViewer3D)
Vue.component('nxt-probing-panel', ProbingPanel)
Vue.component('nxt-tool-library-panel', ToolLibraryPanel)

export {
  StatusWidget,
  ActionConfirmationWidget,
  MachineStatusPanel,
  ConfigurationPanel,
  StockPreparationPanel,
  ProbingPanel,
  GCodeViewer3D,
  ToolLibraryPanel
}