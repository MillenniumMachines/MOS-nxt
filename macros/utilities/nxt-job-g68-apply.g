; nxt-job-g68-apply.g: apply job G68 around live G10 origin
;
; Job-start M5011 (after Apply / Q1) and nxt-job-g68-restore.
; USAGE: M98 P"nxt-job-g68-apply.g" R<thetaDeg> W<wcs 1-9>
; No nested P (M98 steals P).

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

G68 X0 Y0 R{var.thetaDeg}

var cx = { 0 }
var cy = { 0 }
var haveC = false
if { exists(move.rotation) }
    if { exists(move.rotation.centre) }
        if { move.rotation.centre != null }
            set var.haveC = true
            set var.cx = { move.rotation.centre[0] }
            set var.cy = { move.rotation.centre[1] }

var g10Far = { abs(var.ox) > 5 || abs(var.oy) > 5 }
var ctrNear0 = { abs(var.cx) < 0.5 && abs(var.cy) < 0.5 }
var retryCtr = { var.haveC && var.g10Far && var.ctrNear0 }
if { var.retryCtr }
    G69
    var g68x = { 0 - var.ox }
    var g68y = { 0 - var.oy }
    G68 X{var.g68x} Y{var.g68y} R{var.thetaDeg}
    echo "nxt-job-g68-apply: retried G68 XY compensating G10"
    if { exists(move.rotation) }
        if { exists(move.rotation.centre) }
            if { move.rotation.centre != null }
                set var.cx = { move.rotation.centre[0] }
                set var.cy = { move.rotation.centre[1] }

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
echo "nxt-job-g68-apply: G68 R" ^ var.thetaDeg ^ " on G" ^ (53 + var.wcsNumber)
