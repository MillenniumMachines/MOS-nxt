; nxt-wcs-apply.g: APPLY WCS FROM PROBE RESULT (NO TRAVEL)
;
; Same G10 L2 as M6520 (never L20). No travel — caller already G53-parked
; at the fit (G6500/G6501/G6508/G6509/G6520). M6520 G53 G1s stored L2 XY.
; Does not apply G68 — that is M5011 at job start. Q only arms policy.
; M98 steals P for the filename — result slot is I (not P).
; Skips nxt-select-wcs when workplace W is already active (no redundant G54).
;
; USAGE: M98 P"nxt-wcs-apply.g" I<resultIndex> W<wcsNumber> [X1] [Y1] [Z1] [A1] [Q] [T]
;
; Parameters:
;   I: Probe results table index (0-9) — REQUIRED (M98 cannot pass P)
;   W: WCS number (1-9 for G54-G59.3) — REQUIRED
;   X1/Y1/Z1/A1: Axis presence flags (use X1 not bare X)
;   Q: Job-start rotation policy for M5011 (same as M6520 Q; omitted = Q0 prompt)
;   T: Optional max |skew| (deg); default global.nxtProbeMaxSkewDeg

if { !inputs[state.thisInput].active }
    M99

if { !exists(param.I) || param.I == null || param.I < 0 }
    abort { "nxt-wcs-apply: Result index I is required and must be >= 0" }

if { param.I >= #global.nxtProbeResults }
    abort { "nxt-wcs-apply: Result index I=" ^ param.I ^ " exceeds table size" }

if { !exists(param.W) || param.W == null || param.W < 1 || param.W > 9 }
    abort { "nxt-wcs-apply: W must be 1-9 (G54-G59.3)" }

if { !exists(param.X) && !exists(param.Y) && !exists(param.Z) && !exists(param.A) }
    abort { "nxt-wcs-apply: At least one axis flag (X, Y, Z, or A) required" }

if { global.nxtProbeResults[param.I] == null }
    abort { "nxt-wcs-apply: No probe result at index " ^ param.I }

var resultVector = { global.nxtProbeResults[param.I] }

if { #var.resultVector < #move.axes }
    abort { "nxt-wcs-apply: Invalid probe result at index " ^ param.I }

var skewLimit = { exists(param.T) ? param.T : global.nxtProbeMaxSkewDeg }

var thetaDeg = { #var.resultVector > #move.axes ? var.resultVector[#move.axes] : 0 }

if { abs(var.thetaDeg) > var.skewLimit }
    abort { "nxt-wcs-apply: Probe rotation exceeds limit — square part or increase T" }

var wcsNumber = { param.W }

; Legacy G10 L2: feature M5000 coords as stored (no tools[].offsets subtract)
var offsetX = { exists(param.X) ? var.resultVector[0] : null }
var offsetY = { exists(param.Y) ? var.resultVector[1] : null }
var offsetZ = { exists(param.Z) ? var.resultVector[2] : null }
var offsetA = null
if { exists(param.A) && #var.resultVector > 3 }
    set var.offsetA = { var.resultVector[3] }

; Empty table is vector(..., 0). 0,0 is legal only if already near origin.
var nxtBothXY = { var.offsetX != null && var.offsetY != null }
var nxtOxZ = { var.offsetX != null && abs(var.offsetX) < 0.01 }
var nxtOyZ = { var.offsetY != null && abs(var.offsetY) < 0.01 }
var nxtMxPre = { move.axes[0].machinePosition }
var nxtMyPre = { move.axes[1].machinePosition }
var nxtMachFar = { abs(var.nxtMxPre) > 5 || abs(var.nxtMyPre) > 5 }
var nxtReject00 = { var.nxtBothXY && var.nxtOxZ && var.nxtOyZ && var.nxtMachFar }
if { var.nxtReject00 }
    abort { "nxt-wcs-apply: XY origin is 0,0 but machine is not at origin" }

; Idle before G10 so a leftover interpolator cannot run under the new origin
M400

if { var.offsetX != null && var.offsetY != null && var.offsetZ != null && var.offsetA != null }
    G10 L2 P{var.wcsNumber} X{var.offsetX} Y{var.offsetY} Z{var.offsetZ} A{var.offsetA}
elif { var.offsetX != null && var.offsetY != null && var.offsetZ != null }
    G10 L2 P{var.wcsNumber} X{var.offsetX} Y{var.offsetY} Z{var.offsetZ}
elif { var.offsetX != null && var.offsetY != null && var.offsetA != null }
    G10 L2 P{var.wcsNumber} X{var.offsetX} Y{var.offsetY} A{var.offsetA}
elif { var.offsetX != null && var.offsetZ != null && var.offsetA != null }
    G10 L2 P{var.wcsNumber} X{var.offsetX} Z{var.offsetZ} A{var.offsetA}
elif { var.offsetY != null && var.offsetZ != null && var.offsetA != null }
    G10 L2 P{var.wcsNumber} Y{var.offsetY} Z{var.offsetZ} A{var.offsetA}
elif { var.offsetX != null && var.offsetY != null }
    G10 L2 P{var.wcsNumber} X{var.offsetX} Y{var.offsetY}
elif { var.offsetX != null && var.offsetZ != null }
    G10 L2 P{var.wcsNumber} X{var.offsetX} Z{var.offsetZ}
elif { var.offsetX != null && var.offsetA != null }
    G10 L2 P{var.wcsNumber} X{var.offsetX} A{var.offsetA}
elif { var.offsetY != null && var.offsetZ != null }
    G10 L2 P{var.wcsNumber} Y{var.offsetY} Z{var.offsetZ}
elif { var.offsetY != null && var.offsetA != null }
    G10 L2 P{var.wcsNumber} Y{var.offsetY} A{var.offsetA}
elif { var.offsetZ != null && var.offsetA != null }
    G10 L2 P{var.wcsNumber} Z{var.offsetZ} A{var.offsetA}
elif { var.offsetX != null }
    G10 L2 P{var.wcsNumber} X{var.offsetX}
elif { var.offsetY != null }
    G10 L2 P{var.wcsNumber} Y{var.offsetY}
elif { var.offsetZ != null }
    G10 L2 P{var.wcsNumber} Z{var.offsetZ}
elif { var.offsetA != null }
    G10 L2 P{var.wcsNumber} A{var.offsetA}

echo "nxt-wcs-apply: Set WCS G" ^ (53 + var.wcsNumber) ^ " from result " ^ param.I
if { var.offsetX != null }
    echo "nxt-wcs-apply:   X origin = " ^ var.offsetX
if { var.offsetY != null }
    echo "nxt-wcs-apply:   Y origin = " ^ var.offsetY
if { var.offsetZ != null }
    echo "nxt-wcs-apply:   Z origin = " ^ var.offsetZ
if { var.offsetA != null }
    echo "nxt-wcs-apply:   A origin = " ^ var.offsetA

var nxtWpIdx = 0
var nxtHasSys = false
if { exists(move.motionSystems) }
    if { #move.motionSystems > 0 }
        set var.nxtHasSys = true
if { var.nxtHasSys }
    set var.nxtWpIdx = { move.motionSystems[0].workplaceNumber }

var nxtWpSel = { var.nxtWpIdx + 1 }
if { var.nxtWpSel != var.wcsNumber }
    M98 P"nxt-select-wcs.g" W{var.wcsNumber}

var nxtQPol = { 0 }
if { exists(param.Q) && param.Q != null }
    set var.nxtQPol = { param.Q }
if { !exists(global.nxtG68Policy) }
    global nxtG68Policy = { var.nxtQPol }
else
    set global.nxtG68Policy = { var.nxtQPol }
echo "nxt-wcs-apply: Armed job rotation policy Q" ^ var.nxtQPol

var workOffset = { var.wcsNumber - 1 }
var storeDeg = { exists(param.X) && exists(param.Y) }
if { var.storeDeg && exists(global.nxtWPDeg) }
    if { abs(var.thetaDeg) >= 0.0005 }
        set global.nxtWPDeg[var.workOffset] = { var.thetaDeg }
        echo "nxt-wcs-apply: Stored rotation " ^ var.thetaDeg ^ " deg for M5011"
    else
        set global.nxtWPDeg[var.workOffset] = { global.nxtDfltWPDeg }

; G69 + clear job G68 so setup jogging is unrotated. Job-start M5011 re-applies.
M98 P"nxt-job-g68-clear.g"

var nxtMx = { move.axes[0].machinePosition }
var nxtMy = { move.axes[1].machinePosition }
var nxtUx = { move.axes[0].userPosition }
var nxtUy = { move.axes[1].userPosition }
echo "nxt-wcs-apply: machine X=" ^ var.nxtMx ^ " Y=" ^ var.nxtMy
echo "nxt-wcs-apply: user X=" ^ var.nxtUx ^ " Y=" ^ var.nxtUy
if { var.offsetX != null }
    var nxtDx = { var.nxtMx - var.offsetX }
    echo "nxt-wcs-apply: origin X vs machine dX=" ^ var.nxtDx
if { var.offsetY != null }
    var nxtDy = { var.nxtMy - var.offsetY }
    echo "nxt-wcs-apply: origin Y vs machine dY=" ^ var.nxtDy
echo "nxt-wcs-apply: WCS updated; no travel (already parked)"

; Persist G10 L2 origins to SD (opt-out: set global.nxtAutoPersistWcs = false)
M98 P"nxt-user-wcs-sync.g"
M400
M98 P"nxt-g38-cancel.g"
