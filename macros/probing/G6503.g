; G6503.g: RECTANGLE BLOCK PROBE (N-pt perimeter)
;
; Probes each of 4 faces from outside with N points (default 2: near/far inset).
; Outside clearance C defaults to 5 mm; edge inset E (corner clearance) defaults to 10 mm.
; Stay at dive Z along a face; raise to start Z only between faces. CCW from −Y/−X.
;
; Skew = one line slope fitted through every face's hits. Face means → nxtProbeHitXY
; H0..H3 → center + size; nxtProbeResults; M6520 if U.
;
; USAGE: G6503 P|U W H L [F] [R] [C] [O] [E] [N] [T] [Q]
;   C: Outside face clearance (default 5)
;   E: Edge inset from assumed corners / corner clearance (default 10)
;   N: Points per face (default 2, max 5); evenly spaced between inset ends

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
var nPts = { 2 }
if { exists(param.N) && param.N != null }
    set var.nPts = { param.N }
if { var.nPts < 2 || var.nPts > 5 || floor(var.nPts) != var.nPts }
    abort { "G6503: Points per face N must be a whole number from 2 to 5" }
var skewLimit = { exists(param.T) ? param.T : global.nxtProbeMaxSkewDeg }
var probeId = { global.nxtTouchProbeID }

echo { "G6503: Starting " ^ var.nPts ^ "-pt perimeter rectangle block probe" }

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
var xHigh = { var.centerX + var.halfW - var.edgeInset }
var yLow = { var.centerY - var.halfH + var.edgeInset }
var yHigh = { var.centerY + var.halfH - var.edgeInset }
var spanX = { var.xHigh - var.xLow }
var spanY = { var.yHigh - var.yLow }
var denom = { var.nPts - 1 }

echo { "G6503: Block " ^ var.blockWidth ^ "x" ^ var.blockHeight ^ " E=" ^ var.edgeInset ^ " N=" ^ var.nPts }

; Accumulators: face axis sum + along-axis sum (N hits each)
var sumYm = 0
var sumYmAlongX = 0
var sumXp = 0
var sumXpAlongY = 0
var sumYp = 0
var sumYpAlongX = 0
var sumXn = 0
var sumXnAlongY = 0
var fi = 0
var along = 0
; Skew fit sums. a = probe point along the face, d = hit, both from the jog point.
; The points sit symmetrically about the jog point, so each face's a sums to 0.
var sumAdX = 0
var sumAaX = 0
var sumAdY = 0
var sumAaY = 0

; --- Face −Y: N pts along +X at dive Z ---
echo { "G6503: Face -Y (" ^ var.nPts ^ " pts along +X)" }
G6550 X{var.xLow} Y{var.yOutN}
G6550 Z{var.probeZ}
set var.fi = 0
while { var.fi < var.nPts }
    set var.along = { var.xLow + var.fi * var.spanX / var.denom }
    G6550 X{var.along} Y{var.yOutN}
    G6512 Y{var.yTgtN} I{var.probeId} F{var.feedRate} R{var.retries}
    set var.sumYm = { var.sumYm + global.nxtLastProbeResult }
    set var.sumYmAlongX = { var.sumYmAlongX + var.along }
    set var.sumAdY = { var.sumAdY + (var.along - var.centerX) * (global.nxtLastProbeResult - var.centerY) }
    set var.sumAaY = { var.sumAaY + (var.along - var.centerX) * (var.along - var.centerX) }
    set var.fi = { var.fi + 1 }

; --- Face +X: N pts along +Y ---
echo { "G6503: Face +X (" ^ var.nPts ^ " pts along +Y)" }
G6550 Z{var.startZ}
G6550 X{var.xOutP} Y{var.yLow}
G6550 Z{var.probeZ}
set var.fi = 0
while { var.fi < var.nPts }
    set var.along = { var.yLow + var.fi * var.spanY / var.denom }
    G6550 X{var.xOutP} Y{var.along}
    G6512 X{var.xTgtP} I{var.probeId} F{var.feedRate} R{var.retries}
    set var.sumXp = { var.sumXp + global.nxtLastProbeResult }
    set var.sumXpAlongY = { var.sumXpAlongY + var.along }
    set var.sumAdX = { var.sumAdX + (var.along - var.centerY) * (global.nxtLastProbeResult - var.centerX) }
    set var.sumAaX = { var.sumAaX + (var.along - var.centerY) * (var.along - var.centerY) }
    set var.fi = { var.fi + 1 }

; --- Face +Y: N pts along −X ---
echo { "G6503: Face +Y (" ^ var.nPts ^ " pts along -X)" }
G6550 Z{var.startZ}
G6550 X{var.xHigh} Y{var.yOutP}
G6550 Z{var.probeZ}
set var.fi = 0
while { var.fi < var.nPts }
    set var.along = { var.xHigh - var.fi * var.spanX / var.denom }
    G6550 X{var.along} Y{var.yOutP}
    G6512 Y{var.yTgtP} I{var.probeId} F{var.feedRate} R{var.retries}
    set var.sumYp = { var.sumYp + global.nxtLastProbeResult }
    set var.sumYpAlongX = { var.sumYpAlongX + var.along }
    set var.sumAdY = { var.sumAdY + (var.along - var.centerX) * (global.nxtLastProbeResult - var.centerY) }
    set var.sumAaY = { var.sumAaY + (var.along - var.centerX) * (var.along - var.centerX) }
    set var.fi = { var.fi + 1 }

; --- Face −X: N pts along −Y ---
echo { "G6503: Face -X (" ^ var.nPts ^ " pts along -Y)" }
G6550 Z{var.startZ}
G6550 X{var.xOutN} Y{var.yHigh}
G6550 Z{var.probeZ}
set var.fi = 0
while { var.fi < var.nPts }
    set var.along = { var.yHigh - var.fi * var.spanY / var.denom }
    G6550 X{var.xOutN} Y{var.along}
    G6512 X{var.xTgtN} I{var.probeId} F{var.feedRate} R{var.retries}
    set var.sumXn = { var.sumXn + global.nxtLastProbeResult }
    set var.sumXnAlongY = { var.sumXnAlongY + var.along }
    set var.sumAdX = { var.sumAdX + (var.along - var.centerY) * (global.nxtLastProbeResult - var.centerX) }
    set var.sumAaX = { var.sumAaX + (var.along - var.centerY) * (var.along - var.centerY) }
    set var.fi = { var.fi + 1 }

G6550 Z{var.startZ}

var faceXp = { var.sumXp / var.nPts }
var faceXn = { var.sumXn / var.nPts }
var faceYp = { var.sumYp / var.nPts }
var faceYm = { var.sumYm / var.nPts }
var alongYp = { var.sumXpAlongY / var.nPts }
var alongYn = { var.sumXnAlongY / var.nPts }
var alongXp = { var.sumYpAlongX / var.nPts }
var alongXm = { var.sumYmAlongX / var.nPts }

; Face means as H0..H3 (G6502's layout) for the centre and size
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

; Skew θ, anticlockwise positive like G68 R. The X faces run x = c - tan(θ)·y and the Y faces
; y = c + tan(θ)·x, so tan(θ) is the least-squares slope shared by all four faces. vy is always 0
; (both X faces are probed at the same Y), so the face means can't give θ (#60).
; Σa² > 0, so atan2 stays inside ±90°.
var skewXDeg = { degrees(atan2(-var.sumAdX, var.sumAaX)) }
var skewYDeg = { degrees(atan2(var.sumAdY, var.sumAaY)) }
var thetaDeg = { degrees(atan2(var.sumAdY - var.sumAdX, var.sumAaX + var.sumAaY)) }

if { abs(var.thetaDeg) > var.skewLimit }
    abort { "G6503: |skew| " ^ var.thetaDeg ^ " deg exceeds limit " ^ var.skewLimit }

var m1x = { (var.xPx + var.xMx) / 2 }
var m1y = { (var.xPy + var.xMy) / 2 }
var m2x = { (var.yPx + var.yMx) / 2 }
var m2y = { (var.yPy + var.yMy) / 2 }
; Centre = where the X mid-line (halfway between the ±X faces) meets the Y mid-line.
; m1y and m2x are where the probe stood, not measurements, so they must not be averaged in.
var cosT = { cos(var.thetaDeg * pi / 180) }
var sinT = { sin(var.thetaDeg * pi / 180) }
var midU = { var.m1x * var.cosT + var.m1y * var.sinT }
var midN = { var.m2y * var.cosT - var.m2x * var.sinT }
var solvedCx = { var.midU * var.cosT - var.midN * var.sinT }
var solvedCy = { var.midU * var.sinT + var.midN * var.cosT }

; Face spacing square to the faces. Across the block along X or Y, it's W/cos(θ).
var actualWidth = { var.vx * var.cosT + var.vy * var.sinT }
var actualHeight = { var.wy * var.cosT - var.wx * var.sinT }

if { global.nxtProbeResults[var.pSlot] == null || #global.nxtProbeResults[var.pSlot] < 3 }
    set global.nxtProbeResults[var.pSlot] = { vector(#move.axes + 1, 0.0) }

set global.nxtProbeResults[var.pSlot][0] = { var.solvedCx }
set global.nxtProbeResults[var.pSlot][1] = { var.solvedCy }
set global.nxtProbeResults[var.pSlot][#move.axes] = { var.thetaDeg }

G6550 X{var.solvedCx} Y{var.solvedCy}

var totalPts = { 4 * var.nPts }
echo { "G6503: Rectangle block probe completed (" ^ var.totalPts ^ " pts)" }
echo "G6503: Block center at X=" ^ var.solvedCx ^ " Y=" ^ var.solvedCy
echo { "G6503: Skew " ^ var.thetaDeg ^ " deg (X faces " ^ var.skewXDeg ^ ", Y faces " ^ var.skewYDeg ^ ")" }
echo "G6503: Measured dimensions: " ^ var.actualWidth ^ "x" ^ var.actualHeight ^ "mm"
echo "G6503: Result logged to table index " ^ var.pSlot

if { exists(param.U) && param.U != null }
    if { exists(param.Q) && param.Q != null }
        M6520 P{var.pSlot} W{param.U} X1 Y1 T{var.skewLimit} Q{param.Q}
    else
        M6520 P{var.pSlot} W{param.U} X1 Y1 T{var.skewLimit}
