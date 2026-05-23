; nxt-boot.g
; Performs critical sanity checks before allowing NeXT to load.
; CNC mode: meta conditions use { }, not ( ) — see macros/system/RRF_META.txt section 6.

set global.nxtLoaded = false
set global.nxtError = null

; 1. Confirm RRF is in CNC mode (nxt.g runs M453 immediately before this file).
if { state.machineMode != "CNC" }
    set global.nxtError = "Machine mode must be CNC (M453)"
    M99

; 2. Confirm Z-axis is configured correctly (max=0, min=negative)
if { move.axes[2].max > 0 || move.axes[2].min >= 0 }
    set global.nxtError = "Z-axis must have max=0 and min<=0"
    M99

; 3. When nxt-user-vars.g is missing, allow DWC Configuration setup (deferred strict checks)
if { exists(global.nxtUserVarsPresent) && !global.nxtUserVarsPresent }
    set global.nxtConfigPending = true
    var resultVectorSize = { #move.axes + 1 }
    while { iterations < #global.nxtProbeResults }
        set global.nxtProbeResults[iterations] = { vector(var.resultVectorSize, 0.0) }
    set global.nxtLoaded = true
    echo "NeXT: configuration pending — complete setup in DWC Configuration panel and Save nxt-user-vars.g"
    M99

; 4. User-vars on SD but incomplete — allow DWC Configuration (same as missing file)
if { !exists(global.nxtDeltaMachine) || global.nxtDeltaMachine == null }
    set global.nxtConfigPending = true
    set global.nxtError = "Static datum (nxtDeltaMachine) is not defined — open Configuration and Save."
    var resultVectorSize = { #move.axes + 1 }
    while { iterations < #global.nxtProbeResults }
        set global.nxtProbeResults[iterations] = { vector(var.resultVectorSize, 0.0) }
    set global.nxtLoaded = true
    echo "NeXT: configuration incomplete (nxtDeltaMachine) — use DWC Configuration panel"
    M99

if { !exists(global.nxtProbeToolID) || global.nxtProbeToolID == null }
    set global.nxtConfigPending = true
    set global.nxtError = "Probe Tool ID (nxtProbeToolID) is not defined — open Configuration and Save."
    var resultVectorSize = { #move.axes + 1 }
    while { iterations < #global.nxtProbeResults }
        set global.nxtProbeResults[iterations] = { vector(var.resultVectorSize, 0.0) }
    set global.nxtLoaded = true
    echo "NeXT: configuration incomplete (nxtProbeToolID) — use DWC Configuration panel"
    M99

; --- All checks passed ---

var resultVectorSize = { #move.axes + 1 }
while { iterations < #global.nxtProbeResults }
    set global.nxtProbeResults[iterations] = { vector(var.resultVectorSize, 0.0) }

set global.nxtConfigPending = false
set global.nxtLoaded = true
