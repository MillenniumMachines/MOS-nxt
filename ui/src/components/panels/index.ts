/**
 * Global panel tags for NeXT.vue and shared widgets only.
 *
 * Route-only panels (Stock prep, Tool library, etc.) are NOT imported here so they
 * do not run at plugin startup — they load when their route is registered via dynamic import.
 */

import Vue from 'vue'
import StatusWidget from './StatusWidget.vue'
import ActionConfirmationWidget from './ActionConfirmationWidget.vue'
import MachineStatusPanel from './MachineStatusPanel.vue'
import ConfigurationPanel from './ConfigurationPanel.vue'
import ProbingCyclesPanel from './ProbingCyclesPanel.vue'
import ProbeResultsPanel from './ProbeResultsPanel.vue'
import ToolManagementPanel from './ToolManagementPanel.vue'

Vue.component('nxt-status-widget', StatusWidget)
Vue.component('nxt-action-confirmation-widget', ActionConfirmationWidget)
Vue.component('nxt-machine-status-panel', MachineStatusPanel)
Vue.component('nxt-configuration-panel', ConfigurationPanel)
Vue.component('nxt-probing-cycles-panel', ProbingCyclesPanel)
Vue.component('nxt-probe-results-panel', ProbeResultsPanel)
Vue.component('nxt-tool-management-panel', ToolManagementPanel)

export {
  StatusWidget,
  ActionConfirmationWidget,
  MachineStatusPanel,
  ConfigurationPanel,
  ProbingCyclesPanel,
  ProbeResultsPanel,
  ToolManagementPanel
}
