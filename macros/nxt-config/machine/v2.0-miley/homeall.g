; homeall.g — nxt platform v2.0-miley (V2.0 Miley)
; Requirements: see docs/NXT_BOARD_HOMING.md (v2.0-miley — Z, then A if present,
; then X toward max, Y toward min)

; homeall.g - Homes Z, then A if present, then X and Y together.

; Relative positioning in mm and mm/min
G91
G21
G94

; Home Z first to move spindle out of the way
M98 P"homez.g"

; Home A before XY when homea.g is deployed (Custom Save / MosFourthAxis)
if { fileexists("0:/sys/homea.g") }
    M98 P"homea.g"

; Move quickly to X (max) and Y (min) endstops and stop there (first pass)
G53 G1 H1 X{move.axes[0].max - move.axes[0].min + 5} Y{-(move.axes[1].max - move.axes[1].min + 5)} F{1800}

; Endstops should now be triggered, verify
if { ! sensors.endstops[0].triggered }
    abort {"X endstop not triggered after full axis travel. Check that your X motor is connected and the endstop is working!"}
if { ! sensors.endstops[1].triggered }
    abort {"Y endstop not triggered after full axis travel. Check that your Y motor is connected and the endstop is working!"}

; Move away from X and Y endstops
G53 G1 H2 X{-5} Y{5}

; Repeat X and Y home at low speed. Do not move further than
; 2 * 5 further than the expected endstop locations.
G53 G1 H1 X{5*2} Y{-5*2} F{180}
