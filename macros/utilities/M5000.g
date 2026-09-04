; M5000.g: GET TOOL-COMPENSATED ABSOLUTE POSITION
;
; Calculates the current tool-compensated absolute machine position
; and stores it in global.nxtAbsPos (all axes) or a single axis value.
;
; P0 — all axes (vector). P1 I<axis> — single axis scalar (Jake-compatible).

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

M400

if { !exists(global.nxtAbsPos) }
    global nxtAbsPos = { vector(#move.axes, null) }

; RRF 3.7+: prefer motionSystems[0].workplaceNumber (move.workplaceNumber is obsolete).
var nxtWpIdx = 0
if { exists(move.motionSystems) && #move.motionSystems > 0 }
    set var.nxtWpIdx = { move.motionSystems[0].workplaceNumber }

if { !exists(param.P) || param.P == 0 }
    set global.nxtAbsPos = { vector(#move.axes, null) }
    while { iterations < #move.axes }
        var nxtWpOff = { move.axes[iterations].workplaceOffsets[var.nxtWpIdx] }
        var nxtToolOff = { state.currentTool < 0 ? 0 : tools[state.currentTool].offsets[iterations] }
        set global.nxtAbsPos[iterations] = { var.nxtWpOff + var.nxtToolOff + move.axes[iterations].userPosition }
    M99

if { param.P == 1 && exists(param.I) && param.I >= 0 && param.I < #move.axes }
    var nxtWpOff1 = { move.axes[param.I].workplaceOffsets[var.nxtWpIdx] }
    var nxtToolOff1 = { state.currentTool < 0 ? 0 : tools[state.currentTool].offsets[param.I] }
    set global.nxtAbsPos = { var.nxtWpOff1 + var.nxtToolOff1 + move.axes[param.I].userPosition }
    M99

abort { "M5000: Invalid P parameter (use P0 for all axes, or P1 I<axis> for one axis)." }
