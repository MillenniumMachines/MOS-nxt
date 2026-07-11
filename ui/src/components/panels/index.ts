/**
 * Panels shared between nxt.vue and the CNC dashboard override.
 *
 * No global registration (Vue 3 has no `Vue.component`, and DWC's own components resolve their
 * template tags via local imports anyway) - consumers import what they need directly and list it
 * in their own `components: {...}` map, e.g.:
 *
 *   import { MachineStatusPanel } from './components/panels'
 *   export default defineNxtComponent({ components: { NxtMachineStatusPanel: MachineStatusPanel }, ... })
 *
 * Route-only panels (Stock prep, Tool library, etc.) are NOT imported here so they
 * do not run at plugin startup — they load when their route is registered via a static import
 * in ui/src/index.ts.
 */

import StatusWidget from './StatusWidget.vue'
import ActionConfirmationWidget from './ActionConfirmationWidget.vue'
import MachineStatusPanel from './MachineStatusPanel.vue'
import ConfigurationPanel from './ConfigurationPanel.vue'
import ProbingCyclesPanel from './ProbingCyclesPanel.vue'
import ProbeResultsPanel from './ProbeResultsPanel.vue'
import ToolManagementPanel from './ToolManagementPanel.vue'
import RgbLightControl from './RgbLightControl.vue'
import Spindle0ControlPanel from './Spindle0ControlPanel.vue'
import MaintenancePanel from './MaintenancePanel.vue'
import CalibrationPanel from './CalibrationPanel.vue'

export {
  StatusWidget,
  ActionConfirmationWidget,
  MachineStatusPanel,
  ConfigurationPanel,
  CalibrationPanel,
  ProbingCyclesPanel,
  ProbeResultsPanel,
  ToolManagementPanel,
  RgbLightControl,
  Spindle0ControlPanel,
  MaintenancePanel
}
