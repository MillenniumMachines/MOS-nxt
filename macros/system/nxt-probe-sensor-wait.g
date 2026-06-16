; nxt-probe-sensor-wait.g — Block until touch probe sensor reads active.
;
; USAGE: M98 P"nxt-probe-sensor-wait.g" [A0|A1]
;   A0 (default): M291 S4 OK/Cancel
;   A1: M291 S3 trigger (tpre.g style)

if { !inputs[state.thisInput].active }
    M99

if { !global.nxtFeatureTouchProbe }
    abort { "nxt-probe-sensor-wait: Touch probe feature not enabled" }

if { global.nxtTouchProbeID == null }
    abort { "nxt-probe-sensor-wait: nxtTouchProbeID not configured" }

var useS3 = { exists(param.A) && param.A == 1 }
var ready = false
if { sensors.probes[global.nxtTouchProbeID].value[0] >= sensors.probes[global.nxtTouchProbeID].threshold }
    set var.ready = true

while { !var.ready }
    if { var.useS3 }
        M291 P"Load touch probe, and trigger to proceed." R"Touch Probe Check" S3
        if { input != 0 }
            abort { "tpre.g: Touch probe check cancelled by user" }
    if { !var.useS3 }
        M291 P"Install touch probe, then press OK when the probe input is active." R"Touch Probe" S4 K{"OK", "Cancel"} F1
        if { input != 0 }
            abort { "nxt-probe-sensor-wait: Touch probe check cancelled" }
    if { sensors.probes[global.nxtTouchProbeID].value[0] >= sensors.probes[global.nxtTouchProbeID].threshold }
        set var.ready = true
