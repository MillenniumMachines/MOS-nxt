; nxt-tooltable.g — Allocate MillenniumOS-compatible tool table globals for M4000/M4001.
; Loaded from nxt.g when mosTT is not already present (e.g. skipped if mos-vars.g ran for MOS import).

if { !exists(global.mosET) }
    ; [0]=radius, [1]={probe X/Y}, [2]=flutes (-1), [3]=flute len (-1), [4]=tcCapable (1), [5]=tsCapable (1)
    global mosET = { 0.0, {0.0, 0.0}, -1, -1.0, 1, 1 }

if { !exists(global.mosTT) }
    global mosTT = { vector(limits.tools, global.mosET) }
