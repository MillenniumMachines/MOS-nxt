; M4.9.g: SPINDLE ON, COUNTER-CLOCKWISE - WAIT FOR SPINDLE TO ACCELERATE
;
; USAGE: M4.9 [S<rpm>] [P<spindleID>] [D<overrideDwellSeconds>]

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Validate Spindle ID parameter
if { exists(param.P) && param.P < 0 }
    abort { "Spindle ID must be a positive value!" }

; Allocate Spindle ID
var spindleID = { (exists(param.P) ? param.P : global.nxtSpindleID) }

; Validate Spindle ID
if { var.spindleID < 0 || var.spindleID > #spindles-1 || spindles[var.spindleID] == null || spindles[var.spindleID].state == "unconfigured" }
    abort { "Spindle ID " ^ var.spindleID ^ " is not valid!" }

; Validate Spindle direction
if { !spindles[var.spindleID].canReverse }
    abort { "Spindle #" ^ var.spindleID ^ " is not configured to allow counter-clockwise rotation!" }

; Validate Spindle Speed parameter
if { exists(param.S) }
    if { param.S < 0 }
        abort { "Spindle speed for spindle #" ^ var.spindleID ^ " must be a positive value!" }

    ; If spindle speed is above 0, make sure it is above
    ; the minimum configured speed for the spindle.
    if { param.S < spindles[var.spindleID].min && param.S > 0 }
        abort { "Spindle speed " ^ param.S ^ " is below minimum configured speed " ^ spindles[var.spindleID].min ^ " on spindle #" ^ var.spindleID ^ "!" }

    if { param.S > spindles[var.spindleID].max }
        abort { "Spindle speed " ^ param.S ^ " exceeds maximum configured speed " ^ spindles[var.spindleID].max ^ " on spindle #" ^ var.spindleID ^ "!" }

; Validate Dwell Time override parameter
if { exists(param.D) && param.D < 0 }
    abort { "Dwell time must be a positive value!" }

; Wait for all movement to stop before continuing.
M400

; Dwell time defaults to the previously timed spindle acceleration time.
var dwellTime = { global.nxtSpindleAccelSec }

; D parameter always overrides the dwell time
if { exists(param.D) }
    set var.dwellTime = { param.D }
else
    ; If we're changing spindle speed
    if { exists(param.S) }
        ; If this is a deceleration, adjust dT to use the deceleration timer
        if { spindles[var.spindleID].current > param.S }
            set var.dwellTime = { global.nxtSpindleDecelSec }

        ; Now calculate the change in velocity as a percentage
        set var.dwellTime = { ceil(var.dwellTime * (abs(spindles[var.spindleID].current - param.S) / spindles[var.spindleID].max) * 1.05) }

; All safety checks have now been passed, so we can start the spindle using M4 here.

; Account for all permutations of M4 command
if { exists(param.S) }
    if { exists(param.P) }
        M4 S{param.S} P{param.P}
    else
        M4 S{param.S}
elif { exists(param.P) }
    M4 P{param.P}
else
    M4

; If M4 returns an error, abort.
if { result != 0 }
    abort { "Failed to control Spindle ID " ^ var.spindleID ^ "!" }

if { var.dwellTime > 0 }
    if { !global.nxtExpertMode }
        echo { "NeXT: Waiting " ^ var.dwellTime ^ " seconds for spindle #" ^ var.spindleID ^ " to reach the target speed" }
    G4 S{var.dwellTime}
