; M9.g: CONTROL ALL COOLANTS
;
; By default, disables all possible Coolant Outputs.
; If called with R1, restores the previous state of the
; coolant outputs. The state is only saved on pause.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Do not report an error here as M9 is called during parking
if { !global.nxtFeatureCoolantControl }
    M99

; Wait for all movement to stop before continuing.
M400

var restore = { exists(param.R) && param.R == 1 }

if { !var.restore }
    M98 P"nxt-coolant-pulse-stop.g"
    M99

; Restore coolant intent from pause snapshot (not instantaneous pulse phase)
if { !exists(global.nxtPinStates) || global.nxtPinStates == null }
    M99

var floodOn = false
if { global.nxtCoolantFloodID != null }
    set var.floodOn = { global.nxtPinStates[global.nxtCoolantFloodID] > 0 }

var mistOn = false
if { global.nxtCoolantMistID != null }
    set var.mistOn = { global.nxtPinStates[global.nxtCoolantMistID] > 0 }

set global.nxtCoolantFloodRequested = { var.floodOn }
set global.nxtCoolantMistRequested = { var.mistOn }
M98 P"nxt-coolant-pulse-arm.g"
