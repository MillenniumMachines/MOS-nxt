; G27.g: PARK
;
; Park spindle, and center the work area in an accessible location.
;
; USAGE: G27

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Cancel any G68 first. RRF doesn't rotate G53 moves, but it rebuilds every axis
; from the last position, which it keeps in the rotated frame, so the Z move below
; would also shift X/Y by about θ × distance from the work origin, with no limit
; check. Keeps nxtJobG68Deg: tpost, resume.g and the next M5011 put G68 back.
if { exists(move.motionSystems) }
    if { #move.motionSystems > 0 }
        if { move.motionSystems[0].rotation.angle != 0 }
            G69

; Use absolute positions in mm
G90
G21
G94

; Turn off all coolant outputs
M9

; Move spindle to top of Z travel
if { move.axes[2].homed }
    G53 G0 Z{move.axes[2].max}

; Wait for movement to stop
M400

; Stop spindle and wait
M5.9

; If park is called with Z parameter, then the table itself will not be
; moved.
if { !exists(param.Z) && move.axes[0].homed && move.axes[1].homed }
    var nxtParkX = { (move.axes[0].max - move.axes[0].min) / 2 }
    var nxtParkY = { move.axes[1].max }
    echo "G27: table X=" ^ var.nxtParkX ^ " Y=" ^ var.nxtParkY
    G53 G0 X{var.nxtParkX} Y{var.nxtParkY}

; Wait for movement to stop
M400