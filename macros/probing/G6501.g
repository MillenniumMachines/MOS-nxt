; G6501.g: BOSS PROBE (CIRCULAR BOSS)
;
; Outer approach then inward probes: +X and −X (H0,H1), then +Y at midX (H2) — three points on
; the OD define the circle center via circumcenter (same model as G6500 bore).
;
; USAGE: G6501 P|U D<diameter> L<depth> [F] [R] [C] [O] [T] [Q]

if { !inputs[state.thisInput].active }
    M99

if { !global.nxtFeatureTouchProbe }
    abort { "G6501: Touch probe feature not enabled" }

if { global.nxtTouchProbeID == null }
    abort { "G6501: Touch probe ID not configured" }

if { state.currentTool != global.nxtProbeToolID }
    abort { "G6501: Touch probe (T" ^ global.nxtProbeToolID ^ ") must be selected" }

var pSlot = null
if { exists(param.U) && param.U != null }
    if { param.U < 1 || param.U > 9 }
        abort { "G6501: U must be 1-9" }
    set var.pSlot = { param.U - 1 }
elif { exists(param.P) && param.P != null }
    set var.pSlot = { param.P }
else
    abort { "G6501: P or U is required" }

if { var.pSlot < 0 || var.pSlot >= #global.nxtProbeResults }
    abort { "G6501: Result slot out of range" }

if { !exists(param.D) || param.D <= 0 }
    abort { "G6501: Diameter D required" }

if { !exists(param.L) || param.L <= 0 }
    abort { "G6501: Depth L required" }

var feedRate = { exists(param.F) ? param.F : null }
var retries = { exists(param.R) ? param.R : global.nxtProbeInnerSampleCount }
var bossDiameter = { param.D }
var clearance = { exists(param.C) ? param.C : 5.0 }
var overtravel = { exists(param.O) ? param.O : 2.0 }
var probeDepth = { param.L }
var skewLimit = { exists(param.T) ? param.T : global.nxtProbeMaxSkewDeg }

echo "G6501: Starting boss probe cycle (3-point circle)"

M5000
var centerX = { global.nxtAbsPos[0] }
var centerY = { global.nxtAbsPos[1] }
var startZ = { global.nxtAbsPos[2] }

var halfD = { var.bossDiameter / 2 }

echo "G6501: Boss diameter ~" ^ var.bossDiameter ^ "mm"

echo "G6501: Probing from +X"
var xPlusStart = { var.centerX + var.halfD + var.clearance }
var xPlusTarget = { var.centerX + var.halfD - var.overtravel }
G6550 X{var.xPlusStart} Y{var.centerY}
var probeZ = { var.startZ - var.probeDepth }
G6550 Z{var.probeZ}
G6512 X{var.xPlusTarget} I{global.nxtTouchProbeID} F{var.feedRate} R{var.retries} H0
G6550 Z{var.startZ}

echo "G6501: Probing from -X"
var xMinusStart = { var.centerX - var.halfD - var.clearance }
var xMinusTarget = { var.centerX - var.halfD + var.overtravel }
G6550 X{var.xMinusStart} Y{var.centerY}
G6550 Z{var.probeZ}
G6512 X{var.xMinusTarget} I{global.nxtTouchProbeID} F{var.feedRate} R{var.retries} H1
G6550 Z{var.startZ}

var midX = { (global.nxtProbeHitXY[0] + global.nxtProbeHitXY[2]) / 2 }

echo "G6501: Probing from +Y"
var yPlusStart = { var.centerY + var.halfD + var.clearance }
var yPlusTarget = { var.centerY + var.halfD - var.overtravel }
G6550 X{var.midX} Y{var.yPlusStart}
G6550 Z{var.probeZ}
G6512 Y{var.yPlusTarget} I{global.nxtTouchProbeID} F{var.feedRate} R{var.retries} H2
G6550 Z{var.startZ}

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
    abort { "G6501: Degenerate boss fit (collinear hits) — check D/O/centering" }

var ma = { var.ax * var.ax + var.ay * var.ay }
var mb = { var.bx * var.bx + var.by * var.by }
var calculatedCenterX = { var.x1 + (var.by * var.ma - var.ay * var.mb) / var.d }
var calculatedCenterY = { var.y1 + (var.ax * var.mb - var.bx * var.ma) / var.d }

var vx = { var.xPx - var.xMx }
var vy = { var.xPy - var.xMy }
var thetaDeg = { atan2(var.vy, var.vx) * 180 / pi }

if { abs(var.thetaDeg) > var.skewLimit }
    abort { "G6501: |skew| " ^ var.thetaDeg ^ " exceeds limit " ^ var.skewLimit }

var r0 = { sqrt((var.calculatedCenterX - var.xPx)^2 + (var.calculatedCenterY - var.xPy)^2) }
var r1 = { sqrt((var.calculatedCenterX - var.xMx)^2 + (var.calculatedCenterY - var.xMy)^2) }
var r2 = { sqrt((var.calculatedCenterX - var.yPx)^2 + (var.calculatedCenterY - var.yPy)^2) }
var avgDiameter = { (2 * var.r0 + 2 * var.r1 + 2 * var.r2) / 3 }

if { global.nxtProbeResults[var.pSlot] == null || #global.nxtProbeResults[var.pSlot] < 3 }
    set global.nxtProbeResults[var.pSlot] = { vector(#move.axes + 1, 0.0) }

set global.nxtProbeResults[var.pSlot][0] = { var.calculatedCenterX }
set global.nxtProbeResults[var.pSlot][1] = { var.calculatedCenterY }
set global.nxtProbeResults[var.pSlot][#move.axes] = { var.thetaDeg }

G6550 X{var.calculatedCenterX} Y{var.calculatedCenterY}
G27 Z1

echo "G6501: Boss center X=" ^ var.calculatedCenterX ^ " Y=" ^ var.calculatedCenterY
echo "G6501: Mean diameter ~" ^ var.avgDiameter
echo "G6501: Result index " ^ var.pSlot

if { exists(param.U) && param.U != null }
    if { exists(param.Q) && param.Q != null }
        M98 P"M6520.g" P{var.pSlot} W{param.U} X Y T{var.skewLimit} Q{param.Q}
    else
        M98 P"M6520.g" P{var.pSlot} W{param.U} X Y T{var.skewLimit}
