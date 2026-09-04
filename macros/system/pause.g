; pause.g - PAUSE CURRENT JOB

; Save pre-pause state of general purpose output pins (allocate snapshot on demand).
if { !exists(global.nxtPinStates) || global.nxtPinStates == null }
    if { !exists(global.nxtPinStates) }
        global nxtPinStates = { vector(min(limits.gpOutPorts, 8), 0.0) }
    else
        set global.nxtPinStates = { vector(min(limits.gpOutPorts, 8), 0.0) }

while { iterations < min(#state.gpOut, #global.nxtPinStates) }
    if { state.gpOut[iterations] != null }
        set global.nxtPinStates[iterations] = state.gpOut[iterations].pwm

; When coolant is pulsing, save operator intent (not instantaneous OFF phase)
var nxtPulsePause = { exists(global.nxtCoolantPulseActive) && global.nxtCoolantPulseActive }
if { var.nxtPulsePause }
    if { global.nxtCoolantMistID != null && global.nxtCoolantMistRequested }
        set global.nxtPinStates[global.nxtCoolantMistID] = 1
    if { global.nxtCoolantFloodID != null && global.nxtCoolantFloodRequested }
        set global.nxtPinStates[global.nxtCoolantFloodID] = 1
    if { global.nxtCoolantAirID != null && global.nxtCoolantMistRequested }
        set global.nxtPinStates[global.nxtCoolantAirID] = 1

; Raise the spindle to the top of the Z axis and
; then stop it, but do not move the table.
G27 Z1

; Run plugin pause hooks, if generated.
if { fileexists("0:/sys/nxt/plugins/nxt-plugin-hooks-pause.g") }
    M98 P"nxt/plugins/nxt-plugin-hooks-pause.g"
