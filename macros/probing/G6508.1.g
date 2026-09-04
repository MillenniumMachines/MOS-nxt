; G6508.1.g: GUIDED OUTSIDE CORNER PROBE
;
; Meta macro to gather operator input, then run modern G6508
; (adaptive corner faces → nxtProbeResults + M6520 via U).

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Display description of rectangle block probe if not already displayed this session
if { global.nxtTutorialMode && !global.nxtDialogDisplayed[10] }
    M291 P"This probe cycle finds the X and Y co-ordinates of the corner of a rectangular workpiece by probing along the 2 edges that form the corner." R"nxt: Probe Outside Corner " T0 S2
    var nxtM291Msg1 = "In <b>Full</b> mode, this cycle will take 2 probe points on each edge, allowing us to calculate the position and angle of the corner and the rotation of the workpiece."
    M291 P{var.nxtM291Msg1} R"nxt: Probe Outside Corner" T0 S2
    M291 P"You will be asked to enter an approximate <b>surface length</b> for the surfaces forming the corner, to calculate the 4 probe locations." R"nxt: Probe Outside Corner" T0 S2
    var nxtM291Msg2a = "In <b>Quick</b> mode, this cycle will take 1 probe point on each edge, assuming the corner is square and the workpiece is aligned with the table, "
    var nxtM291Msg2b = { var.nxtM291Msg2a ^ "and will return the extrapolated position of the corner." }
    M291 P{var.nxtM291Msg2b} R"nxt: Probe Outside Corner" T0 S2
    M291 P"For both modes, you will be asked to enter a <b>clearance distance</b> and an <b>overtravel distance</b>." R"nxt: Probe Outside Corner" T0 S2
    var nxtM291Msg3a = "These define how far the probe will move along the surfaces from the corner location before probing, "
    var nxtM291Msg3b = { var.nxtM291Msg3a ^ "and how far past the expected surface the probe can move before erroring when not triggered." }
    M291 P{var.nxtM291Msg3b} R"nxt: Probe Outside Corner" T0 S2
    var nxtM291Msg4a = "You will then jog the tool over the corner to be probed.<br/>"
    var nxtM291Msg4b = { var.nxtM291Msg4a ^ "<b>CAUTION</b>: Jogging in RRF does not watch the probe status, so you could cause damage if moving in the wrong direction!" }
    M291 P{var.nxtM291Msg4b} R"nxt: Probe Outside Corner" T0 S2
    M291 P"Finally, you will be asked to select the corner that is being probed, and the depth below the top surface to probe the corner surfaces at, in mm." R"nxt: Probe Outside Corner" S2
    var nxtM291Msg5 = "If you are still unsure, you can <a target=""_blank"" href=""https://mos.diycnc.xyz/usage/outside-corner"">View the Outside Corner Documentation</a> for more details."
    M291 P{var.nxtM291Msg5} R"nxt: Probe Outside Corner" T0 S4 K{"Continue", "Cancel"} F0
    if { input != 0 }
        abort { "Outside corner probe aborted!" }
    set global.nxtDialogDisplayed[10] = true

; Make sure probe tool is selected
if { global.nxtProbeToolID != state.currentTool }
    T T{global.nxtProbeToolID}

var tR = { global.nxtTT[state.currentTool][0]}

; Default workOffset to the current workplace number if not specified
; with the W parameter.
var workOffset = { move.motionSystems[0].workplaceNumber }
if { exists(param.W) && param.W != null }
    set var.workOffset = { param.W }


; WCS Numbers and Offsets are confusing. Work Offset indicates the offset
; from the first work co-ordinate system, so is 0-indexed. WCS number indicates
; the number of the work co-ordinate system, so is 1-indexed.
var wcsNumber = { var.workOffset + 1 }

var nxtM291Msg6 = {"Please select the probing mode to use.<br/><b>Full</b> will probe 2 points on each horizontal surface, while <b>Quick</b> will probe only 1 point."}
M291 P{var.nxtM291Msg6} R"nxt: Probe Outside Corner" T0 S4 K{"Full","Quick"} F0
if { result != 0 }
    abort { "Outside corner probe aborted!" }

var mode = { input }

var xSL  = null
var ySL  = null

; 0 = Full mode, 1 = Quick mode
if { var.mode == 0 }
    var sW = { 100 }
    if { exists(global.nxtWPDims) && global.nxtWPDims != null }
        if { var.workOffset < #global.nxtWPDims }
            if { global.nxtWPDims[var.workOffset] != null && global.nxtWPDims[var.workOffset][0] != null }
                set var.sW = { global.nxtWPDims[var.workOffset][0] }
    var nxtM291Msg7 = {"Please enter approximate <b>surface length</b> along the X axis in mm.<br/><b>NOTE</b>: Along the X axis means the surface facing towards or directly away from the operator."}
    M291 P{var.nxtM291Msg7} R"nxt: Probe Outside Corner" J1 T0 S6 F{var.sW}
    if { result != 0 }
        abort { "Outside corner probe aborted!" }

    set var.xSL = { input }

    if { var.xSL < var.tR }
        abort { "X surface length too low. Cannot probe distances smaller than the tool radius (" ^ var.tR ^ ")!"}

    var sL = { 100 }
    if { exists(global.nxtWPDims) && global.nxtWPDims != null }
        if { var.workOffset < #global.nxtWPDims }
            if { global.nxtWPDims[var.workOffset] != null && global.nxtWPDims[var.workOffset][1] != null }
                set var.sL = { global.nxtWPDims[var.workOffset][1] }
    var nxtM291Msg8 = {"Please enter approximate <b>surface length</b> along the Y axis in mm.<br/><b>NOTE</b>: Along the Y axis means the surface to the left or the right of the operator."}
    M291 P{var.nxtM291Msg8} R"nxt: Probe Outside Corner" J1 T0 S6 F{var.sL}
    if { result != 0 }
        abort { "Outside corner probe aborted!" }

    set var.ySL = { input }

    if { var.ySL < var.tR }
        abort { "Y surface length too low. Cannot probe distances smaller than the tool radius (" ^ var.tR ^ ")!"}

; Prompt for clearance distance
var nxtM291Msg9 = "Please enter <b>clearance</b> distance in mm.<br/>This is how far away from the expected surfaces and corners we probe from, to account for any innaccuracy in the start position."
M291 P{var.nxtM291Msg9} R"nxt: Probe Outside Corner" J1 T0 S6 F{global.nxtClearance}
if { result != 0 }
    abort { "Outside corner probe aborted!" }

var surfaceClearance = { input }

if { var.surfaceClearance <= 0.1 }
    abort { "Clearance distance too low!" }

var cornerClearance = null

; 0 = Full mode, 1 = Quick mode
if { var.mode == 0 }
    ; Calculate the maximum clearance distance we can use before
    ; the probe points will be flipped
    var mC = { min(var.xSL, var.ySL) / 2 }

    if { var.surfaceClearance >= var.mC }
        var defCC = { max(1, var.mC-1) }
        var nxtCcMsgA = "The <b>clearance</b> distance is more than half of the length of one of the corner surfaces.<br/>"
        var nxtCcMsgB = { var.nxtCcMsgA ^ "Please enter a <b>corner clearance</b> distance less than <b>" ^ var.mC ^ "</b>." }
        M291 P{var.nxtCcMsgB} R"nxt: Probe Outside Corner" J1 T0 S6 F{var.defCC}
        set var.cornerClearance = { input }
        if { var.cornerClearance >= var.mC }
            abort { "Corner clearance distance too high!" }

; Prompt for overtravel distance
var nxtM291Msg11 = "Please enter <b>overtravel</b> distance in mm.<br/>This is how far we move past the expected surface to account for any innaccuracy in the dimensions."
M291 P{var.nxtM291Msg11} R"nxt: Probe Outside Corner" J1 T0 S6 F{global.nxtOvertravel}
if { result != 0 }
    abort { "Outside corner probe aborted!" }

var overtravel = { input }
if { var.overtravel < 0 }
    abort { "Overtravel distance must not be negative!" }

var nxtM291Msg12 = "Please jog the probe <b>OVER</b> the corner and press <b>OK</b>.<br/><b>CAUTION</b>: The chosen height of the probe is assumed to be safe for horizontal moves!"
M291 P{var.nxtM291Msg12} R"nxt: Probe Outside Corner" X1 Y1 Z1 J1 T0 S3
if { result != 0 }
    abort { "Outside corner probe aborted!" }

M98 P"nxt-m291-corners.g" R"nxt: Probe Outside Corner"
if { result != 0 }
    abort { "Outside corner probe aborted!" }

var cnr = { input }

var nxtM291Msg14 = "Please enter the depth to probe at in mm, relative to the current location. A value of 10 will move the probe downwards 10mm before probing inwards."
M291 P{var.nxtM291Msg14} R"nxt: Probe Outside Corner" J1 T0 S6 F{global.nxtOvertravel}
if { result != 0 }
    abort { "Outside corner probe aborted!" }

var probingDepth = { input }

if { var.probingDepth < 0 }
    abort { "Probing depth must not be negative!" }

; Run the block probe cycle
if { global.nxtTutorialMode }
    var nxtCnr = { "Front Left", "Front Right", "Back Right", "Back Left" }
    var cN = { var.nxtCnr[var.cnr] }
    var nxtM291Msg15 = {"We will now move outside the <b>" ^ var.cN ^ "</b> corner, down by " ^ var.probingDepth ^ "mm and probe each surface forming the corner." }
    M291 P{var.nxtM291Msg15} R"nxt: Probe Outside Corner" T0 S4 K{"Continue", "Cancel"} F0
    if { input != 0 }
        abort { "Outside corner probe aborted!" }

var nxtHx = { var.xSL }
var nxtIy = { var.ySL }
if { var.nxtHx == null }
    set var.nxtHx = { 100 }
if { var.nxtIy == null }
    set var.nxtIy = { 100 }
var nxtE = { var.cornerClearance }
if { var.nxtE == null }
    set var.nxtE = { global.nxtCornerOffset }

; Operator is already over the corner — G6508 uses current XY as corner air position
G6508 U{var.wcsNumber} N{var.cnr} L{var.probingDepth} H{var.nxtHx} I{var.nxtIy} C{var.surfaceClearance} O{var.overtravel} E{var.nxtE}
