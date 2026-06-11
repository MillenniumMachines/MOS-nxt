; G99.g — Canned cycle retract to R plane
; Modal for nxt canned cycles. See LinuxCNC G98/G99.

if { !inputs[state.thisInput].active }
    M99

set global.nxtCannedRetractMode = { 99 }
