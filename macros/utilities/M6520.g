; M6520.g: SET WCS OFFSET FROM PROBE RESULT
;
; Sets a Work Coordinate System (WCS) offset using coordinates from the probe results table.
; Optional XY workplace rotation uses RRF G68 (coordinate rotation in the XY plane) after G10 L2.
; After apply: select target WCS, then travel to work 0 on flagged X/Y/A only.
; Never commands work Z0 — Z WCS is set via G10; cycles return to startZ themselves.
; XY-only uses G0 X0 Y0 and keeps current Z. X- or Y-only moves that axis alone.
;
; USAGE: M6520 P<resultIndex> W<wcsNumber> [X1] [Y1] [Z1] [A1] [Q<mode>] [T<maxSkew>]
;
; Parameters:
;   P: Probe results table index (0-9) to read from - REQUIRED
;   W: WCS number (1-9 for G54-G59.3) - REQUIRED
;   X1/Y1/Z1/A1: Axis presence flags (RRF needs letter+number; value ignored)
;       Bare X/Y/Z/A often do NOT populate exists(param.X) — use X1 not X
;   X: If present, set X offset from result
;   Y: If present, set Y offset from result
;   Z: If present, set Z offset from result (no post-apply Z travel)
;   A: If present, set A offset from result
;   Q: Rotation policy when nxtProbeResults[P][#move.axes] holds skew (deg):
;      0 or omitted — prompt (M291) to apply or skip rotation
;      1 — apply G68 without prompt (automation)
;      2 — translation only, never apply G68
;   T: Optional override for max |skew| allowed (deg); default global.nxtProbeMaxSkewDeg
;
; Rotation (G68) is only applied when both X and Y are updated together.
; Requires RRF with G68 (CNC / coordinate rotation). Branch v0.7.0 targets **3.7.x**; G68 sign correct from **3.6.1** onward.
;
; G10 L2 values are probe result machine coords minus current tool offsets
; (M5000: machine = WP + tool + user) so userPosition is ~0 at the feature.
; Z results are raw trigger (G6512; no tip radius / Z deflection).
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

var skewLimit = { exists(param.T) ? param.T : global.nxtProbeMaxSkewDeg }
var qMode = { exists(param.Q) ? param.Q : 0 }

var thetaDeg = { #var.resultVector > #move.axes ? var.resultVector[#move.axes] : 0 }

if { abs(var.thetaDeg) > var.skewLimit }
    abort { "M6520: Probe rotation " ^ var.thetaDeg ^ " deg exceeds limit " ^ var.skewLimit ^ " — square the part or increase T / nxtProbeMaxSkewDeg" }

var wcsNumber = { param.W }

; Tool offsets so G10 L2 yields tip userPosition ~0 (machine = WP + tool + user)
var toolOffX = 0
var toolOffY = 0
var toolOffZ = 0
var toolOffA = 0
if { state.currentTool >= 0 }
    set var.toolOffX = { tools[state.currentTool].offsets[0] }
    set var.toolOffY = { tools[state.currentTool].offsets[1] }
    set var.toolOffZ = { tools[state.currentTool].offsets[2] }
    if { #move.axes > 3 }
        set var.toolOffA = { tools[state.currentTool].offsets[3] }

; Probe results are machine coords at the feature; WP = machine - tool → user ~0
; Only set axes that are flagged (allow real origin at 0 — do not treat 0 as "unset")
var offsetX = { exists(param.X) ? var.resultVector[0] - var.toolOffX : null }
var offsetY = { exists(param.Y) ? var.resultVector[1] - var.toolOffY : null }
var offsetZ = { exists(param.Z) ? var.resultVector[2] - var.toolOffZ : null }
var offsetA = null
if { exists(param.A) && #var.resultVector > 3 }
    set var.offsetA = { var.resultVector[3] - var.toolOffA }

; Execute G10 L2 for flagged axes only
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

; --- Optional G68 rotation (XY), about WCS origin after G10 ---

var applyG68 = false

if { exists(param.X) && exists(param.Y) && abs(var.thetaDeg) >= 0.0005 }
    if { var.qMode == 2 }
        echo "M6520: Skipping G68 (Q2 translation only)"
    elif { var.qMode == 1 }
        set var.applyG68 = true
    else
        M291 P{"Probe skew: " ^ var.thetaDeg ^ " deg. Apply G68 to G" ^ (53 + var.wcsNumber) ^ "?"} R"nxt: Rotation" S4 K{"Apply", "Skip"} F1
        if { input == 0 }
            set var.applyG68 = true

; Always select target WCS so DRO uses the updated offsets
M98 P"nxt-select-wcs.g" W{var.wcsNumber}

if { var.applyG68 }
    ; XY plane, cancel any prior G68, then rotate about WCS origin (3.6.1+ sign)
    ; RRF ≥3.6.1: G68 R is anticlockwise — matches atan2 edge/chord θ vs machine +X
    G17
    G69
    G68 X0 Y0 R{var.thetaDeg}
    ; Job-scoped: persist across toolchanges; cleared on cancel / job finish
    set global.nxtJobG68Deg = { var.thetaDeg }
    set global.nxtJobG68Wcs = { var.wcsNumber }
    echo "M6520: G68 rotation applied R" ^ var.thetaDeg ^ " deg about current WCS origin"

; Travel to work 0 on flagged X/Y/A only — never command work Z0
; (Z WCS is set above; G6510/G6520 return to startZ in machine coords)
M400
if { exists(param.X) && exists(param.Y) && exists(param.A) }
    G0 X0 Y0 A0
elif { exists(param.X) && exists(param.Y) }
    G0 X0 Y0
elif { exists(param.X) && exists(param.A) }
    G0 X0 A0
elif { exists(param.Y) && exists(param.A) }
    G0 Y0 A0
elif { exists(param.X) }
    G0 X0
elif { exists(param.Y) }
    G0 Y0
elif { exists(param.A) }
    G0 A0

if { exists(param.Z) && !exists(param.X) && !exists(param.Y) }
    echo "M6520: WCS Z set; Z height unchanged (cycle returns to startZ)"
elif { exists(param.X) && exists(param.Y) && exists(param.Z) }
    echo "M6520: Traveled to X0 Y0; Z unchanged (cycle returns to startZ)"
elif { exists(param.X) && exists(param.Y) && !exists(param.Z) }
    echo "M6520: Traveled to X0 Y0; Z unchanged (start/park height)"
elif { exists(param.X) && !exists(param.Y) && !exists(param.Z) }
    echo "M6520: Traveled to X0 (side surface); other axes unchanged"
elif { exists(param.Y) && !exists(param.X) && !exists(param.Z) }
    echo "M6520: Traveled to Y0 (side surface); other axes unchanged"
elif { exists(param.X) || exists(param.Y) || exists(param.A) }
    echo "M6520: Traveled to work origin on flagged X/Y/A (Z unchanged)"
elif { exists(param.Z) }
    echo "M6520: WCS Z set; Z height unchanged (cycle returns to startZ)"
else
    echo "M6520: WCS updated; no travel"
