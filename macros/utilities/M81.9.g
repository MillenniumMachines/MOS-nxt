; M81.9.g: DISABLE MACHINE POWER
;
; Operator-confirmed drop of the motor/VFD contactor.
; Scylla: gpOut nxtRelayID (P5 / PD_5). Other boards: RRF ATX if configured.
;
; USAGE: M81.9

if { !inputs[state.thisInput].active }
    M99

var nxtUseGp = false
if { exists(global.nxtRelayID) && global.nxtRelayID != null }
    if { global.nxtRelayID >= 0 }
        set var.nxtUseGp = true

if { !var.nxtUseGp }
    if { state.atxPowerPort == null }
        M99

var nxtAlreadyOff = true
if { var.nxtUseGp }
    set var.nxtAlreadyOff = true
    if { global.nxtRelayID < #state.gpOut }
        if { state.gpOut[global.nxtRelayID] != null }
            if { state.gpOut[global.nxtRelayID].pwm > 0 }
                set var.nxtAlreadyOff = false
if { !var.nxtUseGp }
    set var.nxtAlreadyOff = { !state.atxPower }

if { var.nxtAlreadyOff }
    M99

var nxtM81Msg = {"<b>CAUTION</b>: Machine Power is <b>on</b>. Deactivate?<br/>Stops <b>ALL</b> movement and spindle."}
M291 P{var.nxtM81Msg} R"nxt: Safety Net" S4 K{"Deactivate", "Cancel"} F1

if { input == 0 }
    if { var.nxtUseGp }
        M42 P{global.nxtRelayID} S0
    else
        M81
    echo {"nxt: Safety Net - Machine Power Deactivated!<br/>Run <b>M80.9</b> to activate power."}
