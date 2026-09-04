; M6520.g: SET WCS OFFSET FROM PROBE RESULT
;
; Sets a Work Coordinate System origin from the probe results table.
; G10 L2: X/Y = tip M5000; Z slot = tool-normalized surface (G6512 hit − L1).
; Never G10 L20. After G10 + WCS select, G53 G1 flagged X/Y to stored L2 machine coords
; (Z/A pinned from current pose). A1 touches off live rotary pose (G10 L2 A
; = current machine A so work A reads 0). Never work G0 X0 Y0.
; Does not apply G68 — that is M5011 at job start. Q only arms policy.
;
; USAGE: M6520 P<resultIndex> W<wcsNumber> [X1] [Y1] [Z1] [A1] [Q<mode>] [T<maxSkew>]
;
; Parameters:
;   P: Probe results table index (0-9) - REQUIRED
;   W: WCS number (1-9 for G54-G59.3) - REQUIRED
;   X1/Y1/Z1: Axis presence flags (RRF needs letter+number; value ignored)
;       Bare X/Y/Z/A often do NOT populate exists(param.X) — use X1 not X
;   A1: Touch off current homed machine A (not probe-table slot 3)
;   Q: Job-start rotation policy for M5011 (not applied here):
;      0 — prompt (M291) when the job calls M5011 (default if Q omitted)
;      1 — apply G68 at M5011 without prompt
;      2 — translation only; M5011 will not apply G68
;   T: Optional override for max |skew| allowed (deg); default global.nxtProbeMaxSkewDeg
;
; XY apply stores theta in nxtWPDeg[W-1] for M5011. Always G69 after G10/park.
; Z in nxtProbeResults is L2-ready (G6512 subtracts L1 at capture; no tip R / Z D).
;
; At least one axis flag (X, Y, Z, or A) must be specified.

if { !inputs[state.thisInput].active }
    M99

if { !exists(param.P) || param.P == null || param.P < 0 }
    abort { "M6520: Result index parameter P is required and must be >= 0" }

if { param.P >= #global.nxtProbeResults }
    abort { "M6520: Result index P=" ^ param.P ^ " exceeds table size (" ^ #global.nxtProbeResults ^ ")" }

if { !exists(param.W) || param.W == null || param.W < 1 || param.W > 9 }
    abort { "M6520: WCS number W is required and must be 1-9 (for G54-G59.3)" }

if { !exists(param.X) && !exists(param.Y) && !exists(param.Z) && !exists(param.A) }
    abort { "M6520: At least one axis flag (X, Y, Z, or A) must be specified" }

if { global.nxtProbeResults[param.P] == null }
    abort { "M6520: No probe result found at index " ^ param.P }

var resultVector = { global.nxtProbeResults[param.P] }

if { #var.resultVector < #move.axes }
    abort { "M6520: Invalid probe result at index " ^ param.P }

var skewLimit = { exists(param.T) ? param.T : global.nxtProbeMaxSkewDeg }

var thetaDeg = { #var.resultVector > #move.axes ? var.resultVector[#move.axes] : 0 }

if { abs(var.thetaDeg) > var.skewLimit }
    abort { "M6520: Probe rotation " ^ var.thetaDeg ^ " deg exceeds limit " ^ var.skewLimit ^ " — square the part or increase T / nxtProbeMaxSkewDeg" }

var wcsNumber = { param.W }

; G10 L2: X/Y = tip M5000 from table; Z = tool-normalized (G6512 capture).
; A1 = touch off current rotary pose (not result slot 3, which XY cycles leave 0).
var offsetX = { exists(param.X) ? var.resultVector[0] : null }
var offsetY = { exists(param.Y) ? var.resultVector[1] : null }
var offsetZ = { exists(param.Z) ? var.resultVector[2] : null }
var offsetA = null
var nxtHasA = { #move.axes > 3 }
var nxtAHomed = false
if { var.nxtHasA }
    set var.nxtAHomed = { move.axes[3].homed }
if { exists(param.A) }
    if { !var.nxtHasA }
        abort { "M6520: A flag requires a mapped A axis" }
    if { !var.nxtAHomed }
        abort { "M6520: Homing A is required to touch off WCS A" }
    set var.offsetA = { move.axes[3].machinePosition }

; Empty table is vector(..., 0). 0,0 is legal only if already near machine origin.
var nxtBothXY = { var.offsetX != null && var.offsetY != null }
var nxtOxZ = { var.offsetX != null && abs(var.offsetX) < 0.01 }
var nxtOyZ = { var.offsetY != null && abs(var.offsetY) < 0.01 }
var nxtMxPre = { move.axes[0].machinePosition }
var nxtMyPre = { move.axes[1].machinePosition }
var nxtMachFar = { abs(var.nxtMxPre) > 5 || abs(var.nxtMyPre) > 5 }
var nxtReject00 = { var.nxtBothXY && var.nxtOxZ && var.nxtOyZ && var.nxtMachFar }
if { var.nxtReject00 }
    abort { "M6520: XY origin is 0,0 but machine is not at origin — empty result?" }

; Idle before G10 so a leftover interpolator cannot run under the new origin
if { !exists(global.nxtWcsG10X) }
    global nxtWcsG10X = null
if { !exists(global.nxtWcsG10Y) }
    global nxtWcsG10Y = null
if { !exists(global.nxtWcsG10Z) }
    global nxtWcsG10Z = null
if { !exists(global.nxtWcsG10A) }
    global nxtWcsG10A = null
set global.nxtWcsG10X = { var.offsetX }
set global.nxtWcsG10Y = { var.offsetY }
set global.nxtWcsG10Z = { var.offsetZ }
set global.nxtWcsG10A = { var.offsetA }
M98 P"nxt-wcs-g10-apply.g" W{var.wcsNumber}

echo "M6520: Set WCS G" ^ (53 + var.wcsNumber) ^ " origin from probe result " ^ param.P
if { var.offsetX != null }
    echo "M6520:   X origin = " ^ var.offsetX
if { var.offsetY != null }
    echo "M6520:   Y origin = " ^ var.offsetY
if { var.offsetZ != null }
    echo "M6520:   Z origin = " ^ var.offsetZ
if { var.offsetA != null }
    echo "M6520:   A origin = " ^ var.offsetA

M98 P"nxt-select-wcs.g" W{var.wcsNumber}

var nxtQPol = { 0 }
if { exists(param.Q) && param.Q != null }
    set var.nxtQPol = { param.Q }
if { !exists(global.nxtG68Policy) }
    global nxtG68Policy = { var.nxtQPol }
else
    set global.nxtG68Policy = { var.nxtQPol }
echo "M6520: Armed job rotation policy Q" ^ var.nxtQPol

var workOffset = { var.wcsNumber - 1 }
var storeDeg = { exists(param.X) && exists(param.Y) }
if { var.storeDeg && exists(global.nxtWPDeg) }
    if { abs(var.thetaDeg) >= 0.0005 }
        set global.nxtWPDeg[var.workOffset] = { var.thetaDeg }
        echo "M6520: Stored rotation " ^ var.thetaDeg ^ " deg for M5011"
    else
        set global.nxtWPDeg[var.workOffset] = { global.nxtDfltWPDeg }

; G53 G1 to stored L2 XY (never work G0 — G53 leak → machine 0,0)
G90
M400
var parkFeed = { 3000 }
var parkPid = { global.nxtTouchProbeID }
if { var.parkPid != null && sensors.probes[var.parkPid] != null }
    set var.parkFeed = { sensors.probes[var.parkPid].travelSpeed }
var pinX = { move.axes[0].machinePosition }
var pinY = { move.axes[1].machinePosition }
var pinZ = { move.axes[2].machinePosition }
var pinA = { 0 }
var parkHasA = { #move.axes > 3 }
if { var.parkHasA }
    set var.pinA = { move.axes[3].machinePosition }
var parkX = { var.offsetX != null ? var.offsetX : var.pinX }
var parkY = { var.offsetY != null ? var.offsetY : var.pinY }
if { var.offsetX != null || var.offsetY != null }
    if { var.parkHasA }
        G53 G1 F{var.parkFeed} X{var.parkX} Y{var.parkY} Z{var.pinZ} A{var.pinA}
    else
        G53 G1 F{var.parkFeed} X{var.parkX} Y{var.parkY} Z{var.pinZ}
    M400

; G69 + clear job G68 so setup jogging is unrotated. Job-start M5011 re-applies.
M98 P"nxt-job-g68-clear.g"

var nxtMx = { move.axes[0].machinePosition }
var nxtMy = { move.axes[1].machinePosition }
var nxtUx = { move.axes[0].userPosition }
var nxtUy = { move.axes[1].userPosition }
echo "M6520: machine X=" ^ var.nxtMx ^ " Y=" ^ var.nxtMy
echo "M6520: user X=" ^ var.nxtUx ^ " Y=" ^ var.nxtUy
if { var.offsetX != null }
    var nxtDx = { var.nxtMx - var.offsetX }
    echo "M6520: origin X vs machine dX=" ^ var.nxtDx
if { var.offsetY != null }
    var nxtDy = { var.nxtMy - var.offsetY }
    echo "M6520: origin Y vs machine dY=" ^ var.nxtDy
echo "M6520: WCS updated; G53 G1 flagged XY (Z stays startZ)"

; Persist G10 L2 origins to SD (opt-out: set global.nxtAutoPersistWcs = false)
M98 P"nxt-user-wcs-sync.g"
M400
M98 P"nxt-g38-cancel.g"
