; nxt-m291-corners.g — M291 corner picker (names are local; not in key=global)
;
; USAGE: M98 P"nxt-m291-corners.g" R"<title>" [F<defaultIndex>] [Q1]
;   R: dialog title
;   F: default selection (0-3)
;   Q1: short prompt (G6600); omit for the operator-front note
; Caller reads `input` after return. M98 does not steal R/F/Q.

if { !inputs[state.thisInput].active }
    M99

var nxtCnr = { "Front Left", "Front Right", "Back Right", "Back Left" }
var nxtTitle = { "nxt: Probe Corner" }
if { exists(param.R) && param.R != null }
    set var.nxtTitle = { param.R }
var nxtDef = { 0 }
if { exists(param.F) && param.F != null }
    set var.nxtDef = { param.F }
var nxtP = "Please select the corner to probe.<br/><b>NOTE</b>: Names are relative to an operator at the front of the mill."
if { exists(param.Q) && param.Q == 1 }
    set var.nxtP = { "Select the corner under the probe." }
M291 P{var.nxtP} R{var.nxtTitle} T0 S4 K{var.nxtCnr} F{var.nxtDef}
