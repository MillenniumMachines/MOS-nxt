; M7.g: MIST ON
;
; Mist is a combination output of air and unpressurized coolant.
; Turn on the blast air first, then turn on the coolant (steady or pulsed).

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

if { !global.nxtFeatureCoolantControl || global.nxtCoolantMistID == null }
    echo { "nxt: Coolant Control feature is disabled or not configured, cannot enable Mist Coolant." }
    M99

; Wait for all movement to stop before continuing.
M400

set global.nxtCoolantMistRequested = true
M98 P"nxt-coolant-pulse-arm.g"
