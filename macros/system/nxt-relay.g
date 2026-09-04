; nxt-relay.g - Motor / VFD contactor safety interlock (UEB)
;
; Optional manual helper: M98 P"nxt-relay.g" (not called from nxt.g boot).
; Boot must not block on M291 — that keeps config.g → nxt.g open and locks SD updates.
; Prefer Status Activate or M80.9 for normal arming.
; Requires board pack gpio.g (M950 P5 C"PD_5") and nxtRelayID.
; S4 + K (not S3): S3 Cancel aborts the calling file.

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

; --- Operator safety gate (S4 + K — Cancel must not abort the caller) ------
var nxtRelayPrompt = {"<b>SAFETY CHECK</b><br/>Confirm the machine is clear and in a safe state."}
var nxtRelayPrompt2 = {"Press <b>Arm</b> to power the drives and VFD, or <b>Leave off</b> to keep them off."}
var nxtRelayPromptFull = { var.nxtRelayPrompt ^ var.nxtRelayPrompt2 }
M291 P{var.nxtRelayPromptFull} R"Safety Check" S4 K{"Arm", "Leave off"} F0

var nxtRelayChoice = input
if { var.nxtRelayChoice == 0 }
    M42 P{global.nxtRelayID} S1          ; gpOut ON - drives / VFD live
    M150 E0 R255 U255 B255 P255 S32 F0   ; solid white - armed and ready
else
    M150 E0 R255 U0 B0 P255 S32 F0       ; stay red
    echo "Relay NOT armed - drives remain unpowered. Use M80.9 or Status to arm."
