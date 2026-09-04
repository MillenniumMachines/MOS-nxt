; nxt-probe-virtual-clear.g — Explicit invalidate of mill length datum.
; Does not clear mill session cache until reboot.

if { !inputs[state.thisInput].active }
    M99

if { exists(global.nxtProbeVirtualTsZ) }
    set global.nxtProbeVirtualTsZ = null
if { exists(global.nxtRefSurfaceProbed) }
    set global.nxtRefSurfaceProbed = false
if { exists(global.nxtToolCacheIdx) }
    if { exists(global.nxtProbeToolID) }
        if { global.nxtToolCacheIdx == global.nxtProbeToolID }
            set global.nxtToolCacheIdx = -1
            set global.nxtToolCacheZ = null

M98 P"nxt-probe-virtual-sync.g"
echo "nxt-probe-virtual-clear: probe virtual cleared"
