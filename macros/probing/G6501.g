; G6501.g: BOSS PROBE (CIRCULAR BOSS)
;
; Three triangulated OD touches at 0/120/240 deg via G6513 (same geometry
; family as G6501.1). C = approach clearance (outside air before OD).
; Raises to startZ between touches. Park at circumcenter at startZ.
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

if { sensors.probes[global.nxtTouchProbeID].value[0] != 0 }
    abort { "G6501: Probe already triggered — clear stylus before starting" }

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

if { !exists(param.D) || param.D == null || param.D <= 0 }
    abort { "G6501: Diameter D required" }

if { !exists(param.L) || param.L == null || param.L <= 0 }
    abort { "G6501: Depth L required" }

var retries = { exists(param.R) ? param.R : global.nxtProbeInnerSampleCount }
var bossDiameter = { param.D }
var toolR = 0
if { state.currentTool <= limits.tools-1 && state.currentTool >= 0 }
    set var.toolR = { global.nxtTT[state.currentTool][0] }
; Approach clearance C: outside air before OD (default 5 mm, like G6503)
var clearance = 5.0
if { exists(param.C) && param.C != null && param.C > 0 }
    set var.clearance = { param.C }
set var.clearance = { var.clearance + var.toolR }
var overtravel = { (exists(param.O) ? param.O : 2.0) - var.toolR }
var probeDepth = { param.L }
var skewLimit = { exists(param.T) ? param.T : global.nxtProbeMaxSkewDeg }
var probeI = { global.nxtTouchProbeID }

echo "G6501: Starting boss probe (3-point triangulation at 120 deg)"
echo "G6501: Approach clearance C=" ^ var.clearance ^ " mm overtravel O=" ^ var.overtravel

M5000
var sX = { global.nxtAbsPos[0] }
var sY = { global.nxtAbsPos[1] }
var startZ = { global.nxtAbsPos[2] }
var probeZ = { var.startZ - var.probeDepth }
var bR = { var.bossDiameter / 2 }

echo "G6501: startZ=" ^ var.startZ ^ " L=" ^ var.probeDepth ^ " diveZ=" ^ var.probeZ
echo "G6501: Boss diameter ~" ^ var.bossDiameter ^ "mm"

var numPoints = 3
var probePoints = { vector(var.numPoints, {{{null, null, null}, {null, null, null}},}) }

; 0 deg: start outside on +X, probe inward toward OD
set var.probePoints[0][0][0] = { var.sX + var.bR + var.clearance, var.sY, var.probeZ }
set var.probePoints[0][0][1] = { var.sX + var.bR - var.overtravel, var.sY, var.probeZ }

while { iterations < var.numPoints - 1 }
    var pointNo = { iterations + 1 }
    var probeAngle = { radians(120 * var.pointNo) }
    var sPX = { var.sX + (var.bR + var.clearance) * cos(var.probeAngle) }
    var sPY = { var.sY + (var.bR + var.clearance) * sin(var.probeAngle) }
    set var.probePoints[var.pointNo][0][0] = { var.sPX, var.sPY, var.probeZ }
    var tPX = { var.sX + (var.bR - var.overtravel) * cos(var.probeAngle) }
    var tPY = { var.sY + (var.bR - var.overtravel) * sin(var.probeAngle) }
    set var.probePoints[var.pointNo][0][1] = { var.tPX, var.tPY, var.probeZ }

G6513 I{var.probeI} P{var.probePoints} S{var.startZ} R{var.retries}

var result = { global.nxtAbsPos }
var pXY = { vector(3, null) }

while { iterations < #var.result }
    set var.pXY[iterations] = { var.result[iterations][0][0][0], var.result[iterations][0][0][1] }

if { var.pXY[0] == null || var.pXY[1] == null || var.pXY[2] == null }
    abort { "G6501: Missing triangulated hits from G6513" }
if { var.pXY[0][0] == null || var.pXY[0][1] == null }
    abort { "G6501: Null hit 0 from G6513" }
if { var.pXY[1][0] == null || var.pXY[1][1] == null }
    abort { "G6501: Null hit 1 from G6513" }
if { var.pXY[2][0] == null || var.pXY[2][1] == null }
    abort { "G6501: Null hit 2 from G6513" }

var x1 = { var.pXY[0][0] }
var y1 = { var.pXY[0][1] }
var x2 = { var.pXY[1][0] }
var y2 = { var.pXY[1][1] }
var x3 = { var.pXY[2][0] }
var y3 = { var.pXY[2][1] }

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

var vx = { var.x1 - var.calculatedCenterX }
var vy = { var.y1 - var.calculatedCenterY }
var thetaDeg = { atan2(var.vy, var.vx) * 180 / pi }
if { var.thetaDeg > 90 }
    set var.thetaDeg = { var.thetaDeg - 180 }
elif { var.thetaDeg <= -90 }
    set var.thetaDeg = { var.thetaDeg + 180 }

if { abs(var.thetaDeg) > var.skewLimit }
    abort { "G6501: |skew| " ^ var.thetaDeg ^ " exceeds limit " ^ var.skewLimit }

; RRF ^ is string concat — use multiply for squares (not ^2)
var dx0 = { var.calculatedCenterX - var.x1 }
var dy0 = { var.calculatedCenterY - var.y1 }
var dx1 = { var.calculatedCenterX - var.x2 }
var dy1 = { var.calculatedCenterY - var.y2 }
var dx2 = { var.calculatedCenterX - var.x3 }
var dy2 = { var.calculatedCenterY - var.y3 }
var r0 = { sqrt(var.dx0 * var.dx0 + var.dy0 * var.dy0) }
var r1 = { sqrt(var.dx1 * var.dx1 + var.dy1 * var.dy1) }
var r2 = { sqrt(var.dx2 * var.dx2 + var.dy2 * var.dy2) }
var avgDiameter = { (2 * var.r0 + 2 * var.r1 + 2 * var.r2) / 3 }

if { global.nxtProbeResults[var.pSlot] == null || #global.nxtProbeResults[var.pSlot] < 3 }
    set global.nxtProbeResults[var.pSlot] = { vector(#move.axes + 1, 0.0) }

set global.nxtProbeResults[var.pSlot][0] = { var.calculatedCenterX }
set global.nxtProbeResults[var.pSlot][1] = { var.calculatedCenterY }
set global.nxtProbeResults[var.pSlot][#move.axes] = { var.thetaDeg }

G6550 Z{var.startZ} I{var.probeI}
G6550 X{var.calculatedCenterX} Y{var.calculatedCenterY} I{var.probeI}

echo "G6501: Boss center X=" ^ var.calculatedCenterX ^ " Y=" ^ var.calculatedCenterY
echo "G6501: Mean diameter ~" ^ var.avgDiameter
echo "G6501: Result index " ^ var.pSlot

if { exists(param.U) && param.U != null }
    if { exists(param.Q) && param.Q != null }
        M98 P"M6520.g" P{var.pSlot} W{param.U} X Y T{var.skewLimit} Q{param.Q}
    else
        M98 P"M6520.g" P{var.pSlot} W{param.U} X Y T{var.skewLimit}
