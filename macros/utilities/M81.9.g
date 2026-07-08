; M81.9.g: DISABLE ATX POWER
;
; Allows the operator to disable ATX power with confirmation.
;
; USAGE: M81.9

if { !inputs[state.thisInput].active }
    M99

; If no ATX power port is configured, exit
if { state.atxPowerPort == null }
    M99

; If power is already disabled, exit
if { !state.atxPower }
    M99

; Prompt the operator to disable ATX power
var nxtM81Msg = {"<b>CAUTION</b>: Machine Power is <b>on</b>. Deactivate?<br/>Stops <b>ALL</b> movement and spindle."}
M291 P{var.nxtM81Msg} R"nxt: Safety Net" S4 K{"Deactivate", "Cancel"} F1

if { input == 0 }
    M81
    echo {"nxt: Safety Net - Machine Power Deactivated!<br/>Run <b>M80.9</b> to activate power."}