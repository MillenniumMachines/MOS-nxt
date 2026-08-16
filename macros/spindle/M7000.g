; M7000.g: ENABLE VSSC
;
; USAGE: M7000 P<period-ms> V<variance-rpm>

if { !inputs[state.thisInput].active }
    M99

if { !exists(param.P) }
    abort { "M7000: P (period in milliseconds) is required" }

if { !exists(param.V) }
    abort { "M7000: V (variance in RPM) is required" }

var daemonMs = { global.nxtDaemonInterval }
if { param.P < var.daemonMs }
    abort { "M7000: P cannot be less than nxtDaemonInterval (" ^ var.daemonMs ^ "ms)" }

if { mod(param.P, var.daemonMs) > 0 }
    abort { "M7000: P must be a multiple of nxtDaemonInterval (" ^ var.daemonMs ^ "ms)" }

set global.nxtVSP = { param.P }
set global.nxtVSV = { param.V }
set global.nxtVSEnabled = true
