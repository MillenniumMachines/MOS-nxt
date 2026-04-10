; nxt-boot.g
; Performs critical sanity checks before allowing NeXT to load.
; CNC mode: meta conditions use { }, not ( ) — see macros/system/RRF_META.txt section 6.

; 1. Confirm RRF is in CNC mode.
if { state.machineMode != "CNC" }
    set global.nxtError = "Machine mode must be CNC (M453)"
    M99

; 2. Confirm Z-axis is configured correctly (max=0, min=negative)
if { move.axes[2].max > 0 || move.axes[2].min >= 0 }
    set global.nxtError = "Z-axis must have max=0 and min<=0"
    M99

; 3. Check for critical user-defined variables (which will come from the UI config)
if { !exists(global.nxtDeltaMachine) }
    set global.nxtError = "Static datum (nxtDeltaMachine) is not defined. Please run the configuration."
    M99

if { !exists(global.nxtProbeToolID) }
    set global.nxtError = "Probe Tool ID (nxtProbeToolID) is not defined. Please run the configuration."
    M99

; --- All checks passed ---

; Initialize probe results table (each row: axis positions + rotation)
var resultVectorSize = { #move.axes + 1 }
while { iterations < #global.nxtProbeResults }
    set global.nxtProbeResults[iterations] = { vector(var.resultVectorSize, 0.0) }

set global.nxtLoaded = true
