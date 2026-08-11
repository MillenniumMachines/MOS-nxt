; G6520.g: VISE CORNER PROBE (meta — not the same file as utilities/M6520.g)
;
; Machine-local sequence:
;   1. Probe top surface (−Z) → corner Z in result[2]
;   2. Probe X-facing jaw along X at fixed probe Z (retracted from top hit)
;   3. Clear along X, probe Y-facing jaw along Y
; Corner XY = intersection of the two vertical faces. Optional X/Y args bias probe targets.
; With U, call M6520 (utilities/M6520.g) for G10 WCS apply — not this G6520 cycle file.
;
; USAGE: G6520 P|U L<depth> [X] [Y] [I] [F] [R] [C] [O] [Q]

if { !inputs[state.thisInput].active }
    M99

if { !global.nxtFeatureTouchProbe }
    abort { "G6520: Touch probe feature not enabled" }

if { global.nxtTouchProbeID == null }
    abort { "G6520: Touch probe ID not configured" }

if { state.currentTool != global.nxtProbeToolID }
    abort { "G6520: Touch probe (T" ^ global.nxtProbeToolID ^ ") must be selected" }

var pSlot = null
if { exists(param.U) && param.U != null }
    if { param.U < 1 || param.U > 9 }
        abort { "G6520: U must be 1-9" }
    set var.pSlot = { param.U - 1 }
elif { exists(param.P) && param.P != null }
    set var.pSlot = { param.P }
else
    abort { "G6520: P or U required" }

if { var.pSlot < 0 || var.pSlot >= #global.nxtProbeResults }
    abort { "G6520: Result slot out of range" }

if { !exists(param.L) || param.L == null || param.L <= 0 }
    abort { "G6520: Depth L required" }

var probeID = { exists(param.I) ? param.I : global.nxtTouchProbeID }
var clearance = { exists(param.C) ? param.C : 10.0 }
var feedRate = { exists(param.F) ? param.F : null }
var retries = { exists(param.R) ? param.R : global.nxtProbeInnerSampleCount }
var depth = { param.L }
var overtravel = { exists(param.O) ? param.O : 2.0 }

echo "G6520: Starting vise corner probe"

M5000
var startX = { global.nxtAbsPos[0] }
var startY = { global.nxtAbsPos[1] }
var startZ = { global.nxtAbsPos[2] }

var xSurfaceTarget = { exists(param.X) ? param.X : var.startX - var.overtravel }
var ySurfaceTarget = { exists(param.Y) ? param.Y : var.startY - var.overtravel }

echo "G6520: Probing Z surface"
; Top of jaw / part — defines corner Z in machine space
var zTarget = { var.startZ - var.depth }
G6512 Z{var.zTarget} I{var.probeID} F{var.feedRate} R{var.retries}
var zSurface = { global.nxtLastProbeResult }

M5000
; Z after backoff from Z probe — reuse for XY face probes without re-plunging through top
var currentZ = { global.nxtAbsPos[2] }

echo "G6520: Probing X surface"
; Stand off in Y to clear the Y jaw while moving in X toward the X face
var xProbeY = { var.ySurfaceTarget < var.startY ? var.ySurfaceTarget + var.clearance : var.ySurfaceTarget - var.clearance }
G6550 X{var.startX} Y{var.xProbeY} Z{var.currentZ}
G6512 X{var.xSurfaceTarget} I{var.probeID} F{var.feedRate} R{var.retries}
var xSurface = { global.nxtLastProbeResult }

var xClearPos = { var.xSurfaceTarget < var.startX ? var.xSurfaceTarget + var.clearance : var.xSurfaceTarget - var.clearance }
G6550 X{var.xClearPos}

echo "G6520: Probing Y surface"
; Clear in X to the side of the corner before sweeping toward the Y face
var yProbeX = { var.xSurfaceTarget < var.startX ? var.xSurfaceTarget + var.clearance : var.xSurfaceTarget - var.clearance }
G6550 X{var.yProbeX} Y{var.startY} Z{var.currentZ}
G6512 Y{var.ySurfaceTarget} I{var.probeID} F{var.feedRate} R{var.retries}
var ySurface = { global.nxtLastProbeResult }

var cornerX = { var.xSurface }
var cornerY = { var.ySurface }
var cornerZ = { var.zSurface }

if { global.nxtProbeResults[var.pSlot] == null || #global.nxtProbeResults[var.pSlot] < 3 }
    set global.nxtProbeResults[var.pSlot] = { vector(#move.axes + 1, 0.0) }

set global.nxtProbeResults[var.pSlot][0] = { var.cornerX }
set global.nxtProbeResults[var.pSlot][1] = { var.cornerY }
set global.nxtProbeResults[var.pSlot][2] = { var.cornerZ }
set global.nxtProbeResults[var.pSlot][#move.axes] = 0.0

G6550 X{var.cornerX} Y{var.cornerY} Z{var.cornerZ}

echo "G6520: Corner X=" ^ var.cornerX ^ " Y=" ^ var.cornerY ^ " Z=" ^ var.cornerZ

if { exists(param.U) && param.U != null }
    if { exists(param.Q) && param.Q != null }
        M6520 P{var.pSlot} W{param.U} X Y Z Q{param.Q}
    else
        M6520 P{var.pSlot} W{param.U} X Y Z
