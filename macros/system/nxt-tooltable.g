; nxt-tooltable.g — Allocate nxt tool table globals for M4000/M4001.
; Loaded from nxt.g when nxtTT is not already present.

; Legacy MOS SD may still have mosTT/mosET — nxt-mos-globals-align.g copies them first on import.
if { exists(global.mosTT) && !exists(global.nxtTT) }
    global nxtTT = { global.mosTT }
if { exists(global.mosET) && !exists(global.nxtET) }
    global nxtET = { global.mosET }

if { !exists(global.nxtET) }
    ; Template for M4000 writes: [radius, {deflX,deflY}, flutes, fluteLen, tcCapable, tsCapable]
    global nxtET = { 0.0, {0.0, 0.0}, -1, -1.0, 1, 1 }

if { !exists(global.nxtTT) }
    ; null-filled: empty slots stay null in the OM (keeps SBC global JSON under 8KB)
    global nxtTT = { vector(limits.tools, null) }
