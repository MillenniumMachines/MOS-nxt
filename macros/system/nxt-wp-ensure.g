; nxt-wp-ensure.g — allocate workplace Ctr / Dims / Rad (not Deg, not Cnr/Sfc)
;
; Lazy OM: nxt-probe-wcs.g keeps nxtWPDeg always-on for M5011.
; Call before first write of nxtWPCtrPos / Dims / DimsErr / Rad.
; Corners: nxt-wp-ensure-cnr.g. Surfaces: nxt-wp-ensure-sfc.g.
; Re-entry is a no-op when nxtWPCtrPos already exists.

if { !inputs[state.thisInput].active }
    M99

if { exists(global.nxtWPCtrPos) }
    M99

if { !exists(global.nxtDfltWPCtrPos) }
    global nxtDfltWPCtrPos = { null, null }
global nxtWPCtrPos = { vector(limits.workplaces, global.nxtDfltWPCtrPos) }

if { !exists(global.nxtDfltWPRad) }
    global nxtDfltWPRad = null
global nxtWPRad = { vector(limits.workplaces, global.nxtDfltWPRad) }

if { !exists(global.nxtDfltWPDims) }
    global nxtDfltWPDims = { null, null }
global nxtWPDims = { vector(limits.workplaces, global.nxtDfltWPDims) }

if { !exists(global.nxtDfltWPDimsErr) }
    global nxtDfltWPDimsErr = { null, null }
global nxtWPDimsErr = { vector(limits.workplaces, global.nxtDfltWPDimsErr) }
