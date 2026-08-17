; G6510-jog.g: SINGLE SURFACE PROBE
;
; Meta macro to gather operator input before executing G6510.
; Surface names are relative to an operator at the front of the mill
; (surfaces: Left, Right, Front, Back, Top). Calls G6510 N/O
; (and L for XY dive), not legacy G6510.1.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Index of the zProbe entry as this requires different inputs (Top).
var zProbeI = { 4 }
var nxtSfc = { "Left", "Right", "Front", "Back", "Top" }

; Display description of surface probe if not displayed this session
if { global.nxtTutorialMode && !global.nxtDialogDisplayed[4] }
    var nxtM291Msg1 = "This operation finds the co-ordinate of a surface on a single axis. It is usually used to find the top surface of a workpiece but can be used to find X or Y positions as well."
    M291 P{var.nxtM291Msg1} R"nxt: Probe Surface" T0 S2
    M291 P"<b>CAUTION</b>: This operation will only return accurate results if the surface you are probing is perpendicular to the axis you are probing in." R"nxt: Probe Surface" T0 S2
    var nxtM291Msg2 = "You will jog the tool or touch probe to your chosen starting position. Your starting position should be outside and above X or Y surfaces, or directly above the top surface."
    M291 P{var.nxtM291Msg2} R"nxt: Probe Surface" T0 S2
    M291 P"<b>CAUTION</b>: Jogging in RRF does <b>NOT</b> watch the probe status. Be careful!" R"nxt: Probe Surface" T0 S2
    var nxtM291Msg3 = "<b>CAUTION</b>: For X or Y surfaces, the probe will move down <b>BEFORE</b> moving horizontally to detect a surface. Bear this in mind when selecting a starting position."
    M291 P{var.nxtM291Msg3} R"nxt: Probe Surface" T0 S2
    var nxtM291Msg4 = "For X or Y surfaces, you will then be asked for a <b>probe depth</b>. This is how far your probe will move down from the starting position before moving in X or Y."
    M291 P{var.nxtM291Msg4} R"nxt: Probe Surface" T0 S2
    var nxtM291Msg5 = "Finally, you will be asked to set a <b>probe distance</b>. This is how far the probe will move towards a surface before returning an error if it did not trigger."
    M291 P{var.nxtM291Msg5} R"nxt: Probe Surface" T0 S2
    var nxtM291Msg6 = "If you are still unsure, you can <a target=""_blank"" href=""https://mos.diycnc.xyz/usage/single-surface"">View the Single Surface Documentation</a> for more details."
    M291 P{var.nxtM291Msg6} R"nxt: Probe Surface" T0 S4 K{"Continue", "Cancel"} F0
    if { input != 0 }
        abort { "Surface probe aborted!" }

    set global.nxtDialogDisplayed[4] = true

; Make sure probe tool is selected
if { global.nxtProbeToolID != state.currentTool }
    T T{global.nxtProbeToolID}

; Prompt for overtravel distance
var nxtM291Msg7 = "Please enter <b>overtravel</b> distance in mm.<br/>This is how far we move past the expected surface to account for any innaccuracy in the dimensions."
M291 P{var.nxtM291Msg7} R"nxt: Probe Surface" J1 T0 S6 F{global.nxtOvertravel}
if { result != 0 }
    abort { "Single Surface probe aborted!" }

var overtravel = { input }
if { var.overtravel < 0 }
    abort { "Overtravel distance must not be negative!" }

; Ask the operator to jog to their chosen starting position
var nxtM291Msg8 = "Please jog the probe or tool to your chosen starting position.<br/><b>CAUTION</b>: Remember - Jogging in RRF does <b>NOT</b> watch the probe status. Be careful!"
M291 P{var.nxtM291Msg8} R"nxt: Probe Surface" X1 Y1 Z1 T0 S3
if { result != 0 }
    abort { "Surface probe aborted!" }

M98 P"nxt-m291-surfaces.g" F{var.zProbeI}
if { result != 0 }
    abort { "Surface probe aborted!" }
var probeAxis = { input }

; For Z probes, our depth is 0 but our distance is the probing depth
var probeDepth = 0

var isZProbe = { var.probeAxis == var.zProbeI }

; If this is an X/Y probe, ask for depth
if { !var.isZProbe }
    var nxtM291Msg10 = "Please enter the depth to probe at in mm, below the current location.<br/><b>Example</b>: A value of 10 will move the probe downwards 10mm before probing outwards."
    M291 P{var.nxtM291Msg10} R"nxt: Probe Surface" J1 T0 S6 F{global.nxtOvertravel}
    if { result != 0 }
        abort { "Surface probe aborted!" }

    set var.probeDepth = { input }

    if { var.probeDepth < 0 }
        abort { "Probing depth was negative!" }

M291 P"Please enter the distance to probe towards the surface in mm." R"nxt: Probe Surface" J1 T0 S6 F{global.nxtClearance}
if { result != 0 }
    abort { "Surface probe aborted!" }

var probeDist = { input }

if { var.probeDist < 0 }
    abort { "Probe distance was negative!" }

if { global.nxtTutorialMode }
    if { !var.isZProbe }
        var nxtM291Msg11 = {"Probe will now move down <b>" ^ var.probeDepth ^ "</b> mm and probe towards the <b>" ^ var.nxtSfc[var.probeAxis] ^ "</b> surface." }
        M291 P{var.nxtM291Msg11} R"nxt: Probe Surface" T0 S4 K{"Continue", "Cancel"} F0
        if { input != 0 }
            abort { "Single Surface probe aborted!" }
    else
        M291 P{"Probe will now move towards the <b>" ^ var.nxtSfc[var.probeAxis] ^ "</b> surface." } R"nxt: Probe Surface" T0 S4 K{"Continue", "Cancel"} F0
        if { input != 0 }
            abort { "Single Surface probe aborted!" }

; G6510 snapshots pose (M5000) and seeks O from that air position.
var wcsU = { move.motionSystems[0].workplaceNumber + 1 }
if { exists(param.W) && param.W != null }
    set var.wcsU = { param.W + 1 }
if { var.wcsU < 1 || var.wcsU > 9 }
    abort { "G6510-jog: WCS U must be 1-9" }

var seek = { var.probeDist + var.overtravel }
if { var.seek <= 0 }
    abort { "G6510-jog: Probe distance plus overtravel must be positive" }

if { var.isZProbe }
    G6510 U{var.wcsU} N{var.probeAxis} O{var.seek}
elif { var.probeDepth > 0 }
    G6510 U{var.wcsU} N{var.probeAxis} O{var.seek} L{var.probeDepth}
else
    G6510 U{var.wcsU} N{var.probeAxis} O{var.seek}
