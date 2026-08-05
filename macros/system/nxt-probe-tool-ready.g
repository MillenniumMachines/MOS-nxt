; nxt-probe-tool-ready.g — M4000 probe row, select probe tool, confirm tip.
;
; USAGE: M98 P"nxt-probe-tool-ready.g" [S1]
;   S1: skip T{probe} selection (caller already selected tool)

if { !inputs[state.thisInput].active }
    M99

if { !global.nxtFeatureTouchProbe }
    abort { "nxt-probe-tool-ready: Touch probe feature not enabled" }

if { global.nxtTouchProbeID == null }
    abort { "nxt-probe-tool-ready: nxtTouchProbeID not configured" }

if { !exists(global.nxtProbeToolID) || global.nxtProbeToolID == null }
    abort { "nxt-probe-tool-ready: nxtProbeToolID not configured" }

; Skip sync when probe M4000 row already matches tip radius + name (avoids SD churn).
var nxtProbeRowOk = false
var nxtProbeIdx = { global.nxtProbeToolID }
var nxtRadOk = false
var nxtNameOk = false
if { exists(global.nxtTT) && global.nxtTT[var.nxtProbeIdx] != null }
    if { #tools > var.nxtProbeIdx && tools[var.nxtProbeIdx] != null }
        if { global.nxtProbeTipRadius != null }
            set var.nxtRadOk = { global.nxtTT[var.nxtProbeIdx][0] == global.nxtProbeTipRadius }
            set var.nxtNameOk = { tools[var.nxtProbeIdx].name == "Touch Probe" }
            set var.nxtProbeRowOk = { var.nxtRadOk && var.nxtNameOk }
if { !var.nxtProbeRowOk }
    M98 P"nxt-probe-tool-sync.g"

var skipSelect = { exists(param.S) && param.S == 1 }
if { !var.skipSelect && state.currentTool != global.nxtProbeToolID }
    echo "nxt-probe-tool-ready: Selecting touch probe T" ^ global.nxtProbeToolID
    T{global.nxtProbeToolID}

; P1: install prompt + tip poll (standalone G6511 / G6600 / M6523 path)
M98 P"nxt-probe-sensor-wait.g" P1
