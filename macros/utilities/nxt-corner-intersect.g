; nxt-corner-intersect.g: CORNER XY + SKEW FROM TWO FACE ENDPOINT PAIRS
;
; Expects nxtProbeHitXY packed by caller:
;   [0],[1] X-face p0; [2],[3] X-face p1  (probe-X face; 1-pt → p0==p1 → vertical)
;   [4],[5] Y-face p0; [6],[7] Y-face p1  (probe-Y face; 1-pt → p0==p1 → horizontal)
; Optional H/I = face lengths for θ weighting (longer face wins); T = skew limit.
;
; Writes: global.nxtFaceCornerX, nxtFaceCornerY, nxtFaceThetaDeg

if { !inputs[state.thisInput].active }
    M99

if { !exists(global.nxtProbeHitXY) || global.nxtProbeHitXY == null }
    abort { "nxt-corner-intersect: nxtProbeHitXY missing" }

if { #global.nxtProbeHitXY < 8 }
    abort { "nxt-corner-intersect: nxtProbeHitXY too short" }

var x1 = { global.nxtProbeHitXY[0] }
var y1 = { global.nxtProbeHitXY[1] }
var x2 = { global.nxtProbeHitXY[2] }
var y2 = { global.nxtProbeHitXY[3] }
var x3 = { global.nxtProbeHitXY[4] }
var y3 = { global.nxtProbeHitXY[5] }
var x4 = { global.nxtProbeHitXY[6] }
var y4 = { global.nxtProbeHitXY[7] }

var skewLimit = { exists(param.T) ? param.T : global.nxtProbeMaxSkewDeg }
var fX = { exists(param.H) ? param.H : 0 }
var fY = { exists(param.I) ? param.I : 0 }

var xFace1pt = { abs(var.x2 - var.x1) < 0.0005 && abs(var.y2 - var.y1) < 0.0005 }
var yFace1pt = { abs(var.x4 - var.x3) < 0.0005 && abs(var.y4 - var.y3) < 0.0005 }

if { !exists(global.nxtFaceCornerX) }
    global nxtFaceCornerX = null
if { !exists(global.nxtFaceCornerY) }
    global nxtFaceCornerY = null
if { !exists(global.nxtFaceThetaDeg) }
    global nxtFaceThetaDeg = 0

; Both single-point → axis-aligned corner (legacy quick)
if { var.xFace1pt && var.yFace1pt }
    set global.nxtFaceCornerX = { var.x1 }
    set global.nxtFaceCornerY = { var.y3 }
    set global.nxtFaceThetaDeg = 0
    echo "nxt-corner-intersect: 1+1 pt corner X=" ^ var.x1 ^ " Y=" ^ var.y3
    M99

; Build slopes; 1-pt X-face → vertical; 1-pt Y-face → horizontal
var m1 = { null }
var m2 = { null }
var c1 = 0
var c2 = 0

if { var.xFace1pt }
    set var.m1 = { null }
else
    var dx1 = { var.x2 - var.x1 }
    if { abs(var.dx1) < 0.0005 }
        set var.m1 = { null }
    else
        set var.m1 = { (var.y2 - var.y1) / var.dx1 }
        set var.c1 = { var.y1 - (var.m1 * var.x1) }

if { var.yFace1pt }
    set var.m2 = { 0 }
    set var.c2 = { var.y3 }
else
    var dx2 = { var.x4 - var.x3 }
    if { abs(var.dx2) < 0.0005 }
        set var.m2 = { null }
    else
        set var.m2 = { (var.y4 - var.y3) / var.dx2 }
        set var.c2 = { var.y3 - (var.m2 * var.x3) }

var xIntersect = { null }
var yIntersect = { null }

if { var.m1 == null && var.m2 == null }
    abort { "nxt-corner-intersect: Both faces vertical — cannot intersect" }
elif { var.m1 == null }
    set var.xIntersect = { var.x1 }
    if { var.m2 == 0 }
        set var.yIntersect = { var.y3 }
    else
        set var.yIntersect = { var.m2 * var.xIntersect + var.c2 }
elif { var.m2 == null }
    set var.xIntersect = { var.x3 }
    if { var.m1 == 0 }
        set var.yIntersect = { var.y1 }
    else
        set var.yIntersect = { var.m1 * var.xIntersect + var.c1 }
elif { var.m1 == 0 && var.m2 == 0 }
    abort { "nxt-corner-intersect: Both faces horizontal — cannot intersect" }
elif { var.m1 == 0 }
    set var.yIntersect = { var.y1 }
    set var.xIntersect = { (var.yIntersect - var.c2) / var.m2 }
elif { var.m2 == 0 }
    set var.yIntersect = { var.y3 }
    set var.xIntersect = { (var.yIntersect - var.c1) / var.m1 }
else
    set var.xIntersect = { (var.c2 - var.c1) / (var.m1 - var.m2) }
    set var.yIntersect = { (var.m1 * var.xIntersect) + var.c1 }

if { isnan(var.xIntersect) || isnan(var.yIntersect) }
    abort { "nxt-corner-intersect: Could not calculate intersection" }
if { var.xIntersect == null || var.yIntersect == null }
    abort { "nxt-corner-intersect: Could not calculate intersection" }

set global.nxtFaceCornerX = { var.xIntersect }
set global.nxtFaceCornerY = { var.yIntersect }

; Skew from longer face (legacy G6508.1 weighting); 0 if both 1-pt already handled
var thetaDeg = 0
if { !var.xFace1pt || !var.yFace1pt }
    var angX = 0
    var angY = 0
    if { !var.xFace1pt }
        set var.angX = { atan2(var.y2 - var.y1, var.x2 - var.x1) }
    if { !var.yFace1pt }
        set var.angY = { atan2(var.y4 - var.y3, var.x4 - var.x3) }
    var aR = { var.angY }
    if { var.fX > var.fY && !var.xFace1pt }
        set var.aR = { var.angX - (pi / 2) }
    elif { var.xFace1pt && !var.yFace1pt }
        set var.aR = { var.angY }
    elif { !var.xFace1pt && var.yFace1pt }
        set var.aR = { var.angX - (pi / 2) }
    while { var.aR > pi/4 || var.aR < -pi/4 }
        if { var.aR > pi/4 }
            set var.aR = { var.aR - pi/2 }
        elif { var.aR < -pi/4 }
            set var.aR = { var.aR + pi/2 }
    set var.thetaDeg = { degrees(var.aR) }

if { abs(var.thetaDeg) > var.skewLimit }
    abort { "nxt-corner-intersect: |skew| exceeds limit — square part or increase T" }

set global.nxtFaceThetaDeg = { var.thetaDeg }
echo { "nxt-corner-intersect: Corner X=" ^ var.xIntersect ^ " Y=" ^ var.yIntersect }
echo { "nxt-corner-intersect: Skew " ^ var.thetaDeg ^ " deg" }
