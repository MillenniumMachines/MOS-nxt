; M5.9.g: SPINDLE OFF
;
; USAGE: M5.9 [D<overrideDwellSeconds>]

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

if { exists(param.D) && param.D < 0 }
    abort { "Dwell time must be a positive value!" }

; Wait for all movement to stop before continuing.
M400

; Spindles only need to be stopped if they're actually running.
var spindleID = 0
if { exists(global.nxtSpindleID) && global.nxtSpindleID != null }
    set var.spindleID = { global.nxtSpindleID }

var doWait = false

while { iterations < #spindles && !var.doWait }
    ; Ignore unconfigured spindles
    if { spindles[iterations].state == "unconfigured" }
        continue

    set var.doWait = { spindles[iterations].current != 0 }
    ; In case M5.9 should stop a spindle that _isnt_ the one
    ; configured in nxt. We'll calculate the delay time based
    ; on the spindle that is actually running.
    set var.spindleID = { iterations }

; Must calculate dwell time before spindle speed is changed.

; Full nxtSpindleDecelSec (10 s if unset/<=0). D overrides. No RPM scaling.
var dwellTime = 10
if { exists(global.nxtSpindleDecelSec) }
    if { global.nxtSpindleDecelSec != null }
        if { global.nxtSpindleDecelSec > 0 }
            set var.dwellTime = { global.nxtSpindleDecelSec }

; D parameter always overrides the dwell time
if { exists(param.D) }
    set var.dwellTime = { param.D }

; We run M5 unconditionally for safety purposes. If
; the object model is not up to date for whatever
; reason, then this protects us from not stopping
; the spindle when the running gcode expected it to
; be stopped.
M5

; No spindles were running, so don't wait
if { !var.doWait }
    M99

if { var.dwellTime <= 0 }
    M99

if { !global.nxtExpertMode }
    echo { "nxt: Waiting up to " ^ var.dwellTime ^ "s for spindle #" ^ var.spindleID ^ " stop" }

; Prefer ArborCTL not-running; else timed G4. Timeout continues (never abort).
var useVfdStatus = false
if { exists(global.arborVFDStatus) }
    if { global.arborVFDStatus[var.spindleID] != null }
        set var.useVfdStatus = true
if { var.useVfdStatus }
    if { exists(global.arborVFDCommReady) }
        if { !global.arborVFDCommReady[var.spindleID] }
            set var.useVfdStatus = false

if { !var.useVfdStatus }
    G4 S{var.dwellTime}
    M99

if { fileexists("0:/sys/arborctl/control-spindle.g") }
    M98 P"arborctl/control-spindle.g" S{var.spindleID}

var endMs = { state.upTime * 1000 + state.msUpTime + (var.dwellTime * 1000) }
var gotReady = false
while { !var.gotReady && var.endMs > state.upTime * 1000 + state.msUpTime }
    if { !global.arborVFDStatus[var.spindleID][0] }
        set var.gotReady = true
    else
        G4 P250

if { var.gotReady }
    if { !global.nxtExpertMode }
        echo { "nxt: Spindle #" ^ var.spindleID ^ " stopped" }
else
    echo { "nxt: Spindle #" ^ var.spindleID ^ " status timeout — continuing after " ^ var.dwellTime ^ "s" }
