; nxt-job-g68-apply.g: apply job G68 around live G10 origin
;
; Job-start M5011 (after Apply / Q1) and nxt-job-g68-restore.
; USAGE: M98 P"nxt-job-g68-apply.g" R<thetaDeg> W<wcs 1-9>
; No nested P (M98 steals P).
;
; G68 rebuilds RRF's current position in the rotated frame only when it is issued
; from the job file (or a macro it calls). From tpost or resume.g RRF keeps it
; unrotated, so a later job move that names only X or only Y would place the other
; axis off by about θ × distance from the work origin. Both posts name X and Y in
; the first move after a tool change, which resets it.

if { !inputs[state.thisInput].active }
    M99

if { !exists(param.R) || param.R == null }
    abort { "nxt-job-g68-apply: R (degrees) is required" }

if { !exists(param.W) || param.W == null || param.W < 1 || param.W > 9 }
    abort { "nxt-job-g68-apply: W must be 1-9" }

var thetaDeg = { param.R }
var wcsNumber = { param.W }
var wpIdx = { var.wcsNumber - 1 }

G90
G17
G69
M98 P"nxt-select-wcs.g" W{var.wcsNumber}

var ox = { move.axes[0].workplaceOffsets[var.wpIdx] }
var oy = { move.axes[1].workplaceOffsets[var.wpIdx] }

; RRF stores the centre as X/Y plus the selected workplace's offset, so X0 Y0 is the
; work origin (machine ox, oy).
G68 X0 Y0 R{var.thetaDeg}

; move.rotation is obsolete in RRF 3.7; the rotation is per motion system.
var cx = { move.motionSystems[0].rotation.centre[0] }
var cy = { move.motionSystems[0].rotation.centre[1] }

M98 P"nxt-select-wcs.g" W{var.wcsNumber}

if { !exists(global.nxtJobG68Deg) }
    global nxtJobG68Deg = { var.thetaDeg }
else
    set global.nxtJobG68Deg = { var.thetaDeg }
if { !exists(global.nxtJobG68Wcs) }
    global nxtJobG68Wcs = { var.wcsNumber }
else
    set global.nxtJobG68Wcs = { var.wcsNumber }

var nxtUx = { move.axes[0].userPosition }
var nxtUy = { move.axes[1].userPosition }
var nxtMx = { move.axes[0].machinePosition }
var nxtMy = { move.axes[1].machinePosition }
echo "nxt-job-g68-apply: G10 X=" ^ var.ox ^ " Y=" ^ var.oy
echo "nxt-job-g68-apply: centre X=" ^ var.cx ^ " Y=" ^ var.cy
echo "nxt-job-g68-apply: user X=" ^ var.nxtUx ^ " Y=" ^ var.nxtUy
echo "nxt-job-g68-apply: machine X=" ^ var.nxtMx ^ " Y=" ^ var.nxtMy
echo { "nxt-job-g68-apply: G68 R" ^ var.thetaDeg ^ " on G" ^ (53 + var.wcsNumber) }
