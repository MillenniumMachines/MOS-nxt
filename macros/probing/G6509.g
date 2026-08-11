; G6509.g: INSIDE CORNER PROBE
;
; Concave pocket corner: probes move *into* the pocket (defaults offset by O along +X/+Y if
; X/Y omitted). Clearance jigging mirrors G6508 but interior side: stay inside while switching faces.
; Result corner = (xSurface, ySurface); rotation slot 0.
;
; USAGE: G6509 P|U L<depth> [X] [Y] [F] [R] [C] [O] [Q]

if { !inputs[state.thisInput].active }
    M99

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

if { !exists(param.L) || param.L == null || param.L <= 0 }
    abort { "G6509: Depth L required" }

var clearance = { exists(param.C) ? param.C : 5.0 }
var feedRate = { exists(param.F) ? param.F : null }
var retries = { exists(param.R) ? param.R : global.nxtProbeInnerSampleCount }
var probeDepth = { param.L }
var overtravel = { exists(param.O) ? param.O : 10.0 }

echo "G6509: Inside corner probe"

M5000
var startX = { global.nxtAbsPos[0] }
var startY = { global.nxtAbsPos[1] }
var startZ = { global.nxtAbsPos[2] }

var xTarget = { exists(param.X) ? param.X : var.startX + var.overtravel }
var yTarget = { exists(param.Y) ? param.Y : var.startY + var.overtravel }

echo "G6509: X surface"
var xProbeY = { var.yTarget > var.startY ? var.yTarget - var.clearance : var.yTarget + var.clearance }
G6550 X{var.startX} Y{var.xProbeY}
var probeZ = { var.startZ - var.probeDepth }
G6550 Z{var.probeZ}
G6512 X{var.xTarget} I{global.nxtTouchProbeID} F{var.feedRate} R{var.retries}
var xSurface = { global.nxtLastProbeResult }
G6550 Z{var.startZ}
var xClearPos = { var.xTarget > var.startX ? var.xTarget - var.clearance : var.xTarget + var.clearance }
G6550 X{var.xClearPos}

echo "G6509: Y surface"
var yProbeX = { var.xTarget > var.startX ? var.xTarget - var.clearance : var.xTarget + var.clearance }
G6550 X{var.yProbeX} Y{var.startY}
G6550 Z{var.probeZ}
G6512 Y{var.yTarget} I{global.nxtTouchProbeID} F{var.feedRate} R{var.retries}
var ySurface = { global.nxtLastProbeResult }
G6550 Z{var.startZ}

var cornerX = { var.xSurface }
var cornerY = { var.ySurface }

if { global.nxtProbeResults[var.pSlot] == null || #global.nxtProbeResults[var.pSlot] < 3 }
    set global.nxtProbeResults[var.pSlot] = { vector(#move.axes + 1, 0.0) }

set global.nxtProbeResults[var.pSlot][0] = { var.cornerX }
set global.nxtProbeResults[var.pSlot][1] = { var.cornerY }
set global.nxtProbeResults[var.pSlot][#move.axes] = 0.0

echo "G6509: Corner X=" ^ var.cornerX ^ " Y=" ^ var.cornerY

if { exists(param.U) && param.U != null }
    if { exists(param.Q) && param.Q != null }
        M6520 P{var.pSlot} W{param.U} X Y Q{param.Q}
    else
        M6520 P{var.pSlot} W{param.U} X Y
