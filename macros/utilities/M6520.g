; M6520.g: SET WCS OFFSET FROM PROBE RESULT
;
; Sets a Work Coordinate System (WCS) offset using coordinates from the probe results table.
;
; USAGE: M6520 P<resultIndex> W<wcsNumber> [X] [Y] [Z] [A]
;
; Parameters:
;   P: Probe results table index (0-9) to read from - REQUIRED
;   W: WCS number (1-6 for G54-G59) - REQUIRED
;   X: If present, set X offset from result
;   Y: If present, set Y offset from result
;   Z: If present, set Z offset from result
;   A: If present, set A offset from result
;
; At least one axis flag (X, Y, Z, or A) must be specified.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Validate result index parameter
if { !exists(param.P) || param.P == null || param.P < 0 }
    abort { "M6520: Result index parameter P is required and must be >= 0" }

if { param.P >= #global.nxtProbeResults }
    abort { "M6520: Result index P=" ^ param.P ^ " exceeds table size (" ^ #global.nxtProbeResults ^ ")" }

; Validate WCS number parameter
if { !exists(param.W) || param.W == null || param.W < 1 || param.W > 6 }
    abort { "M6520: WCS number W is required and must be 1-6 (for G54-G59)" }

; Check that at least one axis is specified
if { !exists(param.X) && !exists(param.Y) && !exists(param.Z) && !exists(param.A) }
    abort { "M6520: At least one axis flag (X, Y, Z, or A) must be specified" }

; Check if result exists
if { global.nxtProbeResults[param.P] == null }
    abort { "M6520: No probe result found at index " ^ param.P }

; Get the probe result vector
var resultVector = { global.nxtProbeResults[param.P] }

; Validate result vector size
if { #var.resultVector < #move.axes }
    abort { "M6520: Invalid probe result at index " ^ param.P }

; Get current machine position to preserve unspecified axes
M5000

; Build the offset command
; G10 L2 P<wcs> sets the WCS origin relative to machine zero
; We need to set the offset so that current position becomes the specified coordinate

var wcsNumber = { param.W }

; Calculate offsets: offset = current_position - desired_origin
; For each axis, if the flag is present, use the probe result as the desired origin

var offsetX = { exists(param.X) && var.resultVector[0] != 0 ? (global.nxtAbsPos[0] - var.resultVector[0]) : null }
var offsetY = { exists(param.Y) && var.resultVector[1] != 0 ? (global.nxtAbsPos[1] - var.resultVector[1]) : null }
var offsetZ = { exists(param.Z) && var.resultVector[2] != 0 ? (global.nxtAbsPos[2] - var.resultVector[2]) : null }
var offsetA = { exists(param.A) && #var.resultVector > 3 && var.resultVector[3] != 0 ? (global.nxtAbsPos[3] - var.resultVector[3]) : null }

; Build and execute the G10 L2 command
; Note: G10 L2 P<n> X Y Z A sets absolute offsets for the specified WCS
var gcode = "G10 L2 P" ^ var.wcsNumber

if { var.offsetX != null }
    set var.gcode = { var.gcode ^ " X" ^ var.offsetX }

if { var.offsetY != null }
    set var.gcode = { var.gcode ^ " Y" ^ var.offsetY }

if { var.offsetZ != null }
    set var.gcode = { var.gcode ^ " Z" ^ var.offsetZ }

if { var.offsetA != null }
    set var.gcode = { var.gcode ^ " A" ^ var.offsetA }

; Execute the WCS offset command
{ var.gcode }

echo "M6520: Set WCS G" ^ (53 + var.wcsNumber) ^ " from probe result " ^ param.P
if { var.offsetX != null }
    echo "M6520:   X origin at " ^ var.resultVector[0]
if { var.offsetY != null }
    echo "M6520:   Y origin at " ^ var.resultVector[1]
if { var.offsetZ != null }
    echo "M6520:   Z origin at " ^ var.resultVector[2]
if { var.offsetA != null }
    echo "M6520:   A origin at " ^ var.resultVector[3]
