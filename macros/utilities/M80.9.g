; M80.9.g: ENABLE MACHINE POWER
;
; Operator-confirmed arm of the motor/VFD contactor.
; Scylla: gpOut nxtRelayID (P5 / PD_5). Other boards: RRF ATX if configured.
; No thisInput.active guard — power arm must work from any operator channel.
;
; USAGE: M80.9

if { !exists(global.nxtFeatureMachinePower) || !global.nxtFeatureMachinePower }
    echo "nxt: Machine power feature is disabled (Configuration)."
    M99

var nxtUseGp = false
if { exists(global.nxtRelayID) && global.nxtRelayID != null }
    if { global.nxtRelayID >= 0 }
        set var.nxtUseGp = true

if { !var.nxtUseGp }
    if { state.atxPowerPort == null }
        echo "nxt: No relay gpOut (nxtRelayID) and no ATX — cannot arm."
        M99

if { exists(sensors.gpIn[0]) && sensors.gpIn[0].value == 1 }
    echo "nxt: Cannot arm — E-stop is pressed."
    M99

var nxtAlreadyOn = false
if { var.nxtUseGp }
    if { global.nxtRelayID < #state.gpOut }
        if { state.gpOut[global.nxtRelayID] != null }
            if { state.gpOut[global.nxtRelayID].pwm > 0 }
                set var.nxtAlreadyOn = true
if { !var.nxtUseGp }
    if { state.atxPower }
        set var.nxtAlreadyOn = true

if { var.nxtAlreadyOn }
    echo "nxt: Machine power already on."
    M99

var nxtM80Msg = {"<b>CAUTION</b>: Machine Power is <b>off</b>. Activate?<br/>Confirm the machine is safe first."}
M291 P{var.nxtM80Msg} R"nxt: Safety Net" S4 K{"Activate", "Cancel"} F0

var nxtM80Choice = input
echo {"nxt: Safety Net choice=" ^ var.nxtM80Choice}
if { var.nxtM80Choice == 0 }
    if { var.nxtUseGp }
        M42 P{global.nxtRelayID} S1
    else
        M80
    echo {"nxt: Safety Net - Machine Power Activated!<br/>Run <b>M81.9</b> to deactivate power."}
else
    echo "nxt: Machine power arm cancelled."
