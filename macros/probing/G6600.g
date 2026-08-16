; G6600.g: WORKPIECE PROBING GATEWAY (CAM post-processor)
;
; Pauses CAM setup for operator WCS probing. W is 0-indexed (W0=G54). Omit W = current workplace.
; If live G10 L2 XYZ look set: Use existing / Reprobe / Cancel (no tip wait).
; Probe tool-ready runs only on the vise-corner path.
;
; USAGE: G6600 [W<0..8>]

if { !inputs[state.thisInput].active }
    M99

if { !global.nxtFeatureTouchProbe }
    abort { "G6600: Touch probe feature not enabled" }

if { global.nxtTouchProbeID == null }
    abort { "G6600: nxtTouchProbeID not configured" }

; RRF 3.7+: prefer motionSystems[0].workplaceNumber (move.workplaceNumber is obsolete).
var wcsNum = 1
if { exists(move.motionSystems) && #move.motionSystems > 0 }
    set var.wcsNum = { move.motionSystems[0].workplaceNumber + 1 }
if { exists(param.W) && param.W != null }
    if { param.W < 0 || param.W > 8 }
        abort { "G6600: W must be 0-8 (G54..G59.3)" }
    set var.wcsNum = { param.W + 1 }

var wcsG = { 53 + var.wcsNum }
var wpIdx = { var.wcsNum - 1 }
echo "G6600: Workpiece probing for WCS G" ^ var.wcsG

var offX = null
var offY = null
var offZ = null
if { #move.axes >= 3 }
    if { var.wpIdx < #move.axes[0].workplaceOffsets }
        set var.offX = { move.axes[0].workplaceOffsets[var.wpIdx] }
    if { var.wpIdx < #move.axes[1].workplaceOffsets }
        set var.offY = { move.axes[1].workplaceOffsets[var.wpIdx] }
    if { var.wpIdx < #move.axes[2].workplaceOffsets }
        set var.offZ = { move.axes[2].workplaceOffsets[var.wpIdx] }

var xyzSet = false
if { var.offX != null && var.offY != null && var.offZ != null }
    var near0X = { abs(var.offX) < 0.01 }
    var near0Y = { abs(var.offY) < 0.01 }
    var near0Z = { abs(var.offZ) < 0.01 }
    var allZero = { var.near0X && var.near0Y && var.near0Z }
    if { !var.allZero }
        set var.xyzSet = true

if { var.xyzSet }
    var keepMsgA = { "WCS G" ^ var.wcsG ^ " already has XY and Z origins. " }
    var keepMsgB = { var.keepMsgA ^ "Use them, reprobe, or cancel." }
    M291 P{var.keepMsgB} R"Workpiece WCS" S4 K{"Use existing","Reprobe","Cancel"} F0
    if { input == 2 }
        abort { "G6600: Workpiece probing cancelled" }
    if { input == 0 }
        echo "G6600: Using existing WCS G" ^ var.wcsG ^ " origins"
        M99

var menuMsgA = { "Probe WCS G" ^ var.wcsG ^ ". Vise corner runs G6520 here; " }
var menuMsgB = { var.menuMsgA ^ "bore/rectangle use DWC Probing Cycles." }
M291 P{var.menuMsgB} R"Workpiece probe" S4 K{"Vise corner","DWC panel done","Skip","Cancel"} F0
if { input == 3 }
    abort { "G6600: Workpiece probing cancelled" }
if { input == 2 }
    echo "G6600: Skipped — ensure WCS G" ^ var.wcsG ^ " is set before cutting"
    M99
if { input == 1 }
    echo "G6600: Continuing after DWC probing"
    M99

M98 P"nxt-probe-tool-ready.g"

var nxtJogMsgA = "Please jog the probe <b>OVER</b> the vise corner at probe height and press <b>OK</b>.<br/>"
var nxtJogMsgB = { var.nxtJogMsgA ^ "<b>CAUTION</b>: That height is the start Z; L dives relative to it." }
M291 P{var.nxtJogMsgB} R"Workpiece probe" X1 Y1 Z1 J1 T0 S3
if { result != 0 }
    abort { "G6600: Vise corner probing cancelled" }

if { !exists(global.nxtCornerNames) }
    abort { "G6600: nxtCornerNames not configured" }

M291 P"Select the corner under the probe." R"Vise corner" S4 K{global.nxtCornerNames} F0
if { result != 0 }
    abort { "G6600: Vise corner probing cancelled" }
var cnr = { input }
if { var.cnr < 0 || var.cnr > 3 }
    abort { "G6600: Corner N must be 0-3" }

var defH = 100
var defI = 100
if { exists(global.nxtWPDims) && global.nxtWPDims != null }
    if { var.wpIdx < #global.nxtWPDims }
        if { global.nxtWPDims[var.wpIdx] != null }
            if { global.nxtWPDims[var.wpIdx][1] != null }
                set var.defH = { global.nxtWPDims[var.wpIdx][1] }
            if { global.nxtWPDims[var.wpIdx][0] != null }
                set var.defI = { global.nxtWPDims[var.wpIdx][0] }

var hMsg = "Approximate X-face length along Y (mm)."
M291 P{var.hMsg} R"Vise corner" J1 T0 S6 F{var.defH}
if { result != 0 }
    abort { "G6600: Vise corner probing cancelled" }
var faceH = { input }
if { var.faceH <= 0 }
    abort { "G6600: Face length H must be positive" }

var iMsg = "Approximate Y-face length along X (mm)."
M291 P{var.iMsg} R"Vise corner" J1 T0 S6 F{var.defI}
if { result != 0 }
    abort { "G6600: Vise corner probing cancelled" }
var faceI = { input }
if { var.faceI <= 0 }
    abort { "G6600: Face length I must be positive" }

var depth = 10.0
echo "G6600: Running G6520 vise corner U" ^ var.wcsNum ^ " N" ^ var.cnr
G6520 U{var.wcsNum} N{var.cnr} L{var.depth} H{var.faceH} I{var.faceI}

echo "G6600: WCS G" ^ var.wcsG ^ " probing complete"
