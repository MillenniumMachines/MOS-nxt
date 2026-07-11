; M4000.g: DEFINE TOOL
;
; Defines a tool by index.
;
; RRF's tools[] object model (see upstream Tool / OM) exposes name, spindle, offsets, etc.
; — not cutter radius or diameter. M563 updates the real tools[P] record; param.R (radius) is
; stored in global.nxtTT for CAM/DWC. The nxt plugin merges nxtTT into tool rows client-side.
;
; nxtTT[P] = [ radius, {deflX, deflY}, fluteCount(-1), fluteLength(-1.0), tcCapable(1), tsCapable(1) ]
;
; USAGE: M4000 P<idx> R<radius> S"<name>" [I<spindle>] [X<deflX>] [Y<deflY>] [F<flutes>] [L<fluteLen>]
;   [C<0|1>] [B<0|1>] [K1] — K1 required for system writes to nxtReservedFrom (probe/datum slot).

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Belt-and-suspenders if boot skipped nxt-tooltable.g (partial SD update)
if { !exists(global.nxtTT) }
    if { !exists(global.nxtET) }
        global nxtET = { 0.0, {0.0, 0.0}, -1, -1.0, 1, 1 }
    global nxtTT = { vector(limits.tools, null) }

if { !exists(param.P) || !exists(param.R) || !exists(param.S) }
    abort { "Must provide tool number (P...), radius (R...) and description (S...) to register tool!" }

if { #param.S < 1 }
    abort { "Tool description must be at least 1 character long!" }

; Validate tool index
if { param.P >= limits.tools || param.P < 0 }
    abort { "Tool index must be between 0 and " ^ limits.tools-1 ^ "!" }

; Reserved system slot (probe/datum at nxtProbeToolID) may ONLY be written by system macros with K1.
if { exists(global.nxtReservedFrom) && param.P >= global.nxtReservedFrom && (!exists(param.K) || param.K != 1) }
    abort { "Tool " ^ param.P ^ " is a reserved system slot (probe/datum). User tools must be 0-" ^ (global.nxtReservedFrom - 1) ^ "." }

var spinId = { (exists(param.I)) ? param.I : (global.nxtSpindleID != null ? global.nxtSpindleID : 0) }

; Initial tool similarity check - defined in both the RRF tool table and our nxtTT table.
; nxtTT slots may be null (OM-size slim fill) — never use # or [] on a null row.
var rowLen = 0
if { global.nxtTT[param.P] != null }
    set var.rowLen = { #global.nxtTT[param.P] }

var toolSame = { var.rowLen > 0 && #tools > param.P && tools[param.P] != null }

; Radius + spindle match
if { var.toolSame }
    set var.toolSame = { global.nxtTT[param.P][0] == param.R && tools[param.P].spindle == var.spinId }

; Description match
if { var.toolSame }
    set var.toolSame = { tools[param.P].name == param.S }

; Deflection match (probe tools only; cutting tools omit X/Y)
if { var.toolSame && exists(param.X) }
    set var.toolSame = { global.nxtTT[param.P][1][0] == param.X }
if { var.toolSame && exists(param.Y) }
    set var.toolSame = { global.nxtTT[param.P][1][1] == param.Y }

; Optional flute count (F) / flute length (L) match - stored in nxtTT[P][2],[3]; -1 = unset
if { exists(param.F) }
    if { var.rowLen > 2 }
        set var.toolSame = { var.toolSame && global.nxtTT[param.P][2] == param.F }
    else
        set var.toolSame = false
if { exists(param.L) }
    if { var.rowLen > 3 }
        set var.toolSame = { var.toolSame && global.nxtTT[param.P][3] == param.L }
    else
        set var.toolSame = false

; Optional tool-changer-capable flag (C) match - stored in nxtTT[P][4]; default 1
if { exists(param.C) }
    if { var.rowLen > 4 }
        set var.toolSame = { var.toolSame && global.nxtTT[param.P][4] == param.C }
    else
        set var.toolSame = false
if { exists(param.B) }
    if { var.rowLen > 5 }
        set var.toolSame = { var.toolSame && global.nxtTT[param.P][5] == param.B }
    else
        set var.toolSame = false

; Preserve flute + tc/ts-capable meta across M4000 when params omitted (row is replaced below).
var preserveF = -1
var preserveL = -1.0
var preserveC = 1
var preserveB = 1
if { var.rowLen > 2 }
    set var.preserveF = global.nxtTT[param.P][2]
if { var.rowLen > 3 }
    set var.preserveL = global.nxtTT[param.P][3]
if { var.rowLen > 4 }
    set var.preserveC = global.nxtTT[param.P][4]
if { var.rowLen > 5 }
    set var.preserveB = global.nxtTT[param.P][5]

; Definition unchanged — nothing to do (no M563). Sync SD library (captures G10 without M563).
if { var.toolSame }
    if { (!exists(global.nxtUserToolsLoadDepth) || global.nxtUserToolsLoadDepth < 1) && (!exists(global.nxtAutoPersistTools) || global.nxtAutoPersistTools) }
        M98 P"nxt-user-tools-sync.g"
    M99

; Same tool already selected (e.g. T1 active, job preamble M4000 P1 on re-run).
; M563 clears probed Z offsets — skip it entirely.
if { state.currentTool == param.P && #tools > param.P && tools[param.P] != null }
    M99

; Tool exists in RRF but is not the active tool — refresh nxtTT metadata only.
if { #tools > param.P && tools[param.P] != null }
    ; RRF tool name only changes via M563, which RESETS offsets. Rename only when description
    ; changed and tool is not currently loaded; capture Z length first and re-apply afterwards.
    if { tools[param.P].name != param.S && state.currentTool != param.P }
        var savedZ = { (#tools[param.P].offsets > 2) ? tools[param.P].offsets[2] : 0 }
        M563 P{param.P} S{param.S} R{var.spinId}
        G10 L1 P{param.P} Z{var.savedZ}

    set global.nxtTT[param.P] = { global.nxtET }
    set global.nxtTT[param.P][0] = { param.R }
    if { exists(param.X) }
        set global.nxtTT[param.P][1][0] = { param.X }
    if { exists(param.Y) }
        set global.nxtTT[param.P][1][1] = { param.Y }
    if { exists(param.F) }
        set global.nxtTT[param.P][2] = { param.F }
    elif { var.preserveF >= 0 }
        set global.nxtTT[param.P][2] = { var.preserveF }
    if { exists(param.L) }
        set global.nxtTT[param.P][3] = { param.L }
    elif { var.preserveL >= 0 }
        set global.nxtTT[param.P][3] = { var.preserveL }
    if { exists(param.C) }
        set global.nxtTT[param.P][4] = { param.C }
    else
        set global.nxtTT[param.P][4] = { var.preserveC }
    if { exists(param.B) }
        set global.nxtTT[param.P][5] = { param.B }
    else
        set global.nxtTT[param.P][5] = { var.preserveB }
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
set global.nxtTT[param.P] = { global.nxtET }

; Set tool radius
set global.nxtTT[param.P][0] = { param.R }

; If X and Y parameters are given, these are deemed to be
; the deflection distance of the tool in the relevant axis
; when used for probing. This does not need to be set for
; non-probe tools.
if { exists(param.X) }
    set global.nxtTT[param.P][1][0] = { param.X }

if { exists(param.Y) }
    set global.nxtTT[param.P][1][1] = { param.Y }

; Optional CAM geometry: flute count (F), flute length mm (L). Omitted params keep prior flute slots when redefining (preserveF / preserveL).
if { exists(param.F) }
    set global.nxtTT[param.P][2] = { param.F }
elif { var.preserveF >= 0 }
    set global.nxtTT[param.P][2] = { var.preserveF }

if { exists(param.L) }
    set global.nxtTT[param.P][3] = { param.L }
elif { var.preserveL >= 0 }
    set global.nxtTT[param.P][3] = { var.preserveL }

; Tool-changer capable flag (C): 1 = ATC can load it, 0 = hand-load only. Default preserved.
if { exists(param.C) }
    set global.nxtTT[param.P][4] = { param.C }
else
    set global.nxtTT[param.P][4] = { var.preserveC }

; Toolsetter-capable flag (B): 1 = toolsetter can probe its Z, 0 = must be set manually. Default preserved.
if { exists(param.B) }
    set global.nxtTT[param.P][5] = { param.B }
else
    set global.nxtTT[param.P][5] = { var.preserveB }

; Persist full tool library to SD (optional; disable with global nxtAutoPersistTools = false).
; Skip while nxt-user-tools.g is being M98-loaded (nxtUserToolsLoadDepth > 0) to avoid truncating mid-file.
if { (!exists(global.nxtUserToolsLoadDepth) || global.nxtUserToolsLoadDepth < 1) && (!exists(global.nxtAutoPersistTools) || global.nxtAutoPersistTools) }
    M98 P"nxt-user-tools-sync.g"
