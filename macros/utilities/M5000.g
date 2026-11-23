; M5000.g: GET ABSOLUTE MACHINE POSITION
;
; Stores the current machine position, the coordinates G53 moves use, in
; global.nxtAbsPos (all axes) or a single axis value. No workplace or tool offset
; is applied: RRF's userPosition already includes both (user = machine - workplace
; + tool offset), so adding the tool offset to it put nxtAbsPos twice the offset
; away from the machine, and G53 moves built from it missed by that much (#76).
; With the probe (L1 = 0) the result is the same as before.
;
; P0 — all axes (vector). P1 I<axis> — single axis scalar (Jake-compatible).

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

M400

if { !exists(global.nxtAbsPos) }
    global nxtAbsPos = { vector(#move.axes, null) }

if { !exists(param.P) || param.P == 0 }
    set global.nxtAbsPos = { vector(#move.axes, null) }
    while { iterations < #move.axes }
        set global.nxtAbsPos[iterations] = { move.axes[iterations].machinePosition }
    M99

if { param.P == 1 && exists(param.I) && param.I >= 0 && param.I < #move.axes }
    set global.nxtAbsPos = { move.axes[param.I].machinePosition }
    M99

abort { "M5000: Invalid P parameter (use P0 for all axes, or P1 I<axis> for one axis)." }
