; M6515.g: CHECK MACHINE LIMITS
;
; Aborts if the specified position is outside machine limits.
; This macro is designed to be called with axis letters as parameters.
;
; USAGE: M6515 [X<pos>] [Y<pos>] [Z<pos>] ...

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Create a parameter array to iterate over (can't iterate over params directly)
var axisCoords = { null, null, null, null, null, null, null, null, null }
if { exists(param.X) }
    set var.axisCoords[0] = param.X
if { exists(param.Y) }
    set var.axisCoords[1] = param.Y
if { exists(param.Z) }
    set var.axisCoords[2] = param.Z
if { exists(param.A) }
    set var.axisCoords[3] = param.A
if { exists(param.B) }
    set var.axisCoords[4] = param.B
if { exists(param.C) }
    set var.axisCoords[5] = param.C
if { exists(param.U) }
    set var.axisCoords[6] = param.U
if { exists(param.V) }
    set var.axisCoords[7] = param.V
if { exists(param.W) }
    set var.axisCoords[8] = param.W

; Iterate over all axes to check any provided coordinate parameters
while { iterations < #move.axes && iterations < #var.axisCoords }
    if { var.axisCoords[iterations] != null }
        var coord = { var.axisCoords[iterations] }
        var axisLetter = { move.axes[iterations].letter }
        if { var.coord < move.axes[iterations].min || var.coord > move.axes[iterations].max }
            abort { "M6515: Position " ^ var.coord ^ " for axis " ^ var.axisLetter ^ " is outside machine limits (" ^ move.axes[iterations].min ^ " to " ^ move.axes[iterations].max ^ ")" }
