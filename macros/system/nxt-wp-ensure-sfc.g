; nxt-wp-ensure-sfc.g — allocate workplace surface vectors (OM ~8KB lazy pack)
;
; Call before first write of nxtWPSfcPos / SfcAxis.
; Re-entry is a no-op when nxtWPSfcPos already exists.

if { !inputs[state.thisInput].active }
    M99

if { exists(global.nxtWPSfcPos) }
    M99

if { !exists(global.nxtDfltWPSfcPos) }
    global nxtDfltWPSfcPos = null
global nxtWPSfcPos = { vector(limits.workplaces, global.nxtDfltWPSfcPos) }

if { !exists(global.nxtDfltWPSfcAxis) }
    global nxtDfltWPSfcAxis = null
global nxtWPSfcAxis = { vector(limits.workplaces, global.nxtDfltWPSfcAxis) }
