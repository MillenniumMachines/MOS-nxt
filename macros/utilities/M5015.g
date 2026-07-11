; M5015.g: CALIBRATION G6512 — JOG, PROBE, RETURN
;
; Jog to approach → G6512 to target → return to approach position.
; USAGE: M5015 X|Y|Z<target> I<probeId>
; Target is machine coordinate for the probe move (may be negative).

if { !inputs[state.thisInput].active }
    M99

var axisParams = { null, null, null }
if { exists(param.X) }
    set var.axisParams[0] = param.X
if { exists(param.Y) }
    set var.axisParams[1] = param.Y
if { exists(param.Z) }
    set var.axisParams[2] = param.Z

var axisIdx = -1
var target = 0
while { iterations < #var.axisParams }
    if { var.axisParams[iterations] != null }
        if { var.axisIdx != -1 }
            abort { "M5015: Specify exactly one of X, Y, or Z" }
        set var.axisIdx = { iterations }
        set var.target = { var.axisParams[iterations] }

if { var.axisIdx < 0 }
    abort { "M5015: Specify exactly one of X, Y, or Z as the probe target" }

if { !exists(param.I) || param.I == null }
    abort { "M5015: Probe ID I.. is required" }

var letter = { move.axes[var.axisIdx].letter }

var jogMsgA = { "Jog near the measuring surface for " ^ var.letter }
var jogMsgB = { var.jogMsgA ^ ", then press OK.<br/><b>CAUTION</b>: Jogging does not watch the probe." }
M291 P{var.jogMsgB} R"nxt: Calibration probe" X1 Y1 Z1 J1 T0 S3
if { result != 0 }
    abort { "M5015: Operator cancelled before probe" }

M5000 P0
var approach = { global.nxtAbsPos }

if { var.axisIdx == 0 }
    G6512 X{var.target} I{param.I}
elif { var.axisIdx == 1 }
    G6512 Y{var.target} I{param.I}
else
    G6512 Z{var.target} I{param.I}

; G6512 already backs off by dive height; return to pre-probe approach
var feed = { 600 }
if { exists(global.nxtManualProbeFeeds) && #global.nxtManualProbeFeeds > 0 }
    set var.feed = { global.nxtManualProbeFeeds[0] }

G90
if { var.axisIdx == 0 }
    G53 G1 X{var.approach[0]} F{var.feed}
elif { var.axisIdx == 1 }
    G53 G1 Y{var.approach[1]} F{var.feed}
else
    G53 G1 Z{var.approach[2]} F{var.feed}
M400

echo { "M5015: Probe done; returned to approach. Capture nxtLastProbeResult in Calibration." }
