; G6501.1.g: GUIDED BOSS PROBE
;
; Meta macro to gather operator input, then run modern G6501
; (3-pt boss triangulation → nxtProbeResults + M6520 via U).

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Display description of boss probe if not already displayed this session
if { global.nxtTutorialMode && !global.nxtDialogDisplayed[3] }
    var nxtM291Msg1a = "This probe cycle finds the X and Y co-ordinates of the center of a circular boss (protruding feature) on a workpiece "
    var nxtM291Msg1b = { var.nxtM291Msg1a ^ "by probing towards the approximate center of the boss in 3 directions." }
    M291 P{var.nxtM291Msg1b} R"nxt: Probe Boss" T0 S2
    var nxtM291Msg2a = "You will be asked to enter an approximate <b>boss diameter</b> and <b>clearance distance</b>.<br/>"
    var nxtM291Msg2b = { var.nxtM291Msg2a ^ "These define how far the probe will move away from the centerpoint before probing back inwards." }
    M291 P{var.nxtM291Msg2b} R"nxt: Probe Boss" T0 S2
    var nxtM291Msg3a = "You will then jog the tool over the approximate center of the boss.<br/>"
    var nxtM291Msg3b = { var.nxtM291Msg3a ^ "<b>CAUTION</b>: Jogging in RRF does not watch the probe status, so you could cause damage if moving in the wrong direction!" }
    M291 P{var.nxtM291Msg3b} R"nxt: Probe Boss" T0 S2
    M291 P"You will then be asked for a <b>probe depth</b>. This is how far the probe will move downwards before probing back towards the centerpoint." R"nxt: Probe Boss" T0 S2
    var nxtM291Msg4 = "If you are still unsure, you can <a target=""_blank"" href=""https://mos.diycnc.xyz/usage/circular-boss"">View the Circular Boss Documentation</a> for more details."
    M291 P{var.nxtM291Msg4} R"nxt: Probe Boss" T0 S4 K{"Continue", "Cancel"} F0
    if { input != 0 }
        abort { "Boss probe aborted!" }
    set global.nxtDialogDisplayed[3] = true

; Make sure probe tool is selected
if { global.nxtProbeToolID != state.currentTool }
    T T{global.nxtProbeToolID}

; Default workOffset to the current workplace number if not specified
; with the W parameter.
var workOffset = { move.motionSystems[0].workplaceNumber }
if { exists(param.W) && param.W != null }
    set var.workOffset = { param.W }


; WCS Numbers and Offsets are confusing. Work Offset indicates the offset
; from the first work co-ordinate system, so is 0-indexed. WCS number indicates
; the number of the work co-ordinate system, so is 1-indexed.
var wcsNumber = { var.workOffset + 1 }

; Prompt for boss diameter
var nxtBossF = { 0 }
if { exists(global.nxtWPRad) && exists(global.nxtDfltWPRad) }
    if { global.nxtWPRad[var.workOffset] != global.nxtDfltWPRad }
        set var.nxtBossF = { global.nxtWPRad[var.workOffset] * 2 }
M291 P"Please enter approximate boss diameter in mm." R"nxt: Probe Boss" J1 T0 S6 F{var.nxtBossF}
if { result != 0 }
    abort { "Boss probe aborted!" }

var bossDiameter = { input }

if { var.bossDiameter < 1 }
    abort { "Boss diameter too low!" }

; Prompt for clearance distance
M291 P"Please enter clearance distance in mm." R"nxt: Probe Boss" J1 T0 S6 F{global.nxtClearance}
if { result != 0 }
    abort { "Boss probe aborted!" }

var clearance = { input }
if { var.clearance < 1 }
    abort { "Clearance distance too low!" }

; Prompt for overtravel distance
M291 P"Please enter the overtravel distance in mm." R"nxt: Probe Boss" J1 T0 S6 F{global.nxtOvertravel}
if { result != 0 }
    abort { "Boss probe aborted!" }

var overtravel = { input }
if { var.overtravel < 0.1 }
    abort { "Overtravel distance too low!" }

var nxtM291Msg5 = "Please jog the probe <b>OVER</b> the center of the boss and press <b>OK</b>.<br/><b>CAUTION</b>: The chosen height of the probe is assumed to be safe for horizontal moves!"
M291 P{var.nxtM291Msg5} R"nxt: Probe Boss" X1 Y1 Z1 J1 T0 S3
if { result != 0 }
    abort { "Boss probe aborted!" }

var nxtM291Depth = { "Please enter the depth to probe at in mm, relative to the current location." }
var nxtM291Depth2 = { " A value of 10 will move the probe downwards 10mm before probing inwards." }
M291 P{var.nxtM291Depth ^ var.nxtM291Depth2} R"nxt: Probe Boss" J1 T0 S6 F{global.nxtOvertravel}
if { result != 0 }
    abort { "Boss probe aborted!" }

var probingDepth = { input }

if { var.probingDepth <= 0}
    abort { "Probing depth was negative!" }

; Run the boss probe cycle
if { global.nxtTutorialMode }
    var nxtBossOutMm = { (var.bossDiameter/2) + var.clearance }
    var nxtBossRunMsg = { "Probe will now move outwards by " ^ var.nxtBossOutMm ^ "mm, then downwards " ^ var.probingDepth ^ "mm, before probing back towards the center at 3 points." }
    M291 P{var.nxtBossRunMsg} R"nxt: Probe Boss" T0 S4 K{"Continue", "Cancel"} F0
    if { input != 0 }
        abort { "Boss probe aborted!" }

; Operator is already at approx center — G6501 uses current XY as assumed center
G6501 U{var.wcsNumber} D{var.bossDiameter} L{var.probingDepth} C{var.clearance} O{var.overtravel}
