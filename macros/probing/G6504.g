; G6504.g: WEB PROBE (BLOCK IN X OR Y)
;
; One-axis feature: two opposing outer probes only (N=0 → ±X, N=1 → ±Y).
; Uses H0/H1 in nxtProbeHitXY; center along the web = midpoint of the two contacts;
; orthogonal coordinate copies the start position (assumes operator started on centerline).
;
; No single rotation estimate from two points — nxtProbeResults[][axes] = 0; M6520 is translation only.
;
; USAGE: G6504 P<index>|U<wcs> N<axis> W<width> L<depth> [F<speed>] [R<retries>] [C<clearance>] [O<overtravel>] [Q<6520mode>]

if { !inputs[state.thisInput].active }
    M99

if { !global.nxtFeatureTouchProbe }
    abort { "G6504: Touch probe feature not enabled" }

if { global.nxtTouchProbeID == null }
    abort { "G6504: Touch probe ID not configured" }

if { state.currentTool != global.nxtProbeToolID }
    abort { "G6504: Touch probe (T" ^ global.nxtProbeToolID ^ ") must be selected" }

if { !exists(param.N) || param.N == null }
    abort { "G6504: Axis parameter N is required (0 for X, 1 for Y)" }

if { param.N != 0 && param.N != 1 }
    abort { "G6504: Axis parameter N must be 0 (X) or 1 (Y)" }

var pSlot = null
if { exists(param.U) && param.U != null }
    if { param.U < 1 || param.U > 9 }
        abort { "G6504: U must be 1-9" }
    set var.pSlot = { param.U - 1 }
elif { exists(param.P) && param.P != null }
    set var.pSlot = { param.P }
else
    abort { "G6504: P or U is required" }

if { var.pSlot < 0 || var.pSlot >= #global.nxtProbeResults }
    abort { "G6504: Result slot out of range" }

if { !exists(param.W) || param.W == null || param.W <= 0 }
    abort { "G6504: Width parameter W is required and must be positive" }

if { !exists(param.L) || param.L == null || param.L <= 0 }
    abort { "G6504: Depth parameter L is required and must be positive" }

var probeAxis = { param.N }
var feedRate = { exists(param.F) ? param.F : null }
var retries = { exists(param.R) ? param.R : global.nxtProbeInnerSampleCount }
var webWidth = { param.W }
var probeDepth = { param.L }
var clearance = { exists(param.C) ? param.C : 5.0 }
var overtravel = { exists(param.O) ? param.O : 2.0 }

var axisName = { var.probeAxis == 0 ? "X" : "Y" }

echo "G6504: Starting web probe cycle along " ^ var.axisName ^ " axis"

M5000
var centerX = { global.nxtAbsPos[0] }
var centerY = { global.nxtAbsPos[1] }
var startZ = { global.nxtAbsPos[2] }

var halfW = { var.webWidth / 2 }

echo "G6504: Probing web with width ~" ^ var.webWidth ^ "mm along " ^ var.axisName ^ " axis"

if { var.probeAxis == 0 }
    echo "G6504: Probing from +X direction"
    var xPlusStart = { var.centerX + var.halfW + var.clearance }
    var xPlusTarget = { var.centerX + var.halfW - var.overtravel }

    G6550 X{var.xPlusStart} Y{var.centerY}
    var probeZ = { var.startZ - var.probeDepth }
    G6550 Z{var.probeZ}

    G6512 X{var.xPlusTarget} I{global.nxtTouchProbeID} F{var.feedRate} R{var.retries} H0
    G6550 Z{var.startZ}

    echo "G6504: Probing from -X direction"
    var xMinusStart = { var.centerX - var.halfW - var.clearance }
    var xMinusTarget = { var.centerX - var.halfW + var.overtravel }

    G6550 X{var.xMinusStart} Y{var.centerY}
    G6550 Z{var.probeZ}

    G6512 X{var.xMinusTarget} I{global.nxtTouchProbeID} F{var.feedRate} R{var.retries} H1
    G6550 Z{var.startZ}

    var calculatedCenter = { (global.nxtProbeHitXY[0] + global.nxtProbeHitXY[2]) / 2 }
    var actualWidth = { abs(global.nxtProbeHitXY[0] - global.nxtProbeHitXY[2]) }

    var resultX = { var.calculatedCenter }
    var resultY = { var.centerY }
else
    echo "G6504: Probing from +Y direction"
    var yPlusStart = { var.centerY + var.halfW + var.clearance }
    var yPlusTarget = { var.centerY + var.halfW - var.overtravel }

    G6550 X{var.centerX} Y{var.yPlusStart}
    var probeZ = { var.startZ - var.probeDepth }
    G6550 Z{var.probeZ}

    G6512 Y{var.yPlusTarget} I{global.nxtTouchProbeID} F{var.feedRate} R{var.retries} H0
    G6550 Z{var.startZ}

    echo "G6504: Probing from -Y direction"
    var yMinusStart = { var.centerY - var.halfW - var.clearance }
    var yMinusTarget = { var.centerY - var.halfW + var.overtravel }

    G6550 X{var.centerX} Y{var.yMinusStart}
    G6550 Z{var.probeZ}

    G6512 Y{var.yMinusTarget} I{global.nxtTouchProbeID} F{var.feedRate} R{var.retries} H1
    G6550 Z{var.startZ}

    var calculatedCenter = { (global.nxtProbeHitXY[1] + global.nxtProbeHitXY[3]) / 2 }
    var actualWidth = { abs(global.nxtProbeHitXY[1] - global.nxtProbeHitXY[3]) }

    var resultX = { var.centerX }
    var resultY = { var.calculatedCenter }

if { global.nxtProbeResults[var.pSlot] == null || #global.nxtProbeResults[var.pSlot] < 3 }
    set global.nxtProbeResults[var.pSlot] = { vector(#move.axes + 1, 0.0) }

set global.nxtProbeResults[var.pSlot][0] = { var.resultX }
set global.nxtProbeResults[var.pSlot][1] = { var.resultY }
set global.nxtProbeResults[var.pSlot][#move.axes] = 0.0

G6550 X{var.resultX} Y{var.resultY}
G27 Z1

echo "G6504: Web probe completed"
echo "G6504: Web center along " ^ var.axisName ^ " axis: " ^ var.calculatedCenter
echo "G6504: Measured width: " ^ var.actualWidth ^ "mm"
echo "G6504: Result logged to table index " ^ var.pSlot

if { exists(param.U) && param.U != null }
    if { exists(param.Q) && param.Q != null }
        M98 P"M6520.g" P{var.pSlot} W{param.U} X Y Q{param.Q}
    else
        M98 P"M6520.g" P{var.pSlot} W{param.U} X Y
