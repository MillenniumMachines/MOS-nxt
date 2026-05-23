; M80.9.g: ENABLE ATX POWER
;
; Allows the operator to enable ATX power with confirmation.
;
; USAGE: M80.9

; If no ATX power port is configured, exit
if { state.atxPowerPort == null }
    M99

; If power is already enabled, exit
if { state.atxPower }
    M99

; Prompt the operator to enable ATX power
var nxtM80Msg = {"<b>CAUTION</b>: Machine Power is <b>off</b>. Activate?<br/>Confirm the machine is safe first."}
M291 P{var.nxtM80Msg} R"NeXT: Safety Net" S4 K{"Activate", "Cancel"} F1

if { input == 0 }
    M80
    echo {"NeXT: Safety Net - Machine Power Activated!<br/>Run <b>M81.9</b> to deactivate power."}