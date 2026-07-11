; nxt-workzero.g - MOVE TO WCS ORIGIN (X0 Y0 Z0)
;
; Parks at clearance, moves to X=0 Y=0 in the current workplace, then optionally down to Z=0.

G90
G21
G94

G27 Z1

if { global.nxtTutorialMode }
    var nxtWzMsg1 = { "We will now move above X=0, Y=0 in WCS " ^ move.workplaceNumber+1 ^ " and then down to Z=" ^ global.nxtClearance ^ "mm.<br/>Press <b>Continue</b> to proceed!" }
    M291 P{var.nxtWzMsg1} R"nxt: Go to Zero" T0 S4 K{ "Continue", "Cancel" }
    if { input != 0 }
        abort { "Operator aborted move to X=0, Y=0!" }

G0 X0 Y0
G0 Z{global.nxtClearance}

var nxtWzMsg2 = { "Move to Z=0?<br/>Click <b>Continue</b> if you are sure the tool is " ^ global.nxtClearance ^ "mm above the origin, otherwise <b>Cancel</b>!" }
M291 P{var.nxtWzMsg2} R"nxt: Go to Zero" T0 S4 K{ "Continue", "Cancel" }
if { input != 0 }
    abort { "Operator aborted move to Z=0!" }

G1 Z0 F{global.nxtManualProbeFeeds[2]}
