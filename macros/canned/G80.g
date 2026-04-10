; G80.g — Cancel canned drilling cycle modal state (LinuxCNC-style)
; Clears sticky parameters. RRF does not intercept G0/G1 here; always use G80 or start a new plane/cycle explicitly when unsure.

if { !inputs[state.thisInput].active }
    M99

set global.nxtCannedCycle = { null }
