; G6506.g: ROTATION PROBE
;
; Finds the angle of a *straight edge* vs machine X by probing two points S mm apart along that edge.
; N=0: edge nominally parallel to X → probe motion is in ±Y (air position vs target set by D).
; N=1: edge parallel to Y → probe motion in ±X.
; D picks which side of nominal to approach from: with D=1 the stylus starts on the + side of
; the edge line and probes toward the stock; D=0 is the mirror (see yAir0/yTgt0 pattern).
;
; atan2(dy,dx) of the segment between averaged contacts gives edge angle; midpoint is stored as
; XY “anchor” point with that θ in the rotation slot for M6520.
; Finish: G6550 to startZ (XY pinned), then G6550 to midpoint XY, then M6520.
;
; USAGE: G6506 P|U N<axis> D<dir> S<spacing> L<depth> [F] [R] [O] [T] [Q]

if { !inputs[state.thisInput].active }
    M99

if { !global.nxtFeatureTouchProbe }
    abort { "G6506: Touch probe feature not enabled" }

if { global.nxtTouchProbeID == null }
    abort { "G6506: Touch probe ID not configured" }

if { state.currentTool != global.nxtProbeToolID }
    abort { "G6506: Touch probe (T" ^ global.nxtProbeToolID ^ ") must be selected" }

var pSlot = null
if { exists(param.U) && param.U != null }
    if { param.U < 1 || param.U > 9 }
        abort { "G6506: U must be 1-9" }
    set var.pSlot = { param.U - 1 }
elif { exists(param.P) && param.P != null }
    set var.pSlot = { param.P }
else
    abort { "G6506: P or U required" }

if { var.pSlot < 0 || var.pSlot >= #global.nxtProbeResults }
    abort { "G6506: Result slot out of range" }

if { !exists(param.N) || param.N == null || !exists(param.D) || param.D == null }
    abort { "G6506: N and D are required" }
if { !exists(param.S) || param.S == null || param.S <= 0 }
    abort { "G6506: Spacing S is required and must be positive" }
if { !exists(param.L) || param.L == null || param.L <= 0 }
    abort { "G6506: Depth L is required and must be positive" }

if { param.N != 0 && param.N != 1 }
    abort { "G6506: N must be 0 or 1" }

if { param.D != 0 && param.D != 1 }
    abort { "G6506: D must be 0 or 1" }

var feedRate = { exists(param.F) ? param.F : null }
var retries = { exists(param.R) ? param.R : global.nxtProbeInnerSampleCount }
var spacing = { param.S }
var probeDepth = { param.L }
var overtravel = { exists(param.O) ? param.O : 2.0 }
var skewLimit = { exists(param.T) ? param.T : global.nxtProbeMaxSkewDeg }
var halfSpacing = { var.spacing / 2 }

echo "G6506: Rotation probe N=" ^ param.N ^ " D=" ^ param.D

M5000
var centerX = { global.nxtAbsPos[0] }
var centerY = { global.nxtAbsPos[1] }
var startZ = { global.nxtAbsPos[2] }
var probeZ = { var.startZ - var.probeDepth }

if { param.N == 0 }
    ; Edge along X — probe moves in Y
    var yAir0 = { param.D == 1 ? var.centerY + var.overtravel + 1.0 : var.centerY - var.overtravel - 1.0 }
    var yTgt0 = { param.D == 1 ? var.centerY - var.overtravel : var.centerY + var.overtravel }
    var x0 = { var.centerX - var.halfSpacing }
    echo "G6506: Touch 1"
    G6550 X{var.x0} Y{var.yAir0}
    G6550 Z{var.probeZ}
    G6512 Y{var.yTgt0} I{global.nxtTouchProbeID} F{var.feedRate} R{var.retries} H0
    G6550 Z{var.startZ}

    var yAir1 = { var.yAir0 }
    var yTgt1 = { var.yTgt0 }
    var x1 = { var.centerX + var.halfSpacing }
    echo "G6506: Touch 2"
    G6550 X{var.x1} Y{var.yAir1}
    G6550 Z{var.probeZ}
    G6512 Y{var.yTgt1} I{global.nxtTouchProbeID} F{var.feedRate} R{var.retries} H1
    G6550 Z{var.startZ}

    if { !exists(global.nxtProbeHitXY) || global.nxtProbeHitXY == null || #global.nxtProbeHitXY < 4 }
        abort { "G6506: Missing probe hits in nxtProbeHitXY" }
    if { global.nxtProbeHitXY[0] == null || global.nxtProbeHitXY[1] == null }
        abort { "G6506: Null hit A — check G6512 H0 writes" }
    if { global.nxtProbeHitXY[2] == null || global.nxtProbeHitXY[3] == null }
        abort { "G6506: Null hit B — check G6512 H1 writes" }

    var xA = { global.nxtProbeHitXY[0] }
    var yA = { global.nxtProbeHitXY[1] }
    var xB = { global.nxtProbeHitXY[2] }
    var yB = { global.nxtProbeHitXY[3] }
else
    ; Edge along Y — probe moves in X
    var xAir0 = { param.D == 1 ? var.centerX + var.overtravel + 1.0 : var.centerX - var.overtravel - 1.0 }
    var xTgt0 = { param.D == 1 ? var.centerX - var.overtravel : var.centerX + var.overtravel }
    var y0 = { var.centerY - var.halfSpacing }
    echo "G6506: Touch 1"
    G6550 X{var.xAir0} Y{var.y0}
    G6550 Z{var.probeZ}
    G6512 X{var.xTgt0} I{global.nxtTouchProbeID} F{var.feedRate} R{var.retries} H0
    G6550 Z{var.startZ}

    var xAir1 = { var.xAir0 }
    var xTgt1 = { var.xTgt0 }
    var y1 = { var.centerY + var.halfSpacing }
    echo "G6506: Touch 2"
    G6550 X{var.xAir1} Y{var.y1}
    G6550 Z{var.probeZ}
    G6512 X{var.xTgt1} I{global.nxtTouchProbeID} F{var.feedRate} R{var.retries} H1
    G6550 Z{var.startZ}

    if { !exists(global.nxtProbeHitXY) || global.nxtProbeHitXY == null || #global.nxtProbeHitXY < 4 }
        abort { "G6506: Missing probe hits in nxtProbeHitXY" }
    if { global.nxtProbeHitXY[0] == null || global.nxtProbeHitXY[1] == null }
        abort { "G6506: Null hit A — check G6512 H0 writes" }
    if { global.nxtProbeHitXY[2] == null || global.nxtProbeHitXY[3] == null }
        abort { "G6506: Null hit B — check G6512 H1 writes" }

    var xA = { global.nxtProbeHitXY[0] }
    var yA = { global.nxtProbeHitXY[1] }
    var xB = { global.nxtProbeHitXY[2] }
    var yB = { global.nxtProbeHitXY[3] }

; Directed edge vector from touch A → touch B; angle vs +X matches stock rotation sign convention
var dx = { var.xB - var.xA }
var dy = { var.yB - var.yA }
var rotationRad = { atan2(var.dy, var.dx) }
var rotationDeg = { var.rotationRad * 180 / pi }
; Fold to (−90, 90] so reversed touch order does not yield ~±180°
if { var.rotationDeg > 90 }
    set var.rotationDeg = { var.rotationDeg - 180 }
elif { var.rotationDeg <= -90 }
    set var.rotationDeg = { var.rotationDeg + 180 }

if { abs(var.rotationDeg) > var.skewLimit }
    abort { "G6506: |angle| " ^ var.rotationDeg ^ " exceeds limit " ^ var.skewLimit }

var midpointX = { (var.xA + var.xB) / 2 }
var midpointY = { (var.yA + var.yB) / 2 }

var resultVectorSize = { #move.axes + 1 }
if { global.nxtProbeResults[var.pSlot] == null || #global.nxtProbeResults[var.pSlot] != var.resultVectorSize }
    set global.nxtProbeResults[var.pSlot] = { vector(var.resultVectorSize, 0.0) }

set global.nxtProbeResults[var.pSlot][0] = { var.midpointX }
set global.nxtProbeResults[var.pSlot][1] = { var.midpointY }
set global.nxtProbeResults[var.pSlot][#move.axes] = { var.rotationDeg }

echo "G6506: Edge midpoint X=" ^ var.midpointX ^ " Y=" ^ var.midpointY
echo "G6506: Edge angle vs machine X: " ^ var.rotationDeg ^ " deg"
echo "G6506: Index " ^ var.pSlot

; Raise to startZ with XY pinned (G6550 +Z pins current XY), then midpoint XY
G6550 Z{var.startZ}
G6550 X{var.midpointX} Y{var.midpointY}

if { exists(param.U) && param.U != null }
    if { exists(param.Q) && param.Q != null }
        M6520 P{var.pSlot} W{param.U} X1 Y1 T{var.skewLimit} Q{param.Q}
    else
        M6520 P{var.pSlot} W{param.U} X1 Y1 T{var.skewLimit}
