; G6503.1.g: GUIDED RECTANGLE BLOCK PROBE
;
; Meta macro to gather operator input, then run modern G6503
; (3-pt perimeter external block → nxtProbeResults + M6520 via U).

if { !inputs[state.thisInput].active }
    M99

if { global.nxtTutorialMode && !global.nxtDialogDisplayed[5] }
    var nxtM291Msg1a = "This probe cycle finds the X and Y co-ordinates of the center of a rectangular block "
    var nxtM291Msg1b = { var.nxtM291Msg1a ^ "by probing 3 points on each of 4 faces (CCW perimeter)." }
    M291 P{var.nxtM291Msg1b} R"nxt: Probe Rect. Block " T0 S2
    M291 P"You will enter approximate <b>width</b>, <b>length</b>, <b>clearance</b>, and edge inset." R"nxt: Probe Rect. Block" T0 S2
    M291 P"Clearance is how far outside the faces we start (default 5). Edge inset is corner clearance for outer points (default 10)." R"nxt: Probe Rect. Block" T0 S2
    var nxtM291Msg2a = "You will then jog the tool over the approximate center of the block.<br/>"
    var nxtM291Msg2b = { var.nxtM291Msg2a ^ "<b>CAUTION</b>: Jogging in RRF does not watch the probe status!" }
    M291 P{var.nxtM291Msg2b} R"nxt: Probe Rect. Block" T0 S2
    M291 P"Finally, enter a <b>probe depth</b> (how far down from safe Z before side probes)." R"nxt: Probe Rect. Block" T0 S2
    var nxtM291Msg3 = "If you are still unsure, you can <a target=""_blank"" href=""https://mos.diycnc.xyz/usage/rectangle-block"">View the Rectangle Block Documentation</a> for more details."
    M291 P{var.nxtM291Msg3} R"nxt: Probe Rect. Block" T0 S4 K{"Continue", "Cancel"} F0
    if { input != 0 }
        abort { "Rectangle block probe aborted!" }
    set global.nxtDialogDisplayed[5] = true

if { global.nxtProbeToolID != state.currentTool }
    T T{global.nxtProbeToolID}

var workOffset = { move.motionSystems[0].workplaceNumber }
if { exists(param.W) && param.W != null }
    set var.workOffset = { param.W }
var wcsNumber = { var.workOffset + 1 }

var bW = { 100 }
if { exists(global.nxtWPDims) && global.nxtWPDims != null }
    if { var.workOffset < #global.nxtWPDims }
        if { global.nxtWPDims[var.workOffset] != null && global.nxtWPDims[var.workOffset][0] != null }
            set var.bW = { global.nxtWPDims[var.workOffset][0] }

M291 P{"Please enter approximate <b>block width</b> in mm.<br/><b>NOTE</b>: <b>Width</b> is measured along the <b>X</b> axis."} R"nxt: Probe Rect. Block" J1 T0 S6 F{var.bW}
if { result != 0 }
    abort { "Rectangle block probe aborted!" }

var blockWidth = { input }

if { var.blockWidth < 1 }
    abort { "Block width too low!" }

var bL = { 100 }
if { exists(global.nxtWPDims) && global.nxtWPDims != null }
    if { var.workOffset < #global.nxtWPDims }
        if { global.nxtWPDims[var.workOffset] != null && global.nxtWPDims[var.workOffset][1] != null }
            set var.bL = { global.nxtWPDims[var.workOffset][1] }

M291 P{"Please enter approximate <b>block length</b> in mm.<br/><b>NOTE</b>: <b>Length</b> is measured along the <b>Y</b> axis."} R"nxt: Probe Rect. Block" J1 T0 S6 F{var.bL}
if { result != 0 }
    abort { "Rectangle block probe aborted!" }

var blockLength = { input }

if { var.blockLength < 1 }
    abort { "Block length too low!" }

var nxtM291Msg4 = "Please enter <b>clearance</b> distance in mm (outside each face before diving)."
M291 P{var.nxtM291Msg4} R"nxt: Probe Rect. Block" J1 T0 S6 F{global.nxtClearance}
if { result != 0 }
    abort { "Rectangle block probe aborted!" }

var surfaceClearance = { input }

if { var.surfaceClearance <= 0.1 }
    abort { "Clearance distance too low!" }

var mC = { min(var.blockWidth, var.blockLength) / 2 }
var edgeInset = { 10 }
if { var.edgeInset >= var.mC }
    set var.edgeInset = { max(1, var.mC - 1) }

var nxtM291Msg5a = "Edge inset for outer face points (mm). Must be less than half the "
var nxtM291Msg5b = { var.nxtM291Msg5a ^ "shorter side (" ^ var.mC ^ " mm)." }
M291 P{var.nxtM291Msg5b} R"nxt: Probe Rect. Block" J1 T0 S6 F{var.edgeInset}
if { result != 0 }
    abort { "Rectangle block probe aborted!" }
set var.edgeInset = { input }
if { var.edgeInset <= 0 || var.edgeInset >= var.mC }
    abort { "Edge inset invalid (must be > 0 and < half min side)!" }

var nxtM291Msg6 = "Please enter <b>overtravel</b> distance in mm (past expected face into the block)."
M291 P{var.nxtM291Msg6} R"nxt: Probe Rect. Block" J1 T0 S6 F{global.nxtOvertravel}
if { result != 0 }
    abort { "Rectangle block probe aborted!" }

var overtravel = { input }
if { var.overtravel < 0.1 }
    abort { "Overtravel distance too low!" }

var nxtM291Msg7a = "Please jog the probe <b>OVER</b> the center of the rectangle block and press <b>OK</b>.<br/>"
var nxtM291Msg7b = { var.nxtM291Msg7a ^ "<b>CAUTION</b>: The chosen height of the probe is assumed to be safe for horizontal moves!" }
M291 P{var.nxtM291Msg7b} R"nxt: Probe Rect. Block" X1 Y1 Z1 J1 T0 S3
if { result != 0 }
    abort { "Rectangle block probe aborted!" }

var nxtM291Msg8 = "Please enter the depth to probe at in mm, relative to the current location. A value of 10 will move the probe downwards 10mm before probing inwards."
M291 P{var.nxtM291Msg8} R"nxt: Probe Rect. Block" J1 T0 S6 F{global.nxtOvertravel}
if { result != 0 }
    abort { "Rectangle block probe aborted!" }

var probingDepth = { input }

if { var.probingDepth < 0 }
    abort { "Probing depth was negative!" }

if { global.nxtTutorialMode }
    var tutA = "Probe will run a 3-pt CCW perimeter, dive "
    var tutB = { var.tutA ^ var.probingDepth ^ "mm per face, raise only between faces." }
    M291 P{var.tutB} R"nxt: Probe Rect. Block" T0 S4 K{"Continue", "Cancel"} F0
    if { input != 0 }
        abort { "Rectangle block probe aborted!" }

; Operator is already at approx center — G6503 uses current XY as assumed center
G6503 U{var.wcsNumber} W{var.blockWidth} H{var.blockLength} L{var.probingDepth} C{var.surfaceClearance} O{var.overtravel} E{var.edgeInset}
