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

; Dwell: nxtSpindleDecelSec (10 s if unset/<=0). D overrides.
var dwellTime = 10
if { exists(global.nxtSpindleDecelSec) }
    if { global.nxtSpindleDecelSec != null }
        if { global.nxtSpindleDecelSec > 0 }
            set var.dwellTime = { global.nxtSpindleDecelSec }

; D parameter always overrides the dwell time
if { exists(param.D) }
    set var.dwellTime = { param.D }
elif { var.doWait }
    ; Scale wait by |current|/max. If the indexed spindle is invalid,
    ; M5 still runs below but we do not wait.
    if { spindles[var.spindleID].current != null && spindles[var.spindleID].max != null }
        set var.dwellTime = { ceil(var.dwellTime * (abs(spindles[var.spindleID].current) / spindles[var.spindleID].max) * 1.05) }

; We run M5 unconditionally for safety purposes. If
; the object model is not up to date for whatever
; reason, then this protects us from not stopping
; the spindle when the running gcode expected it to
; be stopped.
M5

; No spindles were running, so don't wait
if { !var.doWait }
    M99

if { var.dwellTime > 0 }
    if { !global.nxtExpertMode }
        echo { "nxt: Waiting " ^ var.dwellTime ^ " seconds for spindle #" ^ var.spindleID ^ " to stop" }
    G4 S{var.dwellTime}
