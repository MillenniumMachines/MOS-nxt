; nxt-tooltable.g — Allocate MillenniumOS-compatible tool table globals for M4000/M4001.
; Loaded from nxt.g when mosTT is not already present (e.g. skipped if mos-vars.g ran for MOS import).

if { !exists(global.mosET) }
    ; [0]=radius, [1]={probe X/Y deflection}, [2]=flute count (-1 unset), [3]=flute length mm (-1 unset)
    global mosET = { 0.0, {0.0, 0.0}, -1, -1.0 }

if { !exists(global.mosTT) }
    global mosTT = { vector(limits.tools, global.mosET) }
