; tpre.g: TOOL PRE-CHANGE - EXECUTED BY RRF BEFORE TOOL LOAD
;
; This macro is executed automatically by RepRapFirmware before a new tool
; is loaded. It validates the tool change state and prepares for offset
; calculation based on the relative offsetting workflow.
;
; ATC integration: Default path uses M291 for manual load. Automatic changer:
; replace prompts with pick-from-pocket motion or M98 to extension macros
; (docs/TOOLCHANGING.md). Preserve nxtToolChangeState (2 -> 3).
;
; NO PARAMETERS - called automatically by RRF

; Validate sequencing: tfree.g should have completed when switching from an active tool.
; First selection from no active tool skips tfree.g in RRF, so allow nxtToolChangeState=null there.
if { state.currentTool >= 0 && global.nxtToolChangeState != 2 }
    echo "tpre.g: Warning - tfree state missing (value " ^ global.nxtToolChangeState ^ "), continuing tool load"

; Validate all axes are homed
while { iterations < #move.axes }
    if { !move.axes[iterations].homed }
        abort { "tpre.g: Axis " ^ move.axes[iterations].letter ^ " must be homed before tool change" }

; Set tool change state to indicate tpre.g started
set global.nxtToolChangeState = 3

; Stop and park spindle for safety
G27 Z1

; Get the tool number that will be loaded (from the pending tool change)
var newTool = { state.nextTool }

if { var.newTool < 0 }
    abort { "tpre.g: No valid tool selected for loading" }

; Prompt user to install the new tool
if { var.newTool == global.nxtProbeToolID }
    var probeType = { global.nxtFeatureTouchProbe ? "Touch Probe" : "Datum Tool" }
    ; ATC: replace with pick from pocket / spindle load sequence for probe
    M291 P{"WARNING: Install " ^ var.probeType ^ " (T" ^ var.newTool ^ "), then confirm."} R{"Install " ^ var.probeType} S3
    if { global.nxtFeatureTouchProbe }
        if { global.nxtTouchProbeID == null }
            abort { "tpre.g: Touch probe sensor ID (nxtTouchProbeID) is not configured" }
        var probeReady = { false }
        if { global.nxtTouchProbeID < #sensors.probes }
            set var.probeReady = { sensors.probes[global.nxtTouchProbeID].value[0] >= sensors.probes[global.nxtTouchProbeID].threshold }
        if { !var.probeReady }
            M291 P{"WARNING: Trigger touch probe sensor " ^ global.nxtTouchProbeID ^ " now, then confirm."} R"Touch Probe Check" S3
            if { global.nxtTouchProbeID < #sensors.probes }
                set var.probeReady = { sensors.probes[global.nxtTouchProbeID].value[0] >= sensors.probes[global.nxtTouchProbeID].threshold }
        if { !var.probeReady }
            abort { "tpre.g: Touch probe is not active/triggered after confirmation" }
else
    ; ATC: replace with pick from pocket / spindle load sequence
    M291 P{"Please install Tool " ^ var.newTool ^ " and confirm when ready."} R"Install Tool" S3

echo "tpre.g: Ready to load Tool " ^ var.newTool