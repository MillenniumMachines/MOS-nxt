; G6503.g: RECTANGLE BLOCK PROBE (3-pt perimeter)
;
; Probes each of 4 faces from outside with 3 points (near-corner, mid, far-corner).
; Outside clearance C defaults to 5 mm; edge inset E (corner clearance) defaults to 10 mm.
; Stay at dive Z along a face; raise to start Z only between faces. CCW from −Y/−X.
;
; Face means → nxtProbeHitXY H0..H3 → skew + center; nxtProbeResults; M6520 if U.
;
; USAGE: G6503 P|U W H L [F] [R] [C] [O] [E] [T] [Q]
;   C: Outside face clearance (default 5)
;   E: Edge inset from assumed corners / corner clearance (default 10)

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

if { !exists(param.W) || param.W == null || param.W <= 0 }
    abort { "G6503: Width W is required and must be positive" }
if { !exists(param.H) || param.H == null || param.H <= 0 }
    abort { "G6503: Height H is required and must be positive" }
if { !exists(param.L) || param.L == null || param.L <= 0 }
    abort { "G6503: Depth L is required and must be positive" }

var feedRate = { exists(param.F) ? param.F : null }
var retries = { exists(param.R) ? param.R : global.nxtProbeInnerSampleCount }
var blockWidth = { param.W }
var blockHeight = { param.H }
var probeDepth = { param.L }
var clearance = { exists(param.C) ? param.C : 5.0 }
var overtravel = { exists(param.O) ? param.O : 2.0 }
var edgeInset = { 10 }
if { exists(param.E) && param.E != null && param.E > 0 }
    set var.edgeInset = { param.E }
var skewLimit = { exists(param.T) ? param.T : global.nxtProbeMaxSkewDeg }
var probeId = { global.nxtTouchProbeID }

echo "G6503: Starting 3-pt perimeter rectangle block probe"

M5000
var centerX = { global.nxtAbsPos[0] }
var centerY = { global.nxtAbsPos[1] }
var startZ = { global.nxtAbsPos[2] }
var probeZ = { var.startZ - var.probeDepth }

var halfW = { var.blockWidth / 2 }
var halfH = { var.blockHeight / 2 }

if { var.halfW <= var.edgeInset || var.halfH <= var.edgeInset }
    abort { "G6503: Edge inset E must be < half width and half height" }

var xOutP = { var.centerX + var.halfW + var.clearance }
var xOutN = { var.centerX - var.halfW - var.clearance }
var yOutP = { var.centerY + var.halfH + var.clearance }
var yOutN = { var.centerY - var.halfH - var.clearance }
var xTgtP = { var.centerX + var.halfW - var.overtravel }
var xTgtN = { var.centerX - var.halfW + var.overtravel }
var yTgtP = { var.centerY + var.halfH - var.overtravel }
var yTgtN = { var.centerY - var.halfH + var.overtravel }
var xLow = { var.centerX - var.halfW + var.edgeInset }
var xMid = { var.centerX }
var xHigh = { var.centerX + var.halfW - var.edgeInset }
var yLow = { var.centerY - var.halfH + var.edgeInset }
var yMid = { var.centerY }
var yHigh = { var.centerY + var.halfH - var.edgeInset }

echo { "G6503: Block " ^ var.blockWidth ^ "x" ^ var.blockHeight ^ " E=" ^ var.edgeInset }

; Accumulators: face axis sum + along-axis sum (3 hits each)
var sumYm = 0
var sumYmAlongX = 0
var sumXp = 0
var sumXpAlongY = 0
var sumYp = 0
var sumYpAlongX = 0
var sumXn = 0
var sumXnAlongY = 0

; --- Face −Y: 3 pts along +X at dive Z ---
echo "G6503: Face -Y (3 pts along +X)"
G6550 X{var.xLow} Y{var.yOutN}
G6550 Z{var.probeZ}
G6512 Y{var.yTgtN} I{var.probeId} F{var.feedRate} R{var.retries}
set var.sumYm = { var.sumYm + global.nxtLastProbeResult }
set var.sumYmAlongX = { var.sumYmAlongX + var.xLow }
G6550 X{var.xMid} Y{var.yOutN}
G6512 Y{var.yTgtN} I{var.probeId} F{var.feedRate} R{var.retries}
set var.sumYm = { var.sumYm + global.nxtLastProbeResult }
set var.sumYmAlongX = { var.sumYmAlongX + var.xMid }
G6550 X{var.xHigh} Y{var.yOutN}
G6512 Y{var.yTgtN} I{var.probeId} F{var.feedRate} R{var.retries}
set var.sumYm = { var.sumYm + global.nxtLastProbeResult }
set var.sumYmAlongX = { var.sumYmAlongX + var.xHigh }

; --- Face +X: 3 pts along +Y ---
echo "G6503: Face +X (3 pts along +Y)"
G6550 Z{var.startZ}
G6550 X{var.xOutP} Y{var.yLow}
G6550 Z{var.probeZ}
G6512 X{var.xTgtP} I{var.probeId} F{var.feedRate} R{var.retries}
set var.sumXp = { var.sumXp + global.nxtLastProbeResult }
set var.sumXpAlongY = { var.sumXpAlongY + var.yLow }
G6550 X{var.xOutP} Y{var.yMid}
G6512 X{var.xTgtP} I{var.probeId} F{var.feedRate} R{var.retries}
set var.sumXp = { var.sumXp + global.nxtLastProbeResult }
set var.sumXpAlongY = { var.sumXpAlongY + var.yMid }
G6550 X{var.xOutP} Y{var.yHigh}
G6512 X{var.xTgtP} I{var.probeId} F{var.feedRate} R{var.retries}
set var.sumXp = { var.sumXp + global.nxtLastProbeResult }
set var.sumXpAlongY = { var.sumXpAlongY + var.yHigh }

; --- Face +Y: 3 pts along −X ---
echo "G6503: Face +Y (3 pts along -X)"
G6550 Z{var.startZ}
G6550 X{var.xHigh} Y{var.yOutP}
G6550 Z{var.probeZ}
G6512 Y{var.yTgtP} I{var.probeId} F{var.feedRate} R{var.retries}
set var.sumYp = { var.sumYp + global.nxtLastProbeResult }
set var.sumYpAlongX = { var.sumYpAlongX + var.xHigh }
G6550 X{var.xMid} Y{var.yOutP}
G6512 Y{var.yTgtP} I{var.probeId} F{var.feedRate} R{var.retries}
set var.sumYp = { var.sumYp + global.nxtLastProbeResult }
set var.sumYpAlongX = { var.sumYpAlongX + var.xMid }
G6550 X{var.xLow} Y{var.yOutP}
G6512 Y{var.yTgtP} I{var.probeId} F{var.feedRate} R{var.retries}
set var.sumYp = { var.sumYp + global.nxtLastProbeResult }
set var.sumYpAlongX = { var.sumYpAlongX + var.xLow }

; --- Face −X: 3 pts along −Y ---
echo "G6503: Face -X (3 pts along -Y)"
G6550 Z{var.startZ}
G6550 X{var.xOutN} Y{var.yHigh}
G6550 Z{var.probeZ}
G6512 X{var.xTgtN} I{var.probeId} F{var.feedRate} R{var.retries}
set var.sumXn = { var.sumXn + global.nxtLastProbeResult }
set var.sumXnAlongY = { var.sumXnAlongY + var.yHigh }
G6550 X{var.xOutN} Y{var.yMid}
G6512 X{var.xTgtN} I{var.probeId} F{var.feedRate} R{var.retries}
set var.sumXn = { var.sumXn + global.nxtLastProbeResult }
set var.sumXnAlongY = { var.sumXnAlongY + var.yMid }
G6550 X{var.xOutN} Y{var.yLow}
G6512 X{var.xTgtN} I{var.probeId} F{var.feedRate} R{var.retries}
set var.sumXn = { var.sumXn + global.nxtLastProbeResult }
set var.sumXnAlongY = { var.sumXnAlongY + var.yLow }

G6550 Z{var.startZ}

var faceXp = { var.sumXp / 3 }
var faceXn = { var.sumXn / 3 }
var faceYp = { var.sumYp / 3 }
var faceYm = { var.sumYm / 3 }
var alongYp = { var.sumXpAlongY / 3 }
var alongYn = { var.sumXnAlongY / 3 }
var alongXp = { var.sumYpAlongX / 3 }
var alongXm = { var.sumYmAlongX / 3 }

; Representative H0..H3 for existing chord / skew math
if { !exists(global.nxtProbeHitXY) }
    global nxtProbeHitXY = { vector(8, 0.0) }
elif { global.nxtProbeHitXY == null }
    set global.nxtProbeHitXY = { vector(8, 0.0) }
elif { #global.nxtProbeHitXY < 8 }
    set global.nxtProbeHitXY = { vector(8, 0.0) }

set global.nxtProbeHitXY[0] = { var.faceXp }
set global.nxtProbeHitXY[1] = { var.alongYp }
set global.nxtProbeHitXY[2] = { var.faceXn }
set global.nxtProbeHitXY[3] = { var.alongYn }
set global.nxtProbeHitXY[4] = { var.alongXp }
set global.nxtProbeHitXY[5] = { var.faceYp }
set global.nxtProbeHitXY[6] = { var.alongXm }
set global.nxtProbeHitXY[7] = { var.faceYm }

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
if { var.thetaDeg > 90 }
    set var.thetaDeg = { var.thetaDeg - 180 }
elif { var.thetaDeg <= -90 }
    set var.thetaDeg = { var.thetaDeg + 180 }

if { abs(var.thetaDeg) > var.skewLimit }
    abort { "G6503: |skew| " ^ var.thetaDeg ^ " deg exceeds limit " ^ var.skewLimit }

var m1x = { (var.xPx + var.xMx) / 2 }
var m1y = { (var.xPy + var.xMy) / 2 }
var m2x = { (var.yPx + var.yMx) / 2 }
var m2y = { (var.yPy + var.yMy) / 2 }
var solvedCx = { (var.m1x + var.m2x) / 2 }
var solvedCy = { (var.m1y + var.m2y) / 2 }

var actualWidth = { sqrt(var.vx * var.vx + var.vy * var.vy) }
var actualHeight = { sqrt(var.wx * var.wx + var.wy * var.wy) }

if { global.nxtProbeResults[var.pSlot] == null || #global.nxtProbeResults[var.pSlot] < 3 }
    set global.nxtProbeResults[var.pSlot] = { vector(#move.axes + 1, 0.0) }

set global.nxtProbeResults[var.pSlot][0] = { var.solvedCx }
set global.nxtProbeResults[var.pSlot][1] = { var.solvedCy }
set global.nxtProbeResults[var.pSlot][#move.axes] = { var.thetaDeg }

G6550 X{var.solvedCx} Y{var.solvedCy}

echo "G6503: Rectangle block probe completed (12 pts)"
echo "G6503: Block center at X=" ^ var.solvedCx ^ " Y=" ^ var.solvedCy
echo "G6503: Approx skew: " ^ var.thetaDeg ^ " deg"
echo "G6503: Measured dimensions: " ^ var.actualWidth ^ "x" ^ var.actualHeight ^ "mm"
echo "G6503: Result logged to table index " ^ var.pSlot

if { exists(param.U) && param.U != null }
    if { exists(param.Q) && param.Q != null }
        M6520 P{var.pSlot} W{param.U} X1 Y1 T{var.skewLimit} Q{param.Q}
    else
        M6520 P{var.pSlot} W{param.U} X1 Y1 T{var.skewLimit}
