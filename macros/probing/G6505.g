; G6505.g: POCKET PROBE (SINGLE AXIS)
;
; Two inward probes along the pocket width (N=0 → ±X, N=1 → ±Y) from a centered start.
; Unlike G6502/G6503, this does *not* populate nxtProbeHitXY — it uses global.nxtLastProbeResult
; (scalar along the probe axis) for each edge, then midpoint = (pos + neg) / 2.
;
; No skew/rotation from this cycle; rotation slot forced to 0. U still runs M6520 for translation.
;
; USAGE: G6505 P|U N<axis> W<width> L<depth> [F] [R] [C] [O] [Q]

if { !inputs[state.thisInput].active }
    M99

if { !global.nxtFeatureTouchProbe }
    abort { "G6505: Touch probe feature not enabled" }

if { global.nxtTouchProbeID == null }
    abort { "G6505: Touch probe ID not configured" }

if { state.currentTool != global.nxtProbeToolID }
    abort { "G6505: Touch probe (T" ^ global.nxtProbeToolID ^ ") must be selected" }

if { !exists(param.N) || param.N == null }
    abort { "G6505: N (0=X 1=Y) required" }

if { param.N != 0 && param.N != 1 }
    abort { "G6505: N must be 0 or 1" }

var pSlot = null
if { exists(param.U) && param.U != null }
    if { param.U < 1 || param.U > 9 }
        abort { "G6505: U must be 1-9" }
    set var.pSlot = { param.U - 1 }
elif { exists(param.P) && param.P != null }
    set var.pSlot = { param.P }
else
    abort { "G6505: P or U required" }

if { var.pSlot < 0 || var.pSlot >= #global.nxtProbeResults }
    abort { "G6505: Result slot out of range" }

if { !exists(param.W) || param.W == null || param.W <= 0 }
    abort { "G6505: W required" }

if { !exists(param.L) || param.L == null || param.L <= 0 }
    abort { "G6505: L required" }

var probeAxis = { param.N }
var feedRate = { exists(param.F) ? param.F : null }
var retries = { exists(param.R) ? param.R : global.nxtProbeInnerSampleCount }
var pocketWidth = { param.W }
var probeDepth = { param.L }
var clearance = { exists(param.C) ? param.C : 2.0 }
var overtravel = { exists(param.O) ? param.O : 2.0 }

var axisName = { var.probeAxis == 0 ? "X" : "Y" }

echo "G6505: Pocket probe along " ^ var.axisName

M5000
var centerX = { global.nxtAbsPos[0] }
var centerY = { global.nxtAbsPos[1] }
var startZ = { global.nxtAbsPos[2] }

var probeDistance = { var.pocketWidth / 2 + var.overtravel }
var probeZ = { var.startZ - var.probeDepth }
G6550 Z{var.probeZ}

if { var.probeAxis == 0 }
    echo "G6505: Probing +X edge"
    var xPlusTarget = { var.centerX + var.probeDistance }
    G6512 X{var.xPlusTarget} I{global.nxtTouchProbeID} F{var.feedRate} R{var.retries}
    var plusEdge = { global.nxtLastProbeResult }
    G6550 X{var.centerX}
    echo "G6505: Probing -X edge"
    var xMinusTarget = { var.centerX - var.probeDistance }
    G6512 X{var.xMinusTarget} I{global.nxtTouchProbeID} F{var.feedRate} R{var.retries}
    var minusEdge = { global.nxtLastProbeResult }
    G6550 X{var.centerX}
    var calculatedCenter = { (var.plusEdge + var.minusEdge) / 2 }
    var actualWidth = { var.plusEdge - var.minusEdge }
    var resultX = { var.calculatedCenter }
    var resultY = { var.centerY }
else
    echo "G6505: Probing +Y edge"
    var yPlusTarget = { var.centerY + var.probeDistance }
    G6512 Y{var.yPlusTarget} I{global.nxtTouchProbeID} F{var.feedRate} R{var.retries}
    var plusEdge = { global.nxtLastProbeResult }
    G6550 Y{var.centerY}
    echo "G6505: Probing -Y edge"
    var yMinusTarget = { var.centerY - var.probeDistance }
    G6512 Y{var.yMinusTarget} I{global.nxtTouchProbeID} F{var.feedRate} R{var.retries}
    var minusEdge = { global.nxtLastProbeResult }
    G6550 Y{var.centerY}
    var calculatedCenter = { (var.plusEdge + var.minusEdge) / 2 }
    var actualWidth = { var.plusEdge - var.minusEdge }
    var resultX = { var.centerX }
    var resultY = { var.calculatedCenter }

if { global.nxtProbeResults[var.pSlot] == null || #global.nxtProbeResults[var.pSlot] < 3 }
    set global.nxtProbeResults[var.pSlot] = { vector(#move.axes + 1, 0.0) }

set global.nxtProbeResults[var.pSlot][0] = { var.resultX }
set global.nxtProbeResults[var.pSlot][1] = { var.resultY }
set global.nxtProbeResults[var.pSlot][#move.axes] = 0.0

G6550 X{var.resultX} Y{var.resultY}
G6550 Z{var.startZ}

echo "G6505: Done center=" ^ var.calculatedCenter ^ " width=" ^ var.actualWidth
echo "G6505: Index " ^ var.pSlot

if { exists(param.U) && param.U != null }
    if { exists(param.Q) && param.Q != null }
        M98 P"M6520.g" P{var.pSlot} W{param.U} X Y Q{param.Q}
    else
        M98 P"M6520.g" P{var.pSlot} W{param.U} X Y
