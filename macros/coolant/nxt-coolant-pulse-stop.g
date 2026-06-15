; nxt-coolant-pulse-stop.g
; Clear coolant request / pulse state and turn outputs off.

set global.nxtCoolantMistRequested = false
set global.nxtCoolantFloodRequested = false
set global.nxtCoolantPulseActive = false
set global.nxtCoolantPulsePhaseOn = true
set global.nxtCoolantPulseLastMs = 0

M98 P"nxt-coolant-pulse-apply.g"
