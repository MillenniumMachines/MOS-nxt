; nxt-relay.g - Motor / VFD contactor safety interlock (UEB)
;
; SAFETY-CRITICAL. Loaded by nxt.g when 0:/sys/estop.g and trigger2.g exist.
; Requires board pack gpio.g (M950 P5 C"PD_5") and nxtRelayID.
; Adds operator safety dialog then M42 S1. Early RGB on PD_6; nxt.g re-applies strip later.

; --- Status LED strip: create and show RED (not armed) ---------------------
M950 E0 C"PD_6" T1 U32                  ; RGB NeoPixel, 32 LEDs, on PD_6
M150 E0 R255 U0 B0 P255 S32 F0          ; solid red

; --- Refuse to arm if the E-stop is currently pressed ----------------------
; estop.g (loaded in board pack) defines the E-stop input as gpIn 0.
if { exists(sensors.gpIn[0]) && sensors.gpIn[0].value == 1 }
    M150 E0 R255 U0 B0 P255 S32 F0       ; stay red
    var nxtEstopMsg = {"<b>E-STOP IS PRESSED</b><br/>Release the emergency stop, then reboot (M999) to arm the drives and VFD."}
    M291 P{var.nxtEstopMsg} R"Safety Check" S2 T0
    echo "E-stop pressed - drives remain unpowered until released and re-armed."
    M99                                   ; done - leave disarmed

if { !exists(global.nxtFeatureMachinePower) || !global.nxtFeatureMachinePower }
    echo "nxt: Machine power feature is disabled — leaving relay off."
    M99

if { !exists(global.nxtRelayID) || global.nxtRelayID == null }
    echo "nxt: nxtRelayID unset — cannot arm motor/VFD relay."
    M99

; --- Operator safety gate (blocks here until answered) ---------------------
var nxtRelayPrompt = {"<b>SAFETY CHECK</b><br/>Confirm the machine is clear and in a safe state."}
var nxtRelayPrompt2 = {"Press <b>OK</b> to arm the relay and power the drives and VFD, or <b>Cancel</b> to leave them off."}
var nxtRelayPromptFull = { var.nxtRelayPrompt ^ var.nxtRelayPrompt2 }
M291 P{var.nxtRelayPromptFull} R"Safety Check" S3 T0

if { result == 0 }
    M42 P{global.nxtRelayID} S1          ; gpOut ON - drives / VFD live
    M150 E0 R255 U255 B255 P255 S32 F0   ; solid white - armed and ready
else
    M150 E0 R255 U0 B0 P255 S32 F0       ; stay red
    echo "Relay NOT armed - drives remain unpowered. Reboot (M999) to re-arm."
