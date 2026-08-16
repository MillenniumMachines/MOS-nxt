; M5011.g: APPLY ROTATION COMPENSATION AT JOB START
;
; CAM posts call this on WCS change. Reads probed skew from nxtWPDeg
; and UI policy from nxtG68Policy (armed by M6520 / nxt-wcs-apply Q).
; Does not run after probing — setup jogging stays unrotated.
;
; USAGE: M5011 [W<workOffset>]
;   W: optional 0-indexed workplace (default: current workplace)

if { !inputs[state.thisInput].active }
    M99

var nxtWMax = { limits.workplaces - 1 }
if { exists(param.W) && param.W != null && (param.W < 0 || param.W > var.nxtWMax) }
    abort { "M5011: Work Offset W must be between 0 and " ^ var.nxtWMax }

; RRF 3.7+: prefer motionSystems[0].workplaceNumber (move.workplaceNumber is obsolete).
var workOffset = 0
var nxtHasSys = false
if { exists(move.motionSystems) }
    if { #move.motionSystems > 0 }
        set var.nxtHasSys = true
if { var.nxtHasSys }
    set var.workOffset = { move.motionSystems[0].workplaceNumber }
if { exists(param.W) && param.W != null }
    set var.workOffset = { param.W }

var wcsNumber = { var.workOffset + 1 }

var thetaDeg = null
if { exists(global.nxtWPDeg) && global.nxtWPDeg != null }
    if { var.workOffset < #global.nxtWPDeg }
        set var.thetaDeg = { global.nxtWPDeg[var.workOffset] }

var qPolicy = 0
if { exists(global.nxtG68Policy) && global.nxtG68Policy != null }
    set var.qPolicy = { global.nxtG68Policy }

var hasTheta = false
if { var.thetaDeg != null && abs(var.thetaDeg) >= 0.0005 }
    set var.hasTheta = true

var applyG68 = false

if { !var.hasTheta }
    echo "M5011: No probed rotation for G" ^ (53 + var.wcsNumber)
elif { var.qPolicy == 2 }
    echo "M5011: Skipping G68 (Q2 translation only)"
elif { var.qPolicy == 1 }
    set var.applyG68 = true
else
    var promptP = { "Probe skew: " ^ var.thetaDeg ^ " deg. Apply G68 to G" }
    set var.promptP = { var.promptP ^ (53 + var.wcsNumber) ^ "?" }
    M291 P{var.promptP} R"nxt: Rotation" S4 K{"Apply", "Skip"} F1
    if { input == 0 }
        set var.applyG68 = true

if { var.applyG68 }
    G17
    G69
    M98 P"nxt-select-wcs.g" W{var.wcsNumber}
    G68 X0 Y0 R{var.thetaDeg}
    set global.nxtJobG68Deg = { var.thetaDeg }
    set global.nxtJobG68Wcs = { var.wcsNumber }
    echo "M5011: G68 rotation applied R" ^ var.thetaDeg ^ " deg"
    M99

G69
if { exists(global.nxtJobG68Deg) }
    set global.nxtJobG68Deg = null
if { exists(global.nxtJobG68Wcs) }
    set global.nxtJobG68Wcs = null
