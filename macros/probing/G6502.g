; G6502.g: RECTANGLE POCKET PROBE
;
; Probes all 4 edges of a rectangular pocket to find the center point.
; Uses single-axis probing for each edge and calculates the geometric center.
; With hit capture (H on G6512), estimates in-plane skew vs machine X and stores angle in
; nxtProbeResults[row][#move.axes] for M6520 / G68. Row index is P, or U-1 when U is given.
;
; USAGE: G6502 P<index>|U<wcs> W<width> H<height> L<depth> [F<speed>] [R<retries>] [C<clearance>] [O<overtravel>] [T<maxSkewDeg>] [Q<6520mode>]
;
; Parameters:
;   P: Result table index (0-based) — legacy measure-only if U omitted - REQUIRED unless U given
;   U: Target workplace number 1..9 (G54..G59.3); storage index = U-1; run M6520 at end
;   W: Pocket width in X direction - REQUIRED
;   H: Pocket height in Y direction - REQUIRED
;   L: Depth to move down into pocket before probing - REQUIRED
;   F,R,C,O: As before
;   T: Optional max |skew| in deg (default global.nxtProbeMaxSkewDeg)
;   Q: Optional M6520 rotation policy when U is used (0=prompt 1=apply 2=never)

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Validate that touch probe feature is enabled and configured
if { !global.nxtFeatureTouchProbe }
    abort { "G6502: Touch probe feature not enabled" }

if { global.nxtTouchProbeID == null }
    abort { "G6502: Touch probe ID not configured" }

; Ensure we're using the touch probe
if { state.currentTool != global.nxtProbeToolID }
    abort { "G6502: Touch probe (T" ^ global.nxtProbeToolID ^ ") must be selected" }

var pSlot = null
if { exists(param.U) && param.U != null }
    if { param.U < 1 || param.U > 9 }
        abort { "G6502: U (target WCS) must be 1-9" }
    set var.pSlot = { param.U - 1 }
elif { exists(param.P) && param.P != null }
    set var.pSlot = { param.P }
else
    abort { "G6502: P (result index) or U (target workplace 1-9) is required" }

if { var.pSlot < 0 || var.pSlot >= #global.nxtProbeResults }
    abort { "G6502: Result slot out of range" }

if { !exists(param.W) || param.W == null || param.W <= 0 }
    abort { "G6502: Width W is required and must be positive" }
if { !exists(param.H) || param.H == null || param.H <= 0 }
    abort { "G6502: Height H is required and must be positive" }
if { !exists(param.L) || param.L == null || param.L <= 0 }
    abort { "G6502: Depth L is required and must be positive" }

; Set parameters
var feedRate = { exists(param.F) ? param.F : null }
var retries = { exists(param.R) ? param.R : global.nxtProbeInnerSampleCount }
var pocketWidth = { param.W }
var pocketHeight = { param.H }
var probeDepth = { param.L }
var clearance = { exists(param.C) ? param.C : 5.0 }
var overtravel = { exists(param.O) ? param.O : 2.0 }
var skewLimit = { exists(param.T) ? param.T : global.nxtProbeMaxSkewDeg }

echo "G6502: Starting rectangle pocket probe cycle"

; Get current position (should be approximately at pocket center)
M5000
var centerX = { global.nxtAbsPos[0] }
var centerY = { global.nxtAbsPos[1] }
var startZ = { global.nxtAbsPos[2] }

; Calculate probe distances (half dimension plus overtravel)
var xProbeDistance = { var.pocketWidth / 2 + var.overtravel }
var yProbeDistance = { var.pocketHeight / 2 + var.overtravel }

; Move down into the pocket before starting probes
var probeZ = { var.startZ - var.probeDepth }
G6550 Z{var.probeZ}

echo "G6502: Probing rectangular pocket " ^ var.pocketWidth ^ "x" ^ var.pocketHeight ^ "mm"

; Probe +X edge (right side of pocket)
echo "G6502: Probing +X edge"
var xPlusTarget = { var.centerX + var.xProbeDistance }
G6512 X{var.xPlusTarget} I{global.nxtTouchProbeID} F{var.feedRate} R{var.retries} H0

; Move back to center for next probe
G6550 X{var.centerX}

; Probe -X edge (left side of pocket)
echo "G6502: Probing -X edge"
var xMinusTarget = { var.centerX - var.xProbeDistance }
G6512 X{var.xMinusTarget} I{global.nxtTouchProbeID} F{var.feedRate} R{var.retries} H1

; Move back to center for next probe
G6550 X{var.centerX}

; Probe +Y edge (front of pocket)
echo "G6502: Probing +Y edge"
var yPlusTarget = { var.centerY + var.yProbeDistance }
G6512 Y{var.yPlusTarget} I{global.nxtTouchProbeID} F{var.feedRate} R{var.retries} H2

; Move back to center for next probe
G6550 Y{var.centerY}

; Probe -Y edge (back of pocket)
echo "G6502: Probing -Y edge"
var yMinusTarget = { var.centerY - var.yProbeDistance }
G6512 Y{var.yMinusTarget} I{global.nxtTouchProbeID} F{var.feedRate} R{var.retries} H3

; Chord vectors from opposing pocket walls; skew θ = angle of X chord vs machine X.
; Center = mean of (midpoint of X pair) and (midpoint of Y pair) — see G6500 header.
if { !exists(global.nxtProbeHitXY) || global.nxtProbeHitXY == null || #global.nxtProbeHitXY < 8 }
    abort { "G6502: Missing probe hits in nxtProbeHitXY" }

var xPx = { global.nxtProbeHitXY[0] }
var xPy = { global.nxtProbeHitXY[1] }
var xMx = { global.nxtProbeHitXY[2] }
var xMy = { global.nxtProbeHitXY[3] }
var yPx = { global.nxtProbeHitXY[4] }
var yPy = { global.nxtProbeHitXY[5] }
var yMx = { global.nxtProbeHitXY[6] }
var yMy = { global.nxtProbeHitXY[7] }

if { var.xPx == null || var.xPy == null || var.xMx == null || var.xMy == null }
    abort { "G6502: Null ±X hit — check G6512 H0/H1 writes" }
if { var.yPx == null || var.yPy == null || var.yMx == null || var.yMy == null }
    abort { "G6502: Null ±Y hit — check G6512 H2/H3 writes" }

var vx = { var.xPx - var.xMx }
var vy = { var.xPy - var.xMy }
var wx = { var.yPx - var.yMx }
var wy = { var.yPy - var.yMy }

var thetaRad = { atan2(var.vy, var.vx) }
var thetaDeg = { var.thetaRad * 180 / pi }
; Fold to (−90, 90] so reversed ±X hit order does not yield ~±180°
if { var.thetaDeg > 90 }
    set var.thetaDeg = { var.thetaDeg - 180 }
elif { var.thetaDeg <= -90 }
    set var.thetaDeg = { var.thetaDeg + 180 }

if { abs(var.thetaDeg) > var.skewLimit }
    abort { "G6502: |skew| " ^ var.thetaDeg ^ " deg exceeds limit " ^ var.skewLimit }

var m1x = { (var.xPx + var.xMx) / 2 }
var m1y = { (var.xPy + var.xMy) / 2 }
var m2x = { (var.yPx + var.yMx) / 2 }
var m2y = { (var.yPy + var.yMy) / 2 }
var calculatedCenterX = { (var.m1x + var.m2x) / 2 }
var calculatedCenterY = { (var.m1y + var.m2y) / 2 }

var xPlusEdge = { var.calculatedCenterX + var.vx / 2 }
var xMinusEdge = { var.calculatedCenterX - var.vx / 2 }
var yPlusEdge = { var.calculatedCenterY + var.wy / 2 }
var yMinusEdge = { var.calculatedCenterY - var.wy / 2 }

; Chord length = true wall spacing (projected |vx|/|wy| underestimate when skewed)
var actualWidth = { sqrt(var.vx * var.vx + var.vy * var.vy) }
var actualHeight = { sqrt(var.wx * var.wx + var.wy * var.wy) }

; Log results to probe results table
if { global.nxtProbeResults[var.pSlot] == null || #global.nxtProbeResults[var.pSlot] < 3 }
    set global.nxtProbeResults[var.pSlot] = { vector(#move.axes + 1, 0.0) }

set global.nxtProbeResults[var.pSlot][0] = { var.calculatedCenterX }
set global.nxtProbeResults[var.pSlot][1] = { var.calculatedCenterY }
set global.nxtProbeResults[var.pSlot][#move.axes] = { var.thetaDeg }

; Move to calculated center
G6550 X{var.calculatedCenterX} Y{var.calculatedCenterY}

; Return to start height
G6550 Z{var.startZ}

echo "G6502: Rectangle pocket probe completed"
echo "G6502: Pocket center at X=" ^ var.calculatedCenterX ^ " Y=" ^ var.calculatedCenterY
echo "G6502: Approx skew vs machine X: " ^ var.thetaDeg ^ " deg"
echo "G6502: Measured dimensions: " ^ var.actualWidth ^ "x" ^ var.actualHeight ^ "mm"
echo "G6502: Result logged to table index " ^ var.pSlot

if { exists(param.U) && param.U != null }
    if { exists(param.Q) && param.Q != null }
        M6520 P{var.pSlot} W{param.U} X1 Y1 T{var.skewLimit} Q{param.Q}
    else
        M6520 P{var.pSlot} W{param.U} X1 Y1 T{var.skewLimit}
