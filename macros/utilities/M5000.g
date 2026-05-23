; M5000.g: GET TOOL-COMPENSATED ABSOLUTE POSITION
;
; Calculates the current tool-compensated absolute machine position
; and stores it in the global.nxtAbsPos array.
;
; This macro accounts for the current tool's offsets.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

M400 ; Wait for all moves to complete before reading positions

; Ensure the global variable is initialized as a 4-element array (X,Y,Z,A)
var numAxes          = { #move.axes }
var currentTool      = { state.currentTool }
set global.nxtAbsPos = { vector(var.numAxes, null) }

while { iterations < var.numAxes }
    var nxtWpOff = { move.axes[iterations].workplaceOffsets[move.workplaceNumber] }
    var nxtToolOff = { var.currentTool < 0 ? 0 : tools[var.currentTool].offsets[iterations] }
    set global.nxtAbsPos[iterations] = { var.nxtWpOff + var.nxtToolOff + move.axes[iterations].userPosition }