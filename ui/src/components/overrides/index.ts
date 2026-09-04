/**
 * Override Components
 *
 * Central entry point for nxt's DWC UI overrides (custom dialog + CNC dashboard panel).
 *
 * CNC every-page status: under Vue 3 / Vite, DWC's builtin shell statically imports stock
 * `CNCContainerPanel`, so global registration cannot intercept it. nxt restores the rich CNC
 * status (tool / WCS / Z offset / spindle) via `registerLayout(NxtShell)` in `ui/src/index.ts`
 * (`takeoverOnFirstLoad`). See DuetWebControl CUSTOM-LAYOUT.md; users can return to the built-in
 * shell from Settings → Display or `/BuiltInLayout`.
 *
 * MessageBoxDialog: still inert — App.vue binds DWC's own import at compile time. Exported here
 * so it stays compiled if DWC later exposes an override hook.
 */

import MessageBoxDialog from './MessageBoxDialog.vue'
import { CNCContainerPanel } from './panels'

export { MessageBoxDialog, CNCContainerPanel }
