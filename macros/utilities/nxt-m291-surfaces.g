; nxt-m291-surfaces.g — M291 surface picker (names are local; not in key=global)
;
; USAGE: M98 P"nxt-m291-surfaces.g" [R"<title>"] [F<defaultIndex>]
;   R: dialog title (default nxt: Probe Surface)
;   F: default selection (0=Left … 4=Top)
; Caller reads `input` after return. M98 does not steal R/F.

if { !inputs[state.thisInput].active }
    M99

var nxtSfc = { "Left", "Right", "Front", "Back", "Top" }
var nxtTitle = { "nxt: Probe Surface" }
if { exists(param.R) && param.R != null }
    set var.nxtTitle = { param.R }
var nxtDef = { 4 }
if { exists(param.F) && param.F != null }
    set var.nxtDef = { param.F }
var nxtP = "Please select the surface to probe.<br/><b>NOTE</b>: Names are relative to an operator at the front of the mill."
M291 P{var.nxtP} R{var.nxtTitle} T0 S4 F{var.nxtDef} K{var.nxtSfc}
