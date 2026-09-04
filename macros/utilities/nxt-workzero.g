; nxt-workzero.g - MOVE TO WCS ORIGIN
;
; After G27 (G53 Z max), never work G0 X0 Y0 — leftover G38/G53 treats
; that as machine home. G53 G1 to G10 L2 workplaceOffsets (M6520 contract),
; Z at clearance, optional Z0 with XY pinned.

if { !inputs[state.thisInput].active }
    M99

G90
G21
G94

; RRF 3.7+: prefer motionSystems[0].workplaceNumber (move.workplaceNumber is obsolete).
var nxtWpIdx = 0
var nxtHasSys = false
if { exists(move.motionSystems) }
    if { #move.motionSystems > 0 }
        set var.nxtHasSys = true
if { var.nxtHasSys }
    set var.nxtWpIdx = { move.motionSystems[0].workplaceNumber }

var nxtWcsNum = { var.nxtWpIdx + 1 }
var wzOffX = { move.axes[0].workplaceOffsets[var.nxtWpIdx] }
var wzOffY = { move.axes[1].workplaceOffsets[var.nxtWpIdx] }
var wzOffZ = { move.axes[2].workplaceOffsets[var.nxtWpIdx] }
var wzToolZ = { 0 }
if { state.currentTool >= 0 }
    set var.wzToolZ = { tools[state.currentTool].offsets[2] }
var wzClr = { 10 }
if { exists(global.nxtClearance) && global.nxtClearance != null }
    set var.wzClr = { global.nxtClearance }
var wzZSafe = { var.wzOffZ + var.wzToolZ + var.wzClr }
var wzZ0 = { var.wzOffZ + var.wzToolZ }
var wzHasA = { #move.axes > 3 }
var wzA = { 0 }
if { var.wzHasA }
    set var.wzA = { move.axes[3].machinePosition }

var wzFeed = { 3000 }
var wzPid = { global.nxtTouchProbeID }
if { var.wzPid != null && sensors.probes[var.wzPid] != null }
    set var.wzFeed = { sensors.probes[var.wzPid].travelSpeed }
var wzFine = { var.wzFeed }
if { exists(global.nxtManualProbeFeeds) && #global.nxtManualProbeFeeds > 2 }
    set var.wzFine = { global.nxtManualProbeFeeds[2] }

G27 Z1
M400

if { global.nxtTutorialMode }
    var nxtWzMsg1a = { "We will now move above X=0, Y=0 in WCS " ^ var.nxtWcsNum }
    var nxtWzMsg1b = { " and then down to Z=" ^ var.wzClr ^ "mm.<br/>Press <b>Continue</b> to proceed!" }
    M291 P{var.nxtWzMsg1a ^ var.nxtWzMsg1b} R"nxt: Go to Zero" T0 S4 K{ "Continue", "Cancel" }
    if { input != 0 }
        abort { "Operator aborted move to X=0, Y=0!" }

var wzZMax = { move.axes[2].max }
var wzZMin = { move.axes[2].min }
if { var.wzZSafe > var.wzZMax }
    set var.wzZSafe = { var.wzZMax }
elif { var.wzZSafe < var.wzZMin }
    set var.wzZSafe = { var.wzZMin }
if { var.wzZ0 > var.wzZMax }
    set var.wzZ0 = { var.wzZMax }
elif { var.wzZ0 < var.wzZMin }
    set var.wzZ0 = { var.wzZMin }
if { var.wzHasA }
    G53 G1 F{var.wzFeed} X{var.wzOffX} Y{var.wzOffY} Z{var.wzZMax} A{var.wzA}
else
    G53 G1 F{var.wzFeed} X{var.wzOffX} Y{var.wzOffY} Z{var.wzZMax}
M400
if { var.wzHasA }
    G53 G1 F{var.wzFeed} X{var.wzOffX} Y{var.wzOffY} Z{var.wzZSafe} A{var.wzA}
else
    G53 G1 F{var.wzFeed} X{var.wzOffX} Y{var.wzOffY} Z{var.wzZSafe}
M400

var nxtWzMsg2a = { "Move to Z=0?<br/>Click <b>Continue</b> if you are sure the tool is " }
var nxtWzMsg2b = { var.wzClr ^ "mm above the origin, otherwise <b>Cancel</b>!" }
M291 P{var.nxtWzMsg2a ^ var.nxtWzMsg2b} R"nxt: Go to Zero" T0 S4 K{ "Continue", "Cancel" }
if { input != 0 }
    abort { "Operator aborted move to Z=0!" }

if { var.wzHasA }
    G53 G1 F{var.wzFine} X{var.wzOffX} Y{var.wzOffY} Z{var.wzZ0} A{var.wzA}
else
    G53 G1 F{var.wzFine} X{var.wzOffX} Y{var.wzOffY} Z{var.wzZ0}
M400
M98 P"nxt-g38-cancel.g"
