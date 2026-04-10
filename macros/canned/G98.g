; G98.g — Canned cycle retract to initial Z (series start height) when above R
; Modal for NeXT canned cycles. See LinuxCNC G98/G99.

if { !inputs[state.thisInput].active }
    M99

set global.nxtCannedRetractMode = { 98 }
