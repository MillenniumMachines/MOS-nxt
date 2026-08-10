; G9000.g: AUTOMATED AXIS TRAVEL CALIBRATION (probe) — backlash estimate
;
; Per leg (TR8x8: 1×/2×/3× of 8 mm lead = 8 / 16 / 24): probe → away D → probe, ×3.
; residual R = (hit1 - hit0) * dirToward; measured = D - meanR
; Same approach dir ⇒ tip/deflection cancel in R; R ≈ backlash when M425 unset.
; Results: global.nxtCalTravelCmd / nxtCalTravelMeas / nxtCalTravelAxis
; Does NOT apply M92/M425 — Calibration UI classifies (backlash only) and applies M425.
; Use Phase 3 dual-dimension spans for steps/mm.
;
; USAGE: G9000 X0 | Y0 | Z0 [J0] [H±1]
;   J0: skip jog M291 (already at approach, e.g. after M5018)
;   H: toward-surface dir (+1 / -1); required with J0, else prompted
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

var skipJog = { false }
if { exists(param.J) && param.J == 0 }
    set var.skipJog = { true }

G90
G21
G94

var jogA = { "G9000 on " ^ var.letter ^ ". Orient 1-2-3 with 3in ∥ X; jog near the face, then OK." }
if { !var.skipJog }
    M291 P{var.jogA} R"nxt: G9000" X1 Y1 Z1 J1 T0 S3
    if { result != 0 }
        abort { "G9000: Operator cancelled" }

var dir = { 0 }
var haveDir = { false }
if { exists(param.H) && param.H != null }
    if { param.H == 1 || param.H == -1 }
        set var.dir = { param.H }
        set var.haveDir = { true }

var dirNames = { "Toward + machine", "Toward - machine" }
if { !var.haveDir }
    if { var.skipJog }
        abort { "G9000: J0 requires H±1 (toward-surface direction)" }
    M291 P"Probe direction toward the surface?" R"nxt: G9000" S4 K{var.dirNames} F0 T0
    if { result != 0 }
        abort { "G9000: Operator cancelled" }
    set var.dir = { input == 0 ? 1 : -1 }

var dirAway = { 0 - var.dir }

M5000 P0
var approach0 = { global.nxtAbsPos }

; Overshoot past the surface for G6512 target
var overshoot = { 30 }

; nxt-vars declares these null — never use # on null (RRF: Expecting array expression).
if { !exists(global.nxtCalTravelCmd) }
    global nxtCalTravelCmd = { 8.0, 16.0, 24.0 }
else
    set global.nxtCalTravelCmd = { 8.0, 16.0, 24.0 }
if { !exists(global.nxtCalTravelMeas) }
    global nxtCalTravelMeas = { 0.0, 0.0, 0.0 }
else
    set global.nxtCalTravelMeas = { 0.0, 0.0, 0.0 }
if { !exists(global.nxtCalTravelAxis) }
    global nxtCalTravelAxis = null

set global.nxtCalTravelAxis = { var.letter }

var feed = { 300 }
if { exists(global.nxtManualProbeFeeds) && #global.nxtManualProbeFeeds > 1 }
    set var.feed = { global.nxtManualProbeFeeds[1] }

; TR8x8 lead 8 mm → travel legs 1× / 2× / 3× lead
var distances = { 8.0, 16.0, 24.0 }
var meas0 = 0.0
var meas1 = 0.0
var meas2 = 0.0
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
    ; Full-vector assign so DSF/DWC OM sees all three legs (indexed set can drop [2]).
    if { var.leg == 0 }
        set var.meas0 = { var.measured }
    elif { var.leg == 1 }
        set var.meas1 = { var.measured }
    else
        set var.meas2 = { var.measured }
    set global.nxtCalTravelMeas = { var.meas0, var.meas1, var.meas2 }
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

echo "G9000: Done on " ^ var.letter ^ " — cmd {8,16,24} meas {" ^ var.meas0 ^ ", " ^ var.meas1 ^ ", " ^ var.meas2 ^ "}"
