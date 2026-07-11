/**
 * Override Components
 *
 * Central entry point for nxt's DWC UI overrides (custom dialog + CNC dashboard panel).
 *
 * NOT wired into ui/src/index.ts by default: under Vue 3 / Vite, DWC core binds
 * `<MessageBoxDialog />` (App.vue) and `<CNCContainerPanel />` (layouts/builtin.vue) to their own
 * imports at compile time, so global registration under these components' kebab-case names can no
 * longer intercept them the way Vue 2's global component registry could - these overrides are
 * currently inert. Exported here (not registered globally) so they're ready to wire up once DWC
 * exposes an explicit override/registration hook for these core singletons (e.g. via the layout
 * system's `registerLayout`).
 */

import MessageBoxDialog from './MessageBoxDialog.vue'
import { CNCContainerPanel } from './panels'

export { MessageBoxDialog, CNCContainerPanel }