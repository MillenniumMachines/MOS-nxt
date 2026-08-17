; nxt-wp-ensure.g — allocate workplace metadata vectors (not nxtWPDeg)
;
; Lazy OM: nxt-probe-wcs.g keeps nxtWPDeg always-on for M5011.
; Call before first write of nxtWPCtrPos / Dims / Cnr* / Sfc* / Rad.
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

if { !exists(global.nxtDfltWPCnrNum) }
    global nxtDfltWPCnrNum = null
global nxtWPCnrNum = { vector(limits.workplaces, global.nxtDfltWPCnrNum) }

if { !exists(global.nxtDfltWPCnrPos) }
    global nxtDfltWPCnrPos = { null, null }
global nxtWPCnrPos = { vector(limits.workplaces, global.nxtDfltWPCnrPos) }

if { !exists(global.nxtDfltWPCnrDeg) }
    global nxtDfltWPCnrDeg = null
global nxtWPCnrDeg = { vector(limits.workplaces, global.nxtDfltWPCnrDeg) }

if { !exists(global.nxtDfltWPSfcPos) }
    global nxtDfltWPSfcPos = null
global nxtWPSfcPos = { vector(limits.workplaces, global.nxtDfltWPSfcPos) }

if { !exists(global.nxtDfltWPSfcAxis) }
    global nxtDfltWPSfcAxis = null
global nxtWPSfcAxis = { vector(limits.workplaces, global.nxtDfltWPSfcAxis) }
