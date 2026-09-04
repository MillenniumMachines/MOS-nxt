; nxt-cal-travel-seed.g: seed G9000 / M5014 travel result globals
;
; Dial-safe legs: TR8x8 lead 8 mm → 1×/2×/3× = 8 / 16 / 24 mm (all ≤ ~25 mm
; indicator travel). Do not raise these without checking dial stroke.
; Caller sets nxtCalTravelAxis after this (axis letter).
;
; USAGE: M98 P"nxt-cal-travel-seed.g"

if { !inputs[state.thisInput].active }
    M99

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
