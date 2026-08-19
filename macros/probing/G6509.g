; G6509.g: INSIDE CORNER PROBE
;
; Adaptive 1/3-pt samples per face along away from the corner (H/I). Sense
; flipped vs G6508 (pocket air). C defaults to 5 mm.
; Finish: M400, G53 G1 raise to startZ (XY pinned), then G53 G1 to corner.
; With U: nxt-wcs-apply (G10 L2, no G0). Never G6550/G0 after the fit.
;
; USAGE: G6509 P|U N L H I [X] [Y] [F] [R] [C] [O] [E] [Q]

if { !inputs[state.thisInput].active }
    M99

if { !exists(global.nxtSkipJobPark) }
    global nxtSkipJobPark = true
else
    set global.nxtSkipJobPark = true

if { !global.nxtFeatureTouchProbe }
    abort { "G6509: Touch probe feature not enabled" }

if { global.nxtTouchProbeID == null }
    abort { "G6509: Touch probe ID not configured" }

if { state.currentTool != global.nxtProbeToolID }
    abort { "G6509: Touch probe (T" ^ global.nxtProbeToolID ^ ") must be selected" }

var pSlot = null
if { exists(param.U) && param.U != null }
    if { param.U < 1 || param.U > 9 }
        abort { "G6509: U must be 1-9" }
    set var.pSlot = { param.U - 1 }
elif { exists(param.P) && param.P != null }
    set var.pSlot = { param.P }
else
    abort { "G6509: P or U required" }

if { var.pSlot < 0 || var.pSlot >= #global.nxtProbeResults }
    abort { "G6509: Result slot out of range" }

if { !exists(param.N) || param.N == null }
    abort { "G6509: Corner N is required (0–3)" }

if { param.N < 0 || param.N > 3 }
    abort { "G6509: Corner N must be 0–3" }

if { !exists(param.L) || param.L == null || param.L <= 0 }
    abort { "G6509: Depth L required" }

if { !exists(param.H) || param.H == null || param.H <= 0 }
    abort { "G6509: Face length H (X-face along Y) is required and must be positive" }

if { !exists(param.I) || param.I == null || param.I <= 0 }
    abort { "G6509: Face length I (Y-face along X) is required and must be positive" }

var clearance = { exists(param.C) ? param.C : 5.0 }
if { var.clearance <= 0 }
    abort { "G6509: Approach clearance C must be positive" }

var cornerOffset = { exists(param.E) ? param.E : global.nxtCornerOffset }
if { var.cornerOffset == null || var.cornerOffset <= 0 }
    abort { "G6509: Corner offset E / nxtCornerOffset must be positive" }

var feedRate = { exists(param.F) ? param.F : null }
var retries = { exists(param.R) ? param.R : global.nxtProbeInnerSampleCount }
var probeDepth = { param.L }
var overtravel = { exists(param.O) ? param.O : 10.0 }
var faceLenX = { param.H }
var faceLenY = { param.I }

var dirX = { (param.N == 0 || param.N == 3) ? -1 : 1 }
var dirY = { (param.N == 0 || param.N == 1) ? 1 : -1 }

echo "G6509: Inside corner probe N=" ^ param.N

M5000
var startX = { global.nxtAbsPos[0] }
var startY = { global.nxtAbsPos[1] }
var startZ = { global.nxtAbsPos[2] }

; Face-1 dirs (pocket): negate outside dirX/dirY — do not flip again on top of this
var f1DirX = { 0 - var.dirX }
var f1DirY = { 0 - var.dirY }
var xTarget = { exists(param.X) ? param.X : var.startX - var.f1DirX * var.overtravel }
var probeZ = { var.startZ - var.probeDepth }
var airX = { var.startX + var.f1DirX * var.clearance }

echo "G6509: X surface"
M98 P"nxt-probe-face-line.g" A0 T{var.xTarget} W{var.airX} J{var.startX} K{var.startY} D{var.f1DirY} S{var.faceLenX} E{var.cornerOffset} Z{var.probeZ} F{var.feedRate} R{var.retries}

var fx0 = { global.nxtProbeHitXY[0] }
var fy0 = { global.nxtProbeHitXY[1] }
var fx1 = { global.nxtProbeHitXY[2] }
var fy1 = { global.nxtProbeHitXY[3] }

; Raise, then Y-face: flip relative to face-1 dirs (not outside dir*)
G6550 Z{var.startZ}
var flipX = { 0 - var.f1DirX }
var flipY = { 0 - var.f1DirY }
var airY2 = { var.startY + var.flipY * var.clearance }
var yTarget2 = { exists(param.Y) ? param.Y : var.startY - var.flipY * var.overtravel }

echo "G6509: Y surface"
M98 P"nxt-probe-face-line.g" A1 T{var.yTarget2} W{var.airY2} J{var.startX} K{var.startY} D{var.flipX} S{var.faceLenY} E{var.cornerOffset} Z{var.probeZ} F{var.feedRate} R{var.retries}

var yx0 = { global.nxtProbeHitXY[0] }
var yy0 = { global.nxtProbeHitXY[1] }
var yx1 = { global.nxtProbeHitXY[2] }
var yy1 = { global.nxtProbeHitXY[3] }

G6550 Z{var.startZ}

set global.nxtProbeHitXY[0] = { var.fx0 }
set global.nxtProbeHitXY[1] = { var.fy0 }
set global.nxtProbeHitXY[2] = { var.fx1 }
set global.nxtProbeHitXY[3] = { var.fy1 }
set global.nxtProbeHitXY[4] = { var.yx0 }
set global.nxtProbeHitXY[5] = { var.yy0 }
set global.nxtProbeHitXY[6] = { var.yx1 }
set global.nxtProbeHitXY[7] = { var.yy1 }

M98 P"nxt-corner-intersect.g" H{var.faceLenX} I{var.faceLenY}

var cornerX = { global.nxtFaceCornerX }
var cornerY = { global.nxtFaceCornerY }
var thetaDeg = { global.nxtFaceThetaDeg }

if { global.nxtProbeResults[var.pSlot] == null || #global.nxtProbeResults[var.pSlot] < 3 }
    set global.nxtProbeResults[var.pSlot] = { vector(#move.axes + 1, 0.0) }

set global.nxtProbeResults[var.pSlot][0] = { var.cornerX }
set global.nxtProbeResults[var.pSlot][1] = { var.cornerY }
set global.nxtProbeResults[var.pSlot][#move.axes] = { var.thetaDeg }

var nxtReadX = { global.nxtProbeResults[var.pSlot][0] }
var nxtReadY = { global.nxtProbeResults[var.pSlot][1] }
var nxtBadX = { abs(var.nxtReadX - var.cornerX) > 0.01 }
var nxtBadY = { abs(var.nxtReadY - var.cornerY) > 0.01 }
if { var.nxtBadX || var.nxtBadY }
    abort { "G6509: Result table mismatch vs fitted corner" }

var nxtCnr00 = { abs(var.cornerX) < 0.01 && abs(var.cornerY) < 0.01 }
var nxtJogFar = { abs(var.startX) > 5 || abs(var.startY) > 5 }
if { var.nxtCnr00 && var.nxtJogFar }
    abort { "G6509: Corner fit is 0,0 but jog was not at origin" }

M98 P"nxt-wp-ensure-cnr.g"
set global.nxtWPCnrNum[var.pSlot] = { param.N }

echo "G6509: Corner X=" ^ var.cornerX ^ " Y=" ^ var.cornerY
echo "G6509: Skew " ^ var.thetaDeg ^ " deg"

; M400, raise startZ with XY pinned, G53 G1 to fit (never G6550/G0)
M400
var parkFeed = { sensors.probes[global.nxtTouchProbeID].travelSpeed }
var parkHasA = { #move.axes > 3 }
var parkTripped = { sensors.probes[global.nxtTouchProbeID].value[0] != 0 }
if { var.parkTripped }
    var curX = { move.axes[0].machinePosition }
    var curY = { move.axes[1].machinePosition }
    var curZ = { move.axes[2].machinePosition }
    var dX = { var.cornerX - var.curX }
    var dY = { var.cornerY - var.curY }
    var mag = { sqrt(var.dX * var.dX + var.dY * var.dY) }
    if { var.mag <= 0 }
        abort { "G6509: Probe triggered at corner — cannot clear in place" }
    var diveH = { sensors.probes[global.nxtTouchProbeID].diveHeights[0] }
    var step = { var.diveH }
    if { var.step > var.mag }
        set var.step = { var.mag }
    var clrX = { var.curX + (var.dX / var.mag * var.step) }
    var clrY = { var.curY + (var.dY / var.mag * var.step) }
    if { var.parkHasA }
        var curA = { move.axes[3].machinePosition }
        G53 G1 F{var.parkFeed} X{var.clrX} Y{var.clrY} Z{var.curZ} A{var.curA}
    else
        G53 G1 F{var.parkFeed} X{var.clrX} Y{var.clrY} Z{var.curZ}
    M400
    var stillOn = { sensors.probes[global.nxtTouchProbeID].value[0] != 0 }
    if { var.stillOn }
        abort { "G6509: Probe still triggered after clear — unsafe to park" }

G90
var pinX = { move.axes[0].machinePosition }
var pinY = { move.axes[1].machinePosition }
var pinA = { 0 }
if { var.parkHasA }
    set var.pinA = { move.axes[3].machinePosition }
    G53 G1 F{var.parkFeed} X{var.pinX} Y{var.pinY} Z{var.startZ} A{var.pinA}
else
    G53 G1 F{var.parkFeed} X{var.pinX} Y{var.pinY} Z{var.startZ}
M400
if { var.parkHasA }
    G53 G1 F{var.parkFeed} X{var.cornerX} Y{var.cornerY} Z{var.startZ} A{var.pinA}
else
    G53 G1 F{var.parkFeed} X{var.cornerX} Y{var.cornerY} Z{var.startZ}
M400
echo "G6509: parked machine X=" ^ move.axes[0].machinePosition ^ " Y=" ^ move.axes[1].machinePosition

if { exists(param.U) && param.U != null }
    if { exists(param.Q) && param.Q != null }
        M98 P"nxt-wcs-apply.g" I{var.pSlot} W{param.U} X1 Y1 Q{param.Q}
    else
        M98 P"nxt-wcs-apply.g" I{var.pSlot} W{param.U} X1 Y1
M98 P"nxt-g38-cancel.g"
