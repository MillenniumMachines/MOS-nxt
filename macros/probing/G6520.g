; G6520.g: VISE CORNER PROBE
;
; Probes a vise corner by first probing the top surface in Z, then probing
; the corner in X and Y using an outside corner probe sequence.
;
; USAGE: G6520 P<index> L<depth> [X<x-surface>] [Y<y-surface>] [I<probeID>] [F<speed>] [R<retries>] [C<clearance>] [O<overtravel>]
;
; Parameters:
;   P: Result table index (0-based) where results will be stored - REQUIRED
;   L: Probe depth below starting position - REQUIRED
;   X: Target coordinate for X-axis surface probe (defaults to current X - overtravel)
;   Y: Target coordinate for Y-axis surface probe (defaults to current Y - overtravel)
;   I: Probe ID (defaults to global.nxtTouchProbeID if not specified)
;   F: Optional speed override in mm/min
;   R: Number of retries for averaging
;   C: Clearance distance between probes (default: 5mm)
;   O: Overtravel distance beyond expected surfaces for default targets (default: 10mm)
;
; The vise corner coordinates (X, Y, Z) are logged to nxtProbeResults table.



; Validate that touch probe feature is enabled and configured
if { !global.nxtFeatureTouchProbe }
    abort { "G6520: Touch probe feature not enabled" }

if { global.nxtTouchProbeID == null }
    abort { "G6520: Touch probe ID not configured" }

; Ensure we're using the touch probe
if { state.currentTool != global.nxtProbeToolID }
    abort { "G6520: Touch probe (T" ^ global.nxtProbeToolID ^ ") must be selected" }

; Validate required parameters
if { !exists(param.P) || param.P == null || param.P < 0 }
    abort { "G6520: Result index parameter P is required and must be >= 0" }

if { param.P >= #global.nxtProbeResults }
    abort { "G6520: Result index P=" ^ param.P ^ " exceeds table size (" ^ #global.nxtProbeResults ^ ")" }

if { !exists(param.L) || param.L == null || param.L <= 0 }
    abort { "G6520: Depth parameter L is required and must be positive" }

; Set defaults for optional parameters
var probeID = { exists(param.I) ? param.I : global.nxtTouchProbeID }
var clearance = { exists(param.C) ? param.C : 10.0 }
var feedRate = { exists(param.F) ? param.F : null }
var retries = { exists(param.R) ? param.R : null }
var depth = { param.L }
var overtravel = { exists(param.O) ? param.O : 2.0 }

echo "G6520: Starting vise corner probe"

; Get current position (should be above the vise corner)
M5000
var startX = { global.nxtAbsPos[0] }
var startY = { global.nxtAbsPos[1] }
var startZ = { global.nxtAbsPos[2] }

; Set default targets if not provided (current position - overtravel for vise corner)
var xSurfaceTarget = { exists(param.X) ? param.X : var.startX - var.overtravel }
var ySurfaceTarget = { exists(param.Y) ? param.Y : var.startY - var.overtravel }

; Phase 1: Probe Z surface (top of vise/workpiece)
echo "G6520: Probing Z surface (top of vise corner)"

; Calculate Z probe target
var zTarget = { var.startZ - var.depth }

; Execute Z surface probe
G6512 X{var.startX} Y{var.startY} Z{var.zTarget} I{var.probeID} F{var.feedRate} R{var.retries}
var zSurface = { global.nxtLastProbeResult }

; Update current position after Z probe
M5000
var currentZ = { global.nxtAbsPos[2] }

echo "G6520: Z surface found at " ^ var.zSurface

; Phase 2: Probe X surface (vise jaw)
echo "G6520: Probing X surface"

; Move to X probe position (away from corner by clearance distance)
var xProbeY = { var.ySurfaceTarget < var.startY ? var.ySurfaceTarget + var.clearance : var.ySurfaceTarget - var.clearance }
G6550 X{var.startX} Y{var.xProbeY}

; Execute X surface probe at the Z level we found
G6512 X{var.xSurfaceTarget} Y{var.xProbeY} Z{var.currentZ} I{var.probeID} F{var.feedRate} R{var.retries}
var xSurface = { global.nxtLastProbeResult }

; Move away from X surface
var xClearPos = { var.xSurfaceTarget < var.startX ? var.xSurfaceTarget + var.clearance : var.xSurfaceTarget - var.clearance }
G6550 X{var.xClearPos}

; Phase 3: Probe Y surface (vise jaw)
echo "G6520: Probing Y surface"

; Move to Y probe position (away from corner by clearance distance)
var yProbeX = { var.xSurfaceTarget < var.startX ? var.xSurfaceTarget + var.clearance : var.xSurfaceTarget - var.clearance }
G6550 X{var.yProbeX} Y{var.startY}

; Execute Y surface probe at the Z level we found
G6512 X{var.yProbeX} Y{var.ySurfaceTarget} Z{var.currentZ} I{var.probeID} F{var.feedRate} R{var.retries}
var ySurface = { global.nxtLastProbeResult }

; The vise corner coordinates are the intersection of the surfaces
var cornerX = { var.xSurface }
var cornerY = { var.ySurface }
var cornerZ = { var.zSurface }

; Log results to probe results table
; Initialize the result vector if needed
if { #global.nxtProbeResults[param.P] < 3 }
    set global.nxtProbeResults[param.P] = { vector(#move.axes + 1, 0.0) }

; Store all three coordinates (X, Y, Z)
set global.nxtProbeResults[param.P][0] = { var.cornerX }
set global.nxtProbeResults[param.P][1] = { var.cornerY }
set global.nxtProbeResults[param.P][2] = { var.cornerZ }

; Move to the found corner position
G6550 X{var.cornerX} Y{var.cornerY} Z{var.cornerZ}

; Return to safe height
G27 Z1

echo "G6520: Vise corner probe completed"
echo "G6520: Corner found at X=" ^ var.cornerX ^ " Y=" ^ var.cornerY ^ " Z=" ^ var.cornerZ
echo "G6520: Result logged to table index " ^ param.P