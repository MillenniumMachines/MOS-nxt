; nxt-probe-tool-ready.g — M4000 probe row, select probe tool, wait for sensor active.
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

M98 P"nxt-probe-tool-sync.g"

var skipSelect = { exists(param.S) && param.S == 1 }
if { !var.skipSelect && state.currentTool != global.nxtProbeToolID }
    echo "nxt-probe-tool-ready: Selecting touch probe T" ^ global.nxtProbeToolID
    T{global.nxtProbeToolID}

M98 P"nxt-probe-sensor-wait.g"
