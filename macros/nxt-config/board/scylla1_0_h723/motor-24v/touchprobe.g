; touchprobe.g — Scylla touch probe K0 on PE_15 (pinmap E.15).
; P5 = filtered digital (debounce). Override with 0:/sys/touchprobe.g.
; Polarity follows global.nxtTouchProbeInvert (default true → active-low !).

var nxtTpInv = true
if { exists(global.nxtTouchProbeInvert) }
    set var.nxtTpInv = { global.nxtTouchProbeInvert }

if { var.nxtTpInv }
    M558 K0 P5 C"!PE_15" H2 A10 S0.01 T1200 F200:50
else
    M558 K0 P5 C"PE_15" H2 A10 S0.01 T1200 F200:50
