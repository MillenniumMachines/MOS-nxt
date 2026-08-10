; G6508.g: OUTSIDE CORNER PROBE
;
; Corner is convex — approach each face from “air”, clearance offsets keep the stylus off the
; second face until the relevant axis is positioned. First probe finds X-normal plane position,
; retract Z, jog clear in X, second probe finds Y-normal plane; intersection (xSurface, ySurface)
; is the corner in machine coords. Optional X/Y target args aim the probe toward the corner.
; No rotation from this cycle (θ = 0).
;
; USAGE: G6508 P<index>|U<wcs> L<depth> [X] [Y] [F] [R] [C] [Q]

if { !inputs[state.thisInput].active }
    M99

if { !global.nxtFeatureTouchProbe }
    abort { "G6508: Touch probe feature not enabled" }

if { global.nxtTouchProbeID == null }
    abort { "G6508: Touch probe ID not configured" }

if { state.currentTool != global.nxtProbeToolID }
    abort { "G6508: Touch probe (T" ^ global.nxtProbeToolID ^ ") must be selected" }

var pSlot = null
if { exists(param.U) && param.U != null }
    if { param.U < 1 || param.U > 9 }
        abort { "G6508: U must be 1-9" }
    set var.pSlot = { param.U - 1 }
elif { exists(param.P) && param.P != null }
    set var.pSlot = { param.P }
else
    abort { "G6508: P or U is required" }

if { var.pSlot < 0 || var.pSlot >= #global.nxtProbeResults }
    abort { "G6508: Result slot out of range" }

if { !exists(param.L) || param.L == null || param.L <= 0 }
    abort { "G6508: Depth (L) parameter is required and must be positive" }

var clearance = { exists(param.C) ? param.C : 5.0 }
var feedRate = { exists(param.F) ? param.F : null }
var retries = { exists(param.R) ? param.R : global.nxtProbeInnerSampleCount }
var probeDepth = { param.L }

echo "G6508: Starting outside corner probe"

M5000
var startX = { global.nxtAbsPos[0] }
var startY = { global.nxtAbsPos[1] }
var startZ = { global.nxtAbsPos[2] }

var xTarget = { exists(param.X) ? param.X : var.startX - 10.0 }
var yTarget = { exists(param.Y) ? param.Y : var.startY - 10.0 }

echo "G6508: Probing X surface"
var xProbeY = { var.yTarget > var.startY ? var.yTarget + var.clearance : var.yTarget - var.clearance }
G6550 X{var.startX} Y{var.xProbeY}

var probeZ = { var.startZ - var.probeDepth }
G6550 Z{var.probeZ}

G6512 X{var.xTarget} I{global.nxtTouchProbeID} F{var.feedRate} R{var.retries}
var xSurface = { global.nxtLastProbeResult }

G6550 Z{var.startZ}

var xClearPos = { var.xTarget > var.startX ? var.xTarget - var.clearance : var.xTarget + var.clearance }
G6550 X{var.xClearPos}

echo "G6508: Probing Y surface"
var yProbeX = { var.xTarget > var.startX ? var.xTarget + var.clearance : var.xTarget - var.clearance }
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

echo "G6508: Outside corner probe completed"
echo "G6508: Corner at X=" ^ var.cornerX ^ " Y=" ^ var.cornerY
echo "G6508: Result logged to table index " ^ var.pSlot

if { exists(param.U) && param.U != null }
    if { exists(param.Q) && param.Q != null }
        M98 P"M6520.g" P{var.pSlot} W{param.U} X Y Q{param.Q}
    else
        M98 P"M6520.g" P{var.pSlot} W{param.U} X Y
