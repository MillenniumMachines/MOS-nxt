; M8.g: FLOOD ON
;
; Flood enables pressurised coolant flow over the cutting tool.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

if { !global.nxtFeatureCoolantControl || global.nxtCoolantFloodID == null }
    echo { "nxt: Coolant Control feature is disabled or not configured, cannot enable Flood Coolant." }
    M99

; Wait for all movement to stop before continuing.
M400

; Turn on flood
M42 P{global.nxtCoolantFloodID} S1
