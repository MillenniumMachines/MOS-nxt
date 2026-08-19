; nxt-wp-ensure-cnr.g — allocate workplace corner vectors (OM ~8KB lazy pack)
;
; Call before first write of nxtWPCnrNum / CnrPos / CnrDeg.
; Re-entry is a no-op when nxtWPCnrNum already exists.

if { !inputs[state.thisInput].active }
    M99

if { exists(global.nxtWPCnrNum) }
    M99

if { !exists(global.nxtDfltWPCnrNum) }
    global nxtDfltWPCnrNum = null
global nxtWPCnrNum = { vector(limits.workplaces, global.nxtDfltWPCnrNum) }

if { !exists(global.nxtDfltWPCnrPos) }
    global nxtDfltWPCnrPos = { null, null }
global nxtWPCnrPos = { vector(limits.workplaces, global.nxtDfltWPCnrPos) }

if { !exists(global.nxtDfltWPCnrDeg) }
    global nxtDfltWPCnrDeg = null
global nxtWPCnrDeg = { vector(limits.workplaces, global.nxtDfltWPCnrDeg) }
