; M3.9.g: SPINDLE ON, CLOCKWISE - WAIT FOR SPINDLE TO ACCELERATE
;
; USAGE: M3.9 [S<rpm>] [P<spindleID>] [D<overrideDwellSeconds>]

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Validate Spindle ID parameter
if { exists(param.P) && param.P < 0 }
    abort { "Spindle ID must be a positive value!" }

; Allocate Spindle ID
var spindleID = 0
if { exists(param.P) }
    set var.spindleID = { param.P }
elif { exists(global.nxtSpindleID) && global.nxtSpindleID != null }
    set var.spindleID = { global.nxtSpindleID }

; Validate Spindle ID
if { var.spindleID < 0 || var.spindleID > #spindles-1 || spindles[var.spindleID] == null || spindles[var.spindleID].state == "unconfigured" }
    abort { "Spindle ID " ^ var.spindleID ^ " is not valid!" }

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

; Full nxtSpindleAccelSec (10 s if unset/<=0). D overrides. Decel uses nxtSpindleDecelSec.
; No RPM scaling — timeout matches VFD J/K ramp seconds from Apply.
var dwellTime = 10
if { exists(global.nxtSpindleAccelSec) }
    if { global.nxtSpindleAccelSec != null }
        if { global.nxtSpindleAccelSec > 0 }
            set var.dwellTime = { global.nxtSpindleAccelSec }

; D parameter always overrides the dwell time
if { exists(param.D) }
    set var.dwellTime = { param.D }
elif { exists(param.S) }
    ; Slowing down: use full deceleration seconds as the wait ceiling
    if { spindles[var.spindleID].current > param.S }
        set var.dwellTime = 10
        if { exists(global.nxtSpindleDecelSec) }
            if { global.nxtSpindleDecelSec != null }
                if { global.nxtSpindleDecelSec > 0 }
                    set var.dwellTime = { global.nxtSpindleDecelSec }

; All safety checks have now been passed, so we can start the spindle using M3 here.

; Account for all permutations of M3 command
if { exists(param.S) }
    if { exists(param.P) }
        M3 S{param.S} P{param.P}
    else
        M3 S{param.S}
elif { exists(param.P) }
    M3 P{param.P}
else
    M3

; If M3 returns an error, abort.
if { result != 0 }
    abort { "Failed to control Spindle ID " ^ var.spindleID ^ "!" }

if { var.dwellTime <= 0 }
    M99

if { !global.nxtExpertMode }
    echo { "nxt: Waiting up to " ^ var.dwellTime ^ "s for spindle #" ^ var.spindleID ^ " ready" }

; Prefer ArborCTL stable flag; else timed G4. Timeout continues (never abort).
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
    if { global.arborVFDStatus[var.spindleID][4] }
        set var.gotReady = true
    else
        G4 P250

if { var.gotReady }
    if { !global.nxtExpertMode }
        echo { "nxt: Spindle #" ^ var.spindleID ^ " stable" }
else
    echo { "nxt: Spindle #" ^ var.spindleID ^ " status timeout — continuing after " ^ var.dwellTime ^ "s" }
