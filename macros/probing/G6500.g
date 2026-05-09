; G6500.g: BORE PROBE (CIRCULAR BORE)
;
; Three inward radial touches (+X, −X, +Y) at radius D/2+O. Three points on a circle fix the
; circumcenter (vs four cardinal points). Contacts go to nxtProbeHitXY H0..H2 (G6512).
;
; Geometry:
;   - Center = circumcenter of triangle P(+X), P(−X), P(+Y).
;   - Skew θ = atan2 of chord from −X to +X touch (bore diameter vs machine X), same spirit as 4-touch.
;   - Reported diameter = mean of 2*r from center to each of the three contacts.
;
; USAGE: G6500 P|U D<diameter> L<depth> [F] [R] [O] [T<skew>] [Q]

if { !inputs[state.thisInput].active }
    M99

if { !global.nxtFeatureTouchProbe }
    abort { "G6500: Touch probe feature not enabled" }

if { global.nxtTouchProbeID == null }
    abort { "G6500: Touch probe ID not configured" }

if { state.currentTool != global.nxtProbeToolID }
    abort { "G6500: Touch probe (T" ^ global.nxtProbeToolID ^ ") must be selected" }

var pSlot = null
if { exists(param.U) && param.U != null }
    if { param.U < 1 || param.U > 9 }
        abort { "G6500: U must be 1-9" }
    set var.pSlot = { param.U - 1 }
elif { exists(param.P) && param.P != null }
    set var.pSlot = { param.P }
else
    abort { "G6500: P or U is required" }

if { var.pSlot < 0 || var.pSlot >= #global.nxtProbeResults }
    abort { "G6500: Result slot out of range" }

if { !exists(param.D) || param.D == null || param.D <= 0 }
    abort { "G6500: Diameter D is required and must be positive" }

if { !exists(param.L) || param.L == null || param.L <= 0 }
    abort { "G6500: Depth L is required and must be positive" }

var feedRate = { exists(param.F) ? param.F : null }
var retries = { exists(param.R) ? param.R : global.nxtProbeInnerSampleCount }
var boreDiameter = { param.D }
var overtravel = { exists(param.O) ? param.O : 2.0 }
var probeDepth = { param.L }
var skewLimit = { exists(param.T) ? param.T : global.nxtProbeMaxSkewDeg }

G27 Z1

echo "G6500: Starting bore probe cycle (3-point circle)"

M5000
var centerX = { global.nxtAbsPos[0] }
var centerY = { global.nxtAbsPos[1] }
var startZ = { global.nxtAbsPos[2] }

var probeZ = { var.startZ - var.probeDepth }
G6550 Z{var.probeZ}

var probeDistance = { var.boreDiameter / 2 + var.overtravel }

echo "G6500: Probing bore diameter ~" ^ var.boreDiameter ^ "mm"

var xPlusTarget = { var.centerX + var.probeDistance }
G6512 X{var.xPlusTarget} Y{var.centerY} Z{var.probeZ} I{global.nxtTouchProbeID} F{var.feedRate} R{var.retries} H0
G6550 X{var.centerX}

var xMinusTarget = { var.centerX - var.probeDistance }
G6512 X{var.xMinusTarget} Y{var.centerY} Z{var.probeZ} I{global.nxtTouchProbeID} F{var.feedRate} R{var.retries} H1
G6550 X{var.centerX}

var yPlusTarget = { var.centerY + var.probeDistance }
G6512 X{var.centerX} Y{var.yPlusTarget} Z{var.probeZ} I{global.nxtTouchProbeID} F{var.feedRate} R{var.retries} H2

var xPx = { global.nxtProbeHitXY[0] }
var xPy = { global.nxtProbeHitXY[1] }
var xMx = { global.nxtProbeHitXY[2] }
var xMy = { global.nxtProbeHitXY[3] }
var yPx = { global.nxtProbeHitXY[4] }
var yPy = { global.nxtProbeHitXY[5] }

var x1 = var.xPx
var y1 = var.xPy
var x2 = var.xMx
var y2 = var.xMy
var x3 = var.yPx
var y3 = var.yPy

var ax = { var.x2 - var.x1 }
var ay = { var.y2 - var.y1 }
var bx = { var.x3 - var.x2 }
var by = { var.y3 - var.y2 }
var d = { 2 * (var.ax * var.by - var.ay * var.bx) }

if { abs(var.d) < 1e-7 }
    abort { "G6500: Degenerate bore fit (collinear hits) — check D/O/centering" }

var ma = { var.ax * var.ax + var.ay * var.ay }
var mb = { var.bx * var.bx + var.by * var.by }
var calculatedCenterX = { var.x1 + (var.by * var.ma - var.ay * var.mb) / var.d }
var calculatedCenterY = { var.y1 + (var.ax * var.mb - var.bx * var.ma) / var.d }

var vx = { var.xPx - var.xMx }
var vy = { var.xPy - var.xMy }
var thetaDeg = { atan2(var.vy, var.vx) * 180 / pi }

if { abs(var.thetaDeg) > var.skewLimit }
    abort { "G6500: |skew| " ^ var.thetaDeg ^ " deg exceeds limit " ^ var.skewLimit }

var r0 = { sqrt((var.calculatedCenterX - var.xPx)^2 + (var.calculatedCenterY - var.xPy)^2) }
var r1 = { sqrt((var.calculatedCenterX - var.xMx)^2 + (var.calculatedCenterY - var.xMy)^2) }
var r2 = { sqrt((var.calculatedCenterX - var.yPx)^2 + (var.calculatedCenterY - var.yPy)^2) }
var avgDiameter = { (2 * var.r0 + 2 * var.r1 + 2 * var.r2) / 3 }

if { #global.nxtProbeResults[var.pSlot] < 3 }
    set global.nxtProbeResults[var.pSlot] = { vector(#move.axes + 1, 0.0) }

set global.nxtProbeResults[var.pSlot][0] = { var.calculatedCenterX }
set global.nxtProbeResults[var.pSlot][1] = { var.calculatedCenterY }
set global.nxtProbeResults[var.pSlot][#move.axes] = { var.thetaDeg }

G6550 X{var.calculatedCenterX} Y{var.calculatedCenterY}
G6550 Z{var.startZ}

echo "G6500: Bore center X=" ^ var.calculatedCenterX ^ " Y=" ^ var.calculatedCenterY ^ " skew=" ^ var.thetaDeg ^ " deg"
echo "G6500: Mean diameter (from 3 radii) ~" ^ var.avgDiameter
echo "G6500: Result index " ^ var.pSlot

if { exists(param.U) && param.U != null }
    if { exists(param.Q) && param.Q != null }
        M98 P"M6520.g" P{var.pSlot} W{param.U} X Y T{var.skewLimit} Q{param.Q}
    else
        M98 P"M6520.g" P{var.pSlot} W{param.U} X Y T{var.skewLimit}
