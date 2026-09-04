; G37.1.g: PROBE Z SURFACE WITH CURRENT TOOL
;
; When the toolsetter is disabled, relative tool lengths are unknown — the Z origin of the
; current WCS must be re-set after each tool change using a manual probe with the installed tool.
;
; NOTE: Intended for tool-change use only (see tooling/tpost.g). Not a general probing macro.

if { !inputs[state.thisInput].active }
    M99

; Temporary G69 for jog + Z probe. Do not clear nxtJobG68Deg — tpost restores.
G69

var wPN = { move.motionSystems[0].workplaceNumber + 1 }

if { global.nxtTutorialMode && !global.nxtDialogDisplayed[12] }
    var nxtG371Msg1 = { "The <b>Toolsetter</b> feature is disabled, so you must set the Z origin in the current WCS after each tool change.<br/>We will run a manual probe cycle to do this." }
    M291 P{var.nxtG371Msg1} R"nxt: Reset Z Origin" S2 T0
    var nxtG371Msg2 = { "You <b>MUST</b> probe the location where WCS " ^ var.wPN ^ " expects the Z origin to be.<br/>Check in your CAM program to confirm where this is!" }
    M291 P{var.nxtG371Msg2} R"nxt: Reset Z Origin" S2 T0
    set global.nxtDialogDisplayed[12] = true

M291 P"Please jog the tool above your origin point in Z.<br/><b>CAUTION</b>: Remember - Jogging in RRF does <b>NOT</b> watch the probe status. Be careful!" R"nxt: Reset Z Origin" X1 Y1 Z1 T0 S3
if { result != 0 }
    abort { "G37.1: Surface probe aborted!" }

M291 P"Please enter the distance to probe towards the surface in mm." R"nxt: Reset Z Origin" J1 T0 S6 F{global.nxtClearance}
if { result != 0 }
    abort { "G37.1: Surface probe aborted!" }

var probeDist = { input }
if { var.probeDist < 0 }
    abort { "G37.1: Probe distance was negative!" }

var nxtG371OtMsg = { "Please enter <b>overtravel</b> distance in mm.<br/>This is how far we move past the expected surface to account for any innaccuracy in the dimensions." }
M291 P{var.nxtG371OtMsg} R"nxt: Reset Z Origin" J1 T0 S6 F{global.nxtOvertravel}
if { result != 0 }
    abort { "G37.1: Surface probe aborted!" }

var overtravel = { input }
if { var.overtravel < 0 }
    abort { "G37.1: Overtravel distance must not be negative!" }

M5000 P1 I2
var startZ = { global.nxtAbsPos }
var tPZ = { var.startZ - var.probeDist - var.overtravel }

M6515 Z{var.tPZ}

G6512.2 Z{var.tPZ}

if { !exists(global.nxtAbsPos) || global.nxtAbsPos[2] == null }
    abort { "G37.1: Surface probe failed!" }

G27 Z1

echo { "nxt: Setting WCS " ^ var.wPN ^ " Z origin to probed co-ordinate." }
if { !exists(global.nxtWcsHitZ) }
    global nxtWcsHitZ = null
if { !exists(global.nxtWcsNormZ) }
    global nxtWcsNormZ = null
set global.nxtWcsHitZ = { global.nxtAbsPos[2] }
M98 P"nxt-wcs-z-from-hit.g"
G10 L2 P{var.wPN} Z{global.nxtWcsNormZ}
