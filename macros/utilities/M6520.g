; M6520.g: SET WCS OFFSET FROM PROBE RESULT
;
; Sets a Work Coordinate System (WCS) offset using coordinates from the probe results table.
;
; USAGE: M6520 P<resultIndex> W<wcsNumber> [X] [Y] [Z] [A]
;
; Parameters:
;   P: Probe results table index (0-9) to read from - REQUIRED
;   W: WCS number (1-9 for G54-G59.3) - REQUIRED
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
if { !exists(param.W) || param.W == null || param.W < 1 || param.W > 9 }
    abort { "M6520: WCS number W is required and must be 1-9 (for G54-G59.3)" }

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
; G10 L2 P<wcs> X Y Z A sets the WCS origin coordinates in machine coordinates
; The probe result IS the desired origin in machine coordinates, so we use it directly

var wcsNumber = { param.W }

; Use probe result coordinates directly as the origin
; Only set axes that are flagged AND have non-zero values

var offsetX = { exists(param.X) && var.resultVector[0] != 0 ? var.resultVector[0] : null }
var offsetY = { exists(param.Y) && var.resultVector[1] != 0 ? var.resultVector[1] : null }
var offsetZ = { exists(param.Z) && var.resultVector[2] != 0 ? var.resultVector[2] : null }
var offsetA = { exists(param.A) && #var.resultVector > 3 && var.resultVector[3] != 0 ? var.resultVector[3] : null }

; Execute G10 L2 command directly based on which axes are specified
; G10 L2 P<n> X Y Z A sets the WCS origin coordinates
; We must call G10 L2 with the appropriate combination of axes

if { var.offsetX != null && var.offsetY != null && var.offsetZ != null && var.offsetA != null }
    G10 L2 P{var.wcsNumber} X{var.offsetX} Y{var.offsetY} Z{var.offsetZ} A{var.offsetA}
elif { var.offsetX != null && var.offsetY != null && var.offsetZ != null }
    G10 L2 P{var.wcsNumber} X{var.offsetX} Y{var.offsetY} Z{var.offsetZ}
elif { var.offsetX != null && var.offsetY != null && var.offsetA != null }
    G10 L2 P{var.wcsNumber} X{var.offsetX} Y{var.offsetY} A{var.offsetA}
elif { var.offsetX != null && var.offsetZ != null && var.offsetA != null }
    G10 L2 P{var.wcsNumber} X{var.offsetX} Z{var.offsetZ} A{var.offsetA}
elif { var.offsetY != null && var.offsetZ != null && var.offsetA != null }
    G10 L2 P{var.wcsNumber} Y{var.offsetY} Z{var.offsetZ} A{var.offsetA}
elif { var.offsetX != null && var.offsetY != null }
    G10 L2 P{var.wcsNumber} X{var.offsetX} Y{var.offsetY}
elif { var.offsetX != null && var.offsetZ != null }
    G10 L2 P{var.wcsNumber} X{var.offsetX} Z{var.offsetZ}
elif { var.offsetX != null && var.offsetA != null }
    G10 L2 P{var.wcsNumber} X{var.offsetX} A{var.offsetA}
elif { var.offsetY != null && var.offsetZ != null }
    G10 L2 P{var.wcsNumber} Y{var.offsetY} Z{var.offsetZ}
elif { var.offsetY != null && var.offsetA != null }
    G10 L2 P{var.wcsNumber} Y{var.offsetY} A{var.offsetA}
elif { var.offsetZ != null && var.offsetA != null }
    G10 L2 P{var.wcsNumber} Z{var.offsetZ} A{var.offsetA}
elif { var.offsetX != null }
    G10 L2 P{var.wcsNumber} X{var.offsetX}
elif { var.offsetY != null }
    G10 L2 P{var.wcsNumber} Y{var.offsetY}
elif { var.offsetZ != null }
    G10 L2 P{var.wcsNumber} Z{var.offsetZ}
elif { var.offsetA != null }
    G10 L2 P{var.wcsNumber} A{var.offsetA}

echo "M6520: Set WCS G" ^ (53 + var.wcsNumber) ^ " origin from probe result " ^ param.P
if { var.offsetX != null }
    echo "M6520:   X origin = " ^ var.offsetX
if { var.offsetY != null }
    echo "M6520:   Y origin = " ^ var.offsetY
if { var.offsetZ != null }
    echo "M6520:   Z origin = " ^ var.offsetZ
if { var.offsetA != null }
    echo "M6520:   A origin = " ^ var.offsetA
