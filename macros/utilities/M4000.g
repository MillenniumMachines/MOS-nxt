; M4000.g: DEFINE TOOL
;
; Defines a tool by index.
;
; RRF's tools[] object model (see upstream Tool / OM) exposes name, spindle, offsets, etc.
; — not cutter radius or diameter. M563 updates the real tools[P] record; param.R (radius) is
; stored in global.mosTT for CAM/DWC. The nxt plugin merges mosTT into tool rows client-side.
;
; Creates an RRF tool and links it to the default spindle (global.nxtSpindleID, or 0 if unset).
; Stores CAM radius, optional probe deflections, and optional flute count / flute length in global.mosTT (see nxt-tooltable.g).

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Belt-and-suspenders if boot skipped nxt-tooltable.g (partial SD update)
if { !exists(global.mosTT) }
    if { !exists(global.mosET) }
        global mosET = { 0.0, {0.0, 0.0}, -1, -1.0 }
    global mosTT = { vector(limits.tools, global.mosET) }

if { !exists(param.P) || !exists(param.R) || !exists(param.S) }
    abort { "Must provide tool number (P...), radius (R...) and description (S...) to register tool!" }

if { #param.S < 1 }
    abort { "Tool description must be at least 1 character long!" }

; Validate tool index
if { param.P >= limits.tools || param.P < 0 }
    abort { "Tool index must be between 0 and " ^ limits.tools-1 ^ "!" }

var spinId = { (exists(param.I)) ? param.I : (global.nxtSpindleID != null ? global.nxtSpindleID : 0) }

; Check if tool is already defined and matches. If so, skip adding it.
; This allows us to re-run a file that defines the tool that is currently
; loaded, without unloading the tool.

; Initial tool similarity check - make sure the tool is defined in both the internal
; RRF tool table and our own mosTT table.
var toolSame = { global.mosTT[param.P] != null && #tools > param.P && tools[param.P] != null }

; Check that tool radius and spindle match
set var.toolSame = { var.toolSame && global.mosTT[param.P][0] == param.R && tools[param.P].spindle == var.spinId }

; Check that tool description matches
set var.toolSame = { var.toolSame && tools[param.P].name == param.S }

; Check that deflection values match (probe tools only; cutting tools omit X/Y)
if { exists(param.X) }
    set var.toolSame = { var.toolSame && global.mosTT[param.P][1][0] == param.X }
if { exists(param.Y) }
    set var.toolSame = { var.toolSame && global.mosTT[param.P][1][1] == param.Y }

; Optional flute count (F) and flute length (L), stored in mosTT[P][2] and [3]; -1 = unset
if { exists(param.F) }
    if { #global.mosTT[param.P] > 2 }
        set var.toolSame = { var.toolSame && global.mosTT[param.P][2] == param.F }
    else
        set var.toolSame = false
if { exists(param.L) }
    if { #global.mosTT[param.P] > 3 }
        set var.toolSame = { var.toolSame && global.mosTT[param.P][3] == param.L }
    else
        set var.toolSame = false

; Preserve flute meta across M4000 when F/L are omitted (row is replaced from mosET below).
var preserveF = -1
var preserveL = -1.0
if { global.mosTT[param.P] != null }
    if { #global.mosTT[param.P] > 2 }
        set var.preserveF = global.mosTT[param.P][2]
    if { #global.mosTT[param.P] > 3 }
        set var.preserveL = global.mosTT[param.P][3]

; Definition unchanged — nothing to do (no M563). Sync SD library (captures G10 without M563).
if { var.toolSame }
    if { (!exists(global.nxtUserToolsLoadDepth) || global.nxtUserToolsLoadDepth < 1) && (!exists(global.nxtAutoPersistTools) || global.nxtAutoPersistTools) }
        M98 P"nxt-user-tools-sync.g"
    M99

; Same tool already selected (e.g. T1 active, job preamble M4000 P1 on re-run).
; M563 clears probed Z offsets — skip it entirely.
if { state.currentTool == param.P && #tools > param.P && tools[param.P] != null }
    M99

; Tool exists in RRF but is not the active tool — refresh mosTT metadata only.
if { #tools > param.P && tools[param.P] != null }
    set global.mosTT[param.P] = { global.mosET }
    set global.mosTT[param.P][0] = { param.R }
    if { exists(param.X) }
        set global.mosTT[param.P][1][0] = { param.X }
    if { exists(param.Y) }
        set global.mosTT[param.P][1][1] = { param.Y }
    if { exists(param.F) }
        set global.mosTT[param.P][2] = { param.F }
    elif { var.preserveF >= 0 }
        set global.mosTT[param.P][2] = { var.preserveF }
    if { exists(param.L) }
        set global.mosTT[param.P][3] = { param.L }
    elif { var.preserveL >= 0 }
        set global.mosTT[param.P][3] = { var.preserveL }
    if { (!exists(global.nxtUserToolsLoadDepth) || global.nxtUserToolsLoadDepth < 1) && (!exists(global.nxtAutoPersistTools) || global.nxtAutoPersistTools) }
        M98 P"nxt-user-tools-sync.g"
    M99

; New tool — define in RRF (may deselect the active tool).
var wasSelected = { state.currentTool == param.P }

; Allow spindle ID to be overridden where necessary using I parameter.
M563 P{param.P} S{param.S} R{var.spinId}

; Restore selection without running tool-change macros
if { var.wasSelected }
    T{param.P} P0

; Store tool details in zero-indexed array.
set global.mosTT[param.P] = { global.mosET }

; Set tool radius
set global.mosTT[param.P][0] = { param.R }

; If X and Y parameters are given, these are deemed to be
; the deflection distance of the tool in the relevant axis
; when used for probing. This does not need to be set for
; non-probe tools.
if { exists(param.X) }
    set global.mosTT[param.P][1][0] = { param.X }

if { exists(param.Y) }
    set global.mosTT[param.P][1][1] = { param.Y }

; Optional CAM geometry: flute count (F), flute length mm (L). Omitted params keep prior flute slots when redefining (preserveF / preserveL).
if { exists(param.F) }
    set global.mosTT[param.P][2] = { param.F }
elif { var.preserveF >= 0 }
    set global.mosTT[param.P][2] = { var.preserveF }

if { exists(param.L) }
    set global.mosTT[param.P][3] = { param.L }
elif { var.preserveL >= 0 }
    set global.mosTT[param.P][3] = { var.preserveL }

; Persist full tool library to SD (optional; disable with global nxtAutoPersistTools = false).
; Skip while nxt-user-tools.g is being M98-loaded (nxtUserToolsLoadDepth > 0) to avoid truncating mid-file.
if { (!exists(global.nxtUserToolsLoadDepth) || global.nxtUserToolsLoadDepth < 1) && (!exists(global.nxtAutoPersistTools) || global.nxtAutoPersistTools) }
    M98 P"nxt-user-tools-sync.g"
