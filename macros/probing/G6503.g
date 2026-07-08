; G6503.g: RECTANGLE BLOCK PROBE
;
; Probes all four faces from *outside* the stock: retract to clearance, plunge, probe inward
; past the nominal face (target = half-dimension ± overtravel *toward* the block interior).
; First pair (+X/−X) fixes line of action; Y pair jogs to the X-midpoint so both Y touches
; span the true width. Z retracts between faces to avoid dragging.
;
; Four H-slots → skew + center same as pocket/bore cycles; result written to nxtProbeResults; M6520 if U.
;
; USAGE: G6503 P<index>|U<wcs> W<width> H<height> L<depth> [F<speed>] [R<retries>] [C<clearance>] [O<overtravel>] [T<maxSkewDeg>] [Q<6520mode>]
;
;   P: Result index — required if U omitted (measure-only)
;   U: Target workplace 1..9; storage index = U-1; chain M6520 at end
;   W,H,L: Width, height, depth — REQUIRED
;   T,Q: Optional skew limit and M6520 Q rotation policy

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

if { !global.nxtFeatureTouchProbe }
    abort { "G6503: Touch probe feature not enabled" }

if { global.nxtTouchProbeID == null }
    abort { "G6503: Touch probe ID not configured" }

if { state.currentTool != global.nxtProbeToolID }
    abort { "G6503: Touch probe (T" ^ global.nxtProbeToolID ^ ") must be selected" }

var pSlot = null
if { exists(param.U) && param.U != null }
    if { param.U < 1 || param.U > 9 }
        abort { "G6503: U (target WCS) must be 1-9" }
    set var.pSlot = { param.U - 1 }
elif { exists(param.P) && param.P != null }
    set var.pSlot = { param.P }
else
    abort { "G6503: P or U is required" }

if { var.pSlot < 0 || var.pSlot >= #global.nxtProbeResults }
    abort { "G6503: Result slot out of range" }

if { !exists(param.W) || !exists(param.H) || !exists(param.L) }
    abort { "G6503: Width (W), Height (H), and Depth (L) parameters are required" }

var feedRate = { exists(param.F) ? param.F : null }
var retries = { exists(param.R) ? param.R : global.nxtProbeInnerSampleCount }
var blockWidth = { param.W }
var blockHeight = { param.H }
var probeDepth = { param.L }
var clearance = { exists(param.C) ? param.C : 5.0 }
var overtravel = { exists(param.O) ? param.O : 2.0 }
var skewLimit = { exists(param.T) ? param.T : global.nxtProbeMaxSkewDeg }

echo "G6503: Starting rectangle block probe cycle"

M5000
var centerX = { global.nxtAbsPos[0] }
var centerY = { global.nxtAbsPos[1] }
var startZ = { global.nxtAbsPos[2] }

var halfW = { var.blockWidth / 2 }
var halfH = { var.blockHeight / 2 }

echo "G6503: Probing rectangular block " ^ var.blockWidth ^ "x" ^ var.blockHeight ^ "mm"

; +X approach from +X: probe toward -X, target inside past the east face
echo "G6503: Probing from +X direction"
var xPlusStart = { var.centerX + var.halfW + var.clearance }
var xPlusTarget = { var.centerX + var.halfW - var.overtravel }

G6550 X{var.xPlusStart} Y{var.centerY}
var probeZ = { var.startZ - var.probeDepth }
G6550 Z{var.probeZ}

G6512 X{var.xPlusTarget} Y{var.centerY} Z{var.probeZ} I{global.nxtTouchProbeID} F{var.feedRate} R{var.retries} H0
G6550 Z{var.startZ}

; -X from left
echo "G6503: Probing from -X direction"
var xMinusStart = { var.centerX - var.halfW - var.clearance }
var xMinusTarget = { var.centerX - var.halfW + var.overtravel }

G6550 X{var.xMinusStart} Y{var.centerY}
G6550 Z{var.probeZ}

G6512 X{var.xMinusTarget} Y{var.centerY} Z{var.probeZ} I{global.nxtTouchProbeID} F{var.feedRate} R{var.retries} H1
G6550 Z{var.startZ}

; X center from ±X chord only (Y probes then run at this X)
var calculatedCenterX = { (global.nxtProbeHitXY[0] + global.nxtProbeHitXY[2]) / 2 }

; +Y from +Y
echo "G6503: Probing from +Y direction"
var yPlusStart = { var.centerY + var.halfH + var.clearance }
var yPlusTarget = { var.centerY + var.halfH - var.overtravel }

G6550 X{var.calculatedCenterX} Y{var.yPlusStart}
G6550 Z{var.probeZ}

G6512 X{var.calculatedCenterX} Y{var.yPlusTarget} Z{var.probeZ} I{global.nxtTouchProbeID} F{var.feedRate} R{var.retries} H2
G6550 Z{var.startZ}

; -Y
echo "G6503: Probing from -Y direction"
var yMinusStart = { var.centerY - var.halfH - var.clearance }
var yMinusTarget = { var.centerY - var.halfH + var.overtravel }

G6550 X{var.calculatedCenterX} Y{var.yMinusStart}
G6550 Z{var.probeZ}

G6512 X{var.calculatedCenterX} Y{var.yMinusTarget} Z{var.probeZ} I{global.nxtTouchProbeID} F{var.feedRate} R{var.retries} H3
G6550 Z{var.startZ}

var xPx = { global.nxtProbeHitXY[0] }
var xPy = { global.nxtProbeHitXY[1] }
var xMx = { global.nxtProbeHitXY[2] }
var xMy = { global.nxtProbeHitXY[3] }
var yPx = { global.nxtProbeHitXY[4] }
var yPy = { global.nxtProbeHitXY[5] }
var yMx = { global.nxtProbeHitXY[6] }
var yMy = { global.nxtProbeHitXY[7] }

var vx = { var.xPx - var.xMx }
var vy = { var.xPy - var.xMy }
var wx = { var.yPx - var.yMx }
var wy = { var.yPy - var.yMy }

var thetaRad = { atan2(var.vy, var.vx) }
var thetaDeg = { var.thetaRad * 180 / pi }

if { abs(var.thetaDeg) > var.skewLimit }
    abort { "G6503: |skew| " ^ var.thetaDeg ^ " deg exceeds limit " ^ var.skewLimit }

var m1x = { (var.xPx + var.xMx) / 2 }
var m1y = { (var.xPy + var.xMy) / 2 }
var m2x = { (var.yPx + var.yMx) / 2 }
var m2y = { (var.yPy + var.yMy) / 2 }
; Intersection of the two chord midlines — robust when stock is slightly skewed vs machine
var solvedCx = { (var.m1x + var.m2x) / 2 }
var solvedCy = { (var.m1y + var.m2y) / 2 }

var actualWidth = { abs(var.vx) }
var actualHeight = { abs(var.wy) }

if { global.nxtProbeResults[var.pSlot] == null || #global.nxtProbeResults[var.pSlot] < 3 }
    set global.nxtProbeResults[var.pSlot] = { vector(#move.axes + 1, 0.0) }

set global.nxtProbeResults[var.pSlot][0] = { var.solvedCx }
set global.nxtProbeResults[var.pSlot][1] = { var.solvedCy }
set global.nxtProbeResults[var.pSlot][#move.axes] = { var.thetaDeg }

G6550 X{var.solvedCx} Y{var.solvedCy}
G27 Z1

echo "G6503: Rectangle block probe completed"
echo "G6503: Block center at X=" ^ var.solvedCx ^ " Y=" ^ var.solvedCy
echo "G6503: Approx skew: " ^ var.thetaDeg ^ " deg"
echo "G6503: Measured dimensions: " ^ var.actualWidth ^ "x" ^ var.actualHeight ^ "mm"
echo "G6503: Result logged to table index " ^ var.pSlot

if { exists(param.U) && param.U != null }
    if { exists(param.Q) && param.Q != null }
        M98 P"M6520.g" P{var.pSlot} W{param.U} X Y T{var.skewLimit} Q{param.Q}
    else
        M98 P"M6520.g" P{var.pSlot} W{param.U} X Y T{var.skewLimit}
