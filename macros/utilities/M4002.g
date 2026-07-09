; M4002.g: CLEAR ALL USER TOOLS
;
; Removes every defined tool EXCEPT the probe/datum slot (nxtProbeToolID), which is
; regenerated from config at boot and must survive. Used by Tool Library replace import.

if { !inputs[state.thisInput].active }
    M99

if { !exists(global.mosTT) }
    M99

var prevPersist = true
if { exists(global.nxtAutoPersistTools) }
    set var.prevPersist = { global.nxtAutoPersistTools }
    set global.nxtAutoPersistTools = false

var i = 0
while { var.i < limits.tools }
    if { exists(global.nxtReservedFrom) && var.i >= global.nxtReservedFrom }
        set var.i = { var.i + 1 }
        continue
    if { var.i < #tools && tools[var.i] != null }
        M4001 P{var.i}
    set var.i = { var.i + 1 }

if { exists(global.nxtAutoPersistTools) }
    set global.nxtAutoPersistTools = { var.prevPersist }
if { (!exists(global.nxtUserToolsLoadDepth) || global.nxtUserToolsLoadDepth < 1) }
    if { !exists(global.nxtAutoPersistTools) || global.nxtAutoPersistTools }
        M98 P"nxt-user-tools-sync.g"

echo "nxt: tool table cleared (probe/datum slot kept)"
