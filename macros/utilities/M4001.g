; M4001.g: REMOVE TOOL
;
; Removes a tool by index

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

if { !exists(global.nxtTT) }
    if { !exists(global.nxtET) }
        global nxtET = { 0.0, {0.0, 0.0}, -1, -1.0, 1, 1 }
    global nxtTT = { vector(limits.tools, null) }

; Read tool number to remove
if { !exists(param.P) }
    abort "Must provide tool number (P...) to remove from tool list!"

if { param.P >= limits.tools || param.P < 0 }
    abort { "Tool index must be between 0 and " ^ (limits.tools-1) ^ "!" }

; Before any tools are defined, the tool table is empty.
; Abort, because we cannot check existence of any tools.
if { #tools < 1 }
    M99

; Check if the tool exists
; The tool array is lazily-extended by RRF, so if the
; number of tools is less than the requested tool number
; then the tool cannot exist.
if { #tools < param.P || tools[param.P] == null }
    M99

; Reset RRF Tool
M563 P{param.P} R-1 S"Unknown Tool"

; Clear tool details (null keeps OM small vs re-filling nxtET)
set global.nxtTT[param.P] = null

; Zero accumulated tool life so a later tool at this index does not inherit spindle time.
if { exists(global.nxtToolLife) && param.P < #global.nxtToolLife && global.nxtToolLife[param.P] != 0 }
    set global.nxtToolLife[param.P] = 0
    if { exists(global.nxtFeatMaint) && global.nxtFeatMaint }
        M98 P"nxt/nxt-save-maintenance.g"

; Rewrite persisted library if auto-persistence is enabled (same rules as M4000).
if { (!exists(global.nxtUserToolsLoadDepth) || global.nxtUserToolsLoadDepth < 1) && (!exists(global.nxtAutoPersistTools) || global.nxtAutoPersistTools) }
    M98 P"nxt-user-tools-sync.g"
