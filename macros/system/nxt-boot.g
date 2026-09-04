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

; 2. Confirm Z has usable travel. Macros retract to .max and dive toward .min;
;    absolute origin (max==0) is preferred for Milo packs but not required for Custom.
if { move.axes[2].min >= move.axes[2].max }
    set global.nxtError = "Z-axis min must be less than max"
    M99

; 3. When nxt-user-vars.g is missing, allow DWC Configuration setup (deferred strict checks)
if { exists(global.nxtUserVarsPresent) && !global.nxtUserVarsPresent }
    set global.nxtConfigPending = true
    ; Leave nxtProbeResults rows null until a cycle writes them (OM global ~8KB budget).
    set global.nxtBootOk = true
    echo "nxt: configuration pending — complete setup in DWC Configuration panel and Save nxt-user-vars.g"
    M99

; 4. Full configuration when user-vars file was loaded
; nxt-user-vars.g from Configuration Save may persist null for fields not in the UI — restore defaults.
if { !exists(global.nxtProbeToolID) || global.nxtProbeToolID == null }
    set global.nxtProbeToolID = 49
    echo "[nxt] boot: nxtProbeToolID unset — defaulting to T49 (49)"

if { global.nxtProbeToolID != 49 }
    set global.nxtProbeToolID = 49
    echo "[nxt] boot: nxtProbeToolID normalized to T49 (49)"

; Legacy nxtReservedFrom (dual-slot alias) — clear if present so it does not bloat OM.
if { exists(global.nxtReservedFrom) }
    set global.nxtReservedFrom = null

if { global.nxtFeatureTouchProbe && (!exists(global.nxtDeltaMachine) || global.nxtDeltaMachine == null) }
    set global.nxtConfigPending = true
    set global.nxtError = "Touch probe enabled but nxtDeltaMachine is not set — calibrate static datum in Configuration"
    set global.nxtBootOk = true
    echo "nxt: configuration incomplete (touch probe datum missing) — use DWC Configuration panel"
    M99

; --- All checks passed ---

; Ensure probe tool row matches config (M4000 early-exits when unchanged; no M4001 wipe).
if { exists(global.nxtProbeToolID) && global.nxtProbeToolID != null }
    if { global.nxtProbeToolID < limits.tools }
        M98 P"nxt-probe-tool-sync.g"

; Probe result rows stay null until written (see probing macros / M6521).
set global.nxtConfigPending = false
set global.nxtBootOk = true
