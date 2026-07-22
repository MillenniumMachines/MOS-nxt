; M5014.g: CALIBRATION PHASE-1 — INDICATOR ZERO / TRAVEL / RETURN (backlash estimate)
;
; Zero dial on block face → away by 8/16/24 → return same distance → enter residual.
; measured = commanded - residual → global.nxtCalTravelCmd / nxtCalTravelMeas
; Round-trip isolates lost motion (backlash), not steps/mm — use Phase 2 for M92.
;
; USAGE: M5014 X0|Y0|Z0|A0 D<±1> [R<1|3>] [F<feed>]
;   D = away direction along the axis (+1 or -1)
;   R = repeats per leg (1 default, or 3); mean residual used when R>1

if { !inputs[state.thisInput].active }
    M99

var axisParams = { null, null, null, null }
if { exists(param.X) }
    set var.axisParams[0] = param.X
if { exists(param.Y) }
    set var.axisParams[1] = param.Y
if { exists(param.Z) }
    set var.axisParams[2] = param.Z
if { exists(param.A) }
    set var.axisParams[3] = param.A

var axisIdx = -1
while { iterations < #var.axisParams }
    if { var.axisParams[iterations] != null }
        if { var.axisIdx != -1 }
            abort { "M5014: Specify exactly one of X, Y, Z, or A" }
        set var.axisIdx = { iterations }

if { var.axisIdx < 0 }
    abort { "M5014: Specify exactly one of X, Y, Z, or A" }

if { !exists(param.D) || param.D == null || param.D == 0 }
    abort { "M5014: D must be +1 or -1 (away from the measured face)" }

var dirAway = { param.D > 0 ? 1 : -1 }

if { var.axisIdx >= #move.axes || !move.axes[var.axisIdx].visible }
    abort { "M5014: Selected axis is not available" }

var letter = { move.axes[var.axisIdx].letter }
var repeats = { 1 }
if { exists(param.R) && param.R != null && param.R >= 3 }
    set var.repeats = 3

var feed = { exists(param.F) ? param.F : 300 }
if { exists(global.nxtManualProbeFeeds) && #global.nxtManualProbeFeeds > 1 }
    set var.feed = { exists(param.F) ? param.F : global.nxtManualProbeFeeds[1] }

G90
G21
G94

var jogA = { "Align indicator on the " ^ var.letter ^ " face (away dir " }
var jogB = { var.jogA ^ var.dirAway ^ "). Zero the dial, then OK." }
var jogC = { var.jogB ^ "<br/><b>CAUTION</b>: Jogging does not watch probes." }
M291 P{var.jogC} R"nxt: Calibration P1" X1 Y1 Z1 J1 T0 S3
if { result != 0 }
    abort { "M5014: Operator cancelled before test" }

M5000 P0
var startPos = { global.nxtAbsPos }

if { !exists(global.nxtCalTravelCmd) || global.nxtCalTravelCmd == null }
    global nxtCalTravelCmd = { vector(3, 0.0) }
if { !exists(global.nxtCalTravelMeas) || global.nxtCalTravelMeas == null }
    global nxtCalTravelMeas = { vector(3, 0.0) }
if { !exists(global.nxtCalTravelAxis) }
    global nxtCalTravelAxis = null

set global.nxtCalTravelCmd[0] = 8
set global.nxtCalTravelCmd[1] = 16
set global.nxtCalTravelCmd[2] = 24
set global.nxtCalTravelMeas[0] = 0
set global.nxtCalTravelMeas[1] = 0
set global.nxtCalTravelMeas[2] = 0
set global.nxtCalTravelAxis = { var.letter }

var distances = { 8, 16, 24 }
var leg = 0
while { var.leg < 3 }
    var dCmd = { var.distances[var.leg] }
    var sumR = { 0 }
    var rep = 0
    while { var.rep < var.repeats }
        ; Return to start before each cycle
        if { var.axisIdx == 0 }
            G53 G1 X{var.startPos[0]} F{var.feed}
        elif { var.axisIdx == 1 }
            G53 G1 Y{var.startPos[1]} F{var.feed}
        elif { var.axisIdx == 2 }
            G53 G1 Z{var.startPos[2]} F{var.feed}
        else
            G53 G1 A{var.startPos[3]} F{var.feed}
        M400

        var away = { var.dirAway * var.dCmd }
        var back = { 0 - var.away }
        G91
        if { var.axisIdx == 0 }
            G1 X{var.away} F{var.feed}
        elif { var.axisIdx == 1 }
            G1 Y{var.away} F{var.feed}
        elif { var.axisIdx == 2 }
            G1 Z{var.away} F{var.feed}
        else
            G1 A{var.away} F{var.feed}
        G90
        M400

        G91
        if { var.axisIdx == 0 }
            G1 X{var.back} F{var.feed}
        elif { var.axisIdx == 1 }
            G1 Y{var.back} F{var.feed}
        elif { var.axisIdx == 2 }
            G1 Z{var.back} F{var.feed}
        else
            G1 A{var.back} F{var.feed}
        G90
        M400

        var resMsgA = { "Leg " ^ { var.leg + 1 } ^ " D=" ^ var.dCmd }
        var resMsgB = { var.resMsgA ^ " rep " ^ { var.rep + 1 } ^ "/" ^ var.repeats }
        var resMsgC = { var.resMsgB ^ ": enter dial residual (mm). + = short of zero." }
        M291 P{var.resMsgC} R"nxt: Calibration P1" J1 T0 S6 F0
        if { result != 0 }
            abort { "M5014: Cancelled while entering residual" }
        set var.sumR = { var.sumR + input }

        set var.rep = { var.rep + 1 }

    var meanR = { var.sumR / var.repeats }
    var measured = { var.dCmd - var.meanR }
    set global.nxtCalTravelMeas[var.leg] = { var.measured }
    echo "M5014: leg " ^ { var.leg + 1 } ^ " cmd=" ^ var.dCmd ^ " meas=" ^ var.measured

    set var.leg = { var.leg + 1 }

; Return to start
if { var.axisIdx == 0 }
    G53 G1 X{var.startPos[0]} F{var.feed}
elif { var.axisIdx == 1 }
    G53 G1 Y{var.startPos[1]} F{var.feed}
elif { var.axisIdx == 2 }
    G53 G1 Z{var.startPos[2]} F{var.feed}
else
    G53 G1 A{var.startPos[3]} F{var.feed}
M400

echo { "M5014: Done on " ^ var.letter ^ " — review 8/16/24 results in Calibration UI" }
