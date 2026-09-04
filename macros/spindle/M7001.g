; M7001.g: DISABLE VSSC
;
; USAGE: M7001

if { !inputs[state.thisInput].active }
    M99

set global.nxtVSEnabled = false

var sid = 0
if { exists(global.nxtSpindleID) && global.nxtSpindleID != null }
    set var.sid = { global.nxtSpindleID }

var restore = false
var spState = "unconfigured"
if { var.sid >= 0 && var.sid < #spindles }
    if { spindles[var.sid] != null }
        set var.spState = { spindles[var.sid].state }
        if { var.spState == "forward" || var.spState == "reverse" }
            if { global.nxtVSPS > 0 }
                set var.restore = true

if { var.restore }
    var hasTool = false
    if { state.currentTool >= 0 }
        if { state.currentTool < limits.tools }
            set var.hasTool = true
    if { var.hasTool }
        M568 F{global.nxtVSPS}
    elif { var.spState == "reverse" }
        M4 S{global.nxtVSPS} P{var.sid}
    else
        M3 S{global.nxtVSPS} P{var.sid}

set global.nxtVSPT = 0
set global.nxtVSPS = 0
