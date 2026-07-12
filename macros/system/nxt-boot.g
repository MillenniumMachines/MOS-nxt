; nxt-boot.g
; Performs critical sanity checks before allowing nxt to load.
; CNC mode: meta conditions use { }, not ( ) — see macros/system/RRF_META.txt section 6.
; Does NOT set global.nxtLoaded — nxt.g sets that after nxt-user-overrides.g.

set global.nxtLoaded = false
set global.nxtBootOk = false
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
    set global.nxtBootOk = true
    echo "nxt: configuration pending — complete setup in DWC Configuration panel and Save nxt-user-vars.g"
    M99

; 4. Full configuration when user-vars file was loaded
; nxt-user-vars.g from Configuration Save may persist null for fields not in the UI — restore defaults.
if { !exists(global.nxtProbeToolID) || global.nxtProbeToolID == null }
    set global.nxtProbeToolID = { limits.tools - 1 }
    echo "[nxt] boot: nxtProbeToolID unset — defaulting to last tool index " ^ global.nxtProbeToolID

if { !exists(global.nxtReservedFrom) || global.nxtReservedFrom == null }
    set global.nxtReservedFrom = { limits.tools - 1 }

; Normalize probe slot to last index (single-slot T49 model).
if { global.nxtProbeToolID != limits.tools - 1 }
    set global.nxtProbeToolID = { limits.tools - 1 }
    set global.nxtReservedFrom = { limits.tools - 1 }

if { global.nxtFeatureTouchProbe && (!exists(global.nxtDeltaMachine) || global.nxtDeltaMachine == null) }
    set global.nxtConfigPending = true
    set global.nxtError = "Touch probe enabled but nxtDeltaMachine is not set — calibrate static datum in Configuration"
    var resultVectorSize = { #move.axes + 1 }
    while { iterations < #global.nxtProbeResults }
        set global.nxtProbeResults[iterations] = { vector(var.resultVectorSize, 0.0) }
    set global.nxtBootOk = true
    echo "nxt: configuration incomplete (touch probe datum missing) — use DWC Configuration panel"
    M99

; --- All checks passed ---

; Rebuild probe/datum tool at nxtProbeToolID (clears stale row, then nxt-probe-tool-sync with K1).
if { exists(global.nxtProbeToolID) && global.nxtProbeToolID != null }
    if { global.nxtProbeToolID < limits.tools }
        M4001 P{global.nxtProbeToolID}
        M98 P"nxt-probe-tool-sync.g"

var resultVectorSize = { #move.axes + 1 }
while { iterations < #global.nxtProbeResults }
    set global.nxtProbeResults[iterations] = { vector(var.resultVectorSize, 0.0) }

set global.nxtConfigPending = false
set global.nxtBootOk = true
