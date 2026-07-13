; G9000.g: AUTOMATED AXIS TRAVEL CALIBRATION (probe)
;
; Per leg (8 / 16 / 24 mm): probe (hit0) → away by D → probe (hit1), ×3.
; residual R = (hit1 - hit0) * dirToward; measured = D - meanR
; Results: global.nxtCalTravelCmd / nxtCalTravelMeas / nxtCalTravelAxis
; Does NOT apply M92/M425 — Calibration UI classifies and applies.
;
; USAGE: G9000 X0 | Y0 | Z0
; Requires: nxtFeatureTouchProbe, nxtTouchProbeID, probe tool selected.

if { !inputs[state.thisInput].active }
    M99

if { !global.nxtFeatureTouchProbe }
    abort { "G9000: Touch probe feature is not enabled" }

if { global.nxtTouchProbeID == null }
    abort { "G9000: nxtTouchProbeID is not configured" }

var axisParams = { exists(param.X), exists(param.Y), exists(param.Z) }
var axisIdx = -1
var nAxes = 0
while { iterations < 3 }
    if { var.axisParams[iterations] }
        set var.nAxes = { var.nAxes + 1 }
        set var.axisIdx = { iterations }

if { var.nAxes != 1 || var.axisIdx < 0 }
    abort { "G9000: Specify exactly one of X, Y, or Z" }

if { var.axisIdx >= #move.axes || !move.axes[var.axisIdx].visible }
    abort { "G9000: Selected axis is not available" }

var letter = { move.axes[var.axisIdx].letter }
var probeId = { global.nxtTouchProbeID }

G90
G21
G94

var jogA = { "Jog the probe near a fixed 1-2-3 face along " ^ var.letter }
var jogB = { var.jogA ^ " (block: 3in parallel to X). Leave clearance." }
var jogC = { var.jogB ^ "<br/><b>CAUTION</b>: Jogging does not watch the probe. OK when ready." }
M291 P{var.jogC} R"nxt: G9000" X1 Y1 Z1 J1 T0 S3
if { result != 0 }
    abort { "G9000: Operator cancelled" }

var dirNames = { "Toward + machine", "Toward - machine" }
M291 P"Probe direction toward the surface?" R"nxt: G9000" S4 K{var.dirNames} F0 T0
if { result != 0 }
    abort { "G9000: Operator cancelled" }
var dir = { input == 0 ? 1 : -1 }
var dirAway = { 0 - var.dir }

M5000 P0
var approach0 = { global.nxtAbsPos }

; Overshoot past the surface for G6512 target
var overshoot = { 30 }

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

var feed = { 300 }
if { exists(global.nxtManualProbeFeeds) && #global.nxtManualProbeFeeds > 1 }
    set var.feed = { global.nxtManualProbeFeeds[1] }

var distances = { 8, 16, 24 }
var leg = 0
while { var.leg < 3 }
    var dCmd = { var.distances[var.leg] }
    var sumR = { 0 }
    var rep = 0
    while { var.rep < 3 }
        ; Start each cycle from original approach
        if { var.axisIdx == 0 }
            G53 G1 X{var.approach0[0]} F{var.feed}
        elif { var.axisIdx == 1 }
            G53 G1 Y{var.approach0[1]} F{var.feed}
        else
            G53 G1 Z{var.approach0[2]} F{var.feed}
        M400

        M5000 P0
        var cur = { global.nxtAbsPos[var.axisIdx] }
        var tgt0 = { var.cur + var.dir * var.overshoot }

        if { var.axisIdx == 0 }
            G6512 X{var.tgt0} I{var.probeId}
        elif { var.axisIdx == 1 }
            G6512 Y{var.tgt0} I{var.probeId}
        else
            G6512 Z{var.tgt0} I{var.probeId}

        var hit0 = { global.nxtLastProbeResult }

        ; Away from surface by commanded test travel
        G91
        if { var.axisIdx == 0 }
            G1 X{var.dirAway * var.dCmd} F{var.feed}
        elif { var.axisIdx == 1 }
            G1 Y{var.dirAway * var.dCmd} F{var.feed}
        else
            G1 Z{var.dirAway * var.dCmd} F{var.feed}
        G90
        M400

        M5000 P0
        var cur2 = { global.nxtAbsPos[var.axisIdx] }
        var tgt1 = { var.cur2 + var.dir * var.overshoot }

        if { var.axisIdx == 0 }
            G6512 X{var.tgt1} I{var.probeId}
        elif { var.axisIdx == 1 }
            G6512 Y{var.tgt1} I{var.probeId}
        else
            G6512 Z{var.tgt1} I{var.probeId}

        var hit1 = { global.nxtLastProbeResult }
        var R = { (var.hit1 - var.hit0) * var.dir }
        set var.sumR = { var.sumR + var.R }

        set var.rep = { var.rep + 1 }

    var meanR = { var.sumR / 3 }
    var measured = { var.dCmd - var.meanR }
    set global.nxtCalTravelMeas[var.leg] = { var.measured }
    echo "G9000: leg " ^ { var.leg + 1 } ^ " cmd=" ^ var.dCmd ^ " meas=" ^ var.measured

    set var.leg = { var.leg + 1 }

; Return to original approach
if { var.axisIdx == 0 }
    G53 G1 X{var.approach0[0]} F{var.feed}
elif { var.axisIdx == 1 }
    G53 G1 Y{var.approach0[1]} F{var.feed}
else
    G53 G1 Z{var.approach0[2]} F{var.feed}
M400

echo "G9000: Done on " ^ var.letter ^ " — review results in Calibration UI"
