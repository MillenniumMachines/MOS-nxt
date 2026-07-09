; nxt-tooltable.g — Allocate nxt tool table globals for M4000/M4001.
; Loaded from nxt.g when nxtTT is not already present.

; Legacy MOS SD may still have mosTT/mosET — nxt-mos-globals-align.g copies them first on import.
if { exists(global.mosTT) && !exists(global.nxtTT) }
    global nxtTT = { global.mosTT }
if { exists(global.mosET) && !exists(global.nxtET) }
    global nxtET = { global.mosET }

if { !exists(global.nxtET) }
    ; [0]=radius, [1]={probe X/Y}, [2]=flutes (-1), [3]=flute len (-1), [4]=tcCapable (1), [5]=tsCapable (1)
    global nxtET = { 0.0, {0.0, 0.0}, -1, -1.0, 1, 1 }

if { !exists(global.nxtTT) }
    global nxtTT = { vector(limits.tools, global.nxtET) }
