; G6505-jog.g: PROBE WORK PIECE - POCKET
;
; Meta macro to gather operator input before executing a
; pocket probe cycle (G6505.1).
; The macro will explain to the operator what is about to
; happen and ask for an approximate length and width of
; the pocket. The macro will then ask the operator to jog
; the probe over the approximate center of the pocket, and
; enter a probe depth. These values will then be passed
; to the underlying G6505.1 macro to execute the probe cycle.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Display description of pocket probe if not already displayed this session
if { global.nxtTutorialMode && !global.nxtDialogDisplayed[6] }
    var nxtM291Msg1 = "This probe cycle finds the X or Y co-ordinates of the midpoint of a pocket (recessed feature) on a workpiece by probing towards the pocket surfaces from the midpoint."
    M291 P{var.nxtM291Msg1} R"nxt: Probe Pocket " T0 S2
    M291 P"You will be asked to enter an approximate <b>width</b> and optionally <b>length</b> of the pocket, and a <b>clearance distance</b>." R"nxt: Probe Pocket" T0 S2
    M291 P"These define how far the probe will move away from the center point before starting to probe towards the relevant surfaces." R"nxt: Probe Pocket" T0 S2
    var nxtM291Msg2a = "You will then jog the tool over the approximate midpoint of the pocket.<br/>"
    var nxtM291Msg2b = { var.nxtM291Msg2a ^ "<b>CAUTION</b>: Jogging in RRF does not watch the probe status, so you could cause damage if moving in the wrong direction!" }
    M291 P{var.nxtM291Msg2b} R"nxt: Probe Pocket" T0 S2
    M291 P"Finally, you will be asked for a <b>probe depth</b>. This is how far the probe will move downwards into the pocket before probing the surfaces." R"nxt: Probe Pocket" T0 S2
    var nxtM291Msg3 = "If you are still unsure, you can <a target=""_blank"" href=""https://mos.diycnc.xyz/usage/pocket-xy"">View the Pocket Documentation</a> for more details."
    M291 P{var.nxtM291Msg3} R"nxt: Probe Pocket" T0 S4 K{"Continue", "Cancel"} F0
    if { input != 0 }
        abort { "Pocket probe aborted!" }
    set global.nxtDialogDisplayed[6] = true

; Make sure probe tool is selected
if { global.nxtProbeToolID != state.currentTool }
    T T{global.nxtProbeToolID}

; Default workOffset to the current workplace number if not specified
; with the W parameter.
var workOffset = { (exists(param.W) && param.W != null) ? param.W : move.workplaceNumber }


; WCS Numbers and Offsets are confusing. Work Offset indicates the offset
; from the first work co-ordinate system, so is 0-indexed. WCS number indicates
; the number of the work co-ordinate system, so is 1-indexed.
var wcsNumber = { var.workOffset + 1 }

var nxtM291Msg4 = {"Please select the probing mode to use.<br/><b>Full</b> will probe 2 points on each surface of the pocket, while <b>Quick</b> will probe only 1 point."}
M291 P{var.nxtM291Msg4} R"nxt: Pocket" J2 T0 S4 K{"Full","Quick"} F0
if { result != 0 }
    abort { "Pocket probe aborted!" }

var mode = { input }

var nxtPktOrientA = "Please select the orientation of the pocket.<br/><b>X</b> probes 2 surfaces forming the pocket perpendicular to the X axis, "
var nxtPktOrientB = { var.nxtPktOrientA ^ "<b>Y</b> probes 2 surfaces perpendicular to the Y axis." }
M291 P{var.nxtPktOrientB} R"nxt: Pocket" J2 T0 S4 K{"X","Y"}
if { result != 0 }
    abort { "Pocket probe aborted!" }

var axis = { input }
var pocketLetter = { (var.axis == 0) ? "X" : "Y" }
var lengthLetter = { (var.axis == 0) ? "Y" : "X" }

var bW = { (global.nxtWPDims[var.workOffset][0] != null) ? global.nxtWPDims[var.workOffset][0] : 100 }

M291 P{"Please enter approximate <b>pocket width</b> in mm.<br/><b>NOTE</b>: <b>Width</b> is measured along the <b>" ^ var.pocketLetter ^ " axis."} R"nxt: Probe Pocket" J1 T0 S6 F{var.bW}
if { result != 0 }
    abort { "Pocket probe aborted!" }

var pocketWidth = { input }

if { var.pocketWidth < 1 }
    abort { "Pocket width too low!" }

var pocketLength = { null }

; 0 = Full mode, 1 = Quick mode
; Only prompt for length if in full mode
if { var.mode == 0 }
    var bL = { (global.nxtWPDims[var.workOffset][1] != null) ? global.nxtWPDims[var.workOffset][1] : 100 }

    M291 P{"Please enter approximate <b>pocket length</b> in mm.<br/><b>NOTE</b>: <b>Length</b> is measured along the <b>" ^ var.lengthLetter ^ "</b> axis."} R"nxt: Probe Pocket" J1 T0 S6 F{var.bL}
    if { result != 0 }
        abort { "Pocket probe aborted!" }

    set var.pocketLength = { input }

    if { var.pocketLength < 1 }
        abort { "Pocket length too low!" }

; Prompt for clearance distance
var nxtM291Msg6 = "Please enter <b>clearance</b> distance in mm.<br/>This is how far away from the expected surfaces and corners we probe from, to account for any innaccuracy in the start position."
M291 P{var.nxtM291Msg6} R"nxt: Probe Pocket" J1 T0 S6 F{global.nxtClearance}
if { result != 0 }
    abort { "Pocket probe aborted!" }

var surfaceClearance = { input }

if { var.surfaceClearance <= 0.1 }
    abort { "Clearance distance too low!" }

var edgeClearance = null

; 0 = Full mode, 1 = Quick mode
; Only check for edge clearance if in full mode
if { var.mode == 0 }
    ; Calculate the maximum clearance distance we can use before
    ; the probe points will be flipped
    var mC = { min(var.pocketWidth, var.pocketLength) / 2 }

    if { var.surfaceClearance >= var.mC }
        var defCC = { max(1, var.mC-1) }
        var nxtM291Msg7 = {"The <b>clearance</b> distance is more than half of the length of the pocket.<br/>Please enter an <b>edge clearance</b> distance less than <b>" ^ var.mC ^ "</b>."}
        M291 P{var.nxtM291Msg7} R"nxt: Probe Pocket" J1 T0 S6 F{var.defCC}
        set var.edgeClearance = { input }
        if { var.edgeClearance >= var.mC }
            abort { "Edge clearance distance too high!" }

; Prompt for overtravel distance
var nxtM291Msg8 = "Please enter <b>overtravel</b> distance in mm.<br/>This is how far we move past the expected surfaces to account for any innaccuracy in the dimensions."
M291 P{var.nxtM291Msg8} R"nxt: Probe Pocket" J1 T0 S6 F{global.nxtOvertravel}
if { result != 0 }
    abort { "Pocket probe aborted!" }

var overtravel = { input }
if { var.overtravel < 0.1 }
    abort { "Overtravel distance too low!" }

var nxtM291Msg9a = "Please jog the probe <b>OVER</b> the approximate midpoint of the pocket and press <b>OK</b>.<br/>"
var nxtM291Msg9b = { var.nxtM291Msg9a ^ "<b>CAUTION</b>: The chosen height of the probe is assumed to be safe for horizontal moves!" }
M291 P{var.nxtM291Msg9b} R"nxt: Probe Pocket" X1 Y1 Z1 J1 T0 S3
if { result != 0 }
    abort { "Pocket probe aborted!" }

var nxtM291Msg10 = "Please enter the depth to probe at in mm, relative to the current location. A value of 10 will move the probe downwards 10mm before probing inwards."
M291 P{var.nxtM291Msg10} R"nxt: Probe Pocket" J1 T0 S6 F{global.nxtOvertravel}
if { result != 0 }
    abort { "Pocket probe aborted!" }

var probingDepth = { input }

if { var.probingDepth < 0 }
    abort { "Probing depth was negative!" }

; Run the pocket probe cycle
if { global.nxtTutorialMode }
    M291 P{"Probe will now move outside each surface and down by " ^ var.probingDepth ^ "mm, before probing towards the midpoint."} R"nxt: Probe Pocket" T0 S4 K{"Continue", "Cancel"} F0
    if { input != 0 }
        abort { "Pocket probe aborted!" }

; Get current machine position
M5000 P0

var nxtJogJ = { global.nxtAbsPos[0] }
var nxtJogK = { global.nxtAbsPos[1] }
var nxtJogL = { global.nxtAbsPos[2] }
var nxtJogZ = { global.nxtAbsPos[2] - var.probingDepth }
var nxtSC = { var.surfaceClearance }
var nxtEC = { var.edgeClearance }
var nxtOTv = { var.overtravel }
G6505.1 W{var.workOffset} Q{var.mode} N{var.axis} H{var.pocketWidth} I{var.pocketLength} T{var.nxtSC} C{var.nxtEC} O{var.nxtOTv} J{var.nxtJogJ} K{var.nxtJogK} L{var.nxtJogL} Z{var.nxtJogZ}
