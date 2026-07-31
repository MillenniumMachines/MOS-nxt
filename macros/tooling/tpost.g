; tpost.g: TOOL POST-CHANGE - EXECUTED BY RRF AFTER TOOL LOAD
;
; This macro is executed automatically by RepRapFirmware after a new tool
; has been loaded. It implements the relative offset calculation workflow
; and handles special cases for the touch probe.
;
; ATC integration: After physical load, measurement and G10 logic below stay
; relevant; only the manual M291 jog/confirm steps may be replaced by fixed
; positions from a changer pack (docs/TOOLCHANGING.md). Preserve
; nxtToolChangeState (3 -> null) at the end.
;
; NO PARAMETERS - called automatically by RRF

; Validate that tpre.g completed properly
if { global.nxtToolChangeState != 3 }
    abort { "tpost.g: Tool change state invalid. tpre.g must complete before tpost.g" }

; Validate that a tool is actually selected
if { state.currentTool < 0 }
    abort { "tpost.g: No tool selected after tool change" }

; Validate all axes are homed
while { iterations < #move.axes }
    if { !move.axes[iterations].homed }
        abort { "tpost.g: Axis " ^ move.axes[iterations].letter ^ " must be homed after tool change" }

; Set tool change state to indicate tpost.g started
set global.nxtToolChangeState = 4

; Stop and park spindle for safety
G27 Z1

; Handle touch probe special case
if { state.currentTool == global.nxtProbeToolID && global.nxtFeatureTouchProbe }
    ; If a toolsetter is enabled, touch probe must be measured against reference
    ; surface to establish its virtual position for relative offset calculations.
    if { global.nxtFeatureToolSetter && global.nxtToolSetterPos != null }
        if { global.nxtDeltaMachine == null }
            M291 P"Touch probe installed but nxtDeltaMachine not calibrated. Please run configuration wizard first." R"Configuration Required" S2
            abort { "tpost.g: nxtDeltaMachine calibration required for touch probe" }
        echo "tpost.g: Probing touch probe against reference surface (G6511)"
        G6511 S0 R1
        var probeRefPos = { global.nxtLastProbeResult }
        var probeVirtualToolsetterPos = { var.probeRefPos - global.nxtDeltaMachine }
; Cache the measurement (scalar cache — OM budget vs vector(limits.tools))
        set global.nxtToolCacheIdx = { state.currentTool }
        set global.nxtToolCacheZ = { var.probeVirtualToolsetterPos }
        G10 L1 P{state.currentTool} Z0
        echo "tpost.g: Touch probe measured, virtual toolsetter position: " ^ var.probeVirtualToolsetterPos
    else
        ; No toolsetter: keep probe active without forcing reference probing.
        set global.nxtToolCacheIdx = -1
        set global.nxtToolCacheZ = null
        G10 L1 P{state.currentTool} Z0
        echo "tpost.g: Touch probe loaded (toolsetter disabled, reference probing skipped)"
    
elif { global.nxtFeatureToolSetter && global.nxtToolSetterPos != null }
    ; Standard tool with toolsetter available
    echo "tpost.g: Measuring new tool " ^ state.currentTool

    if { global.nxtToolSetterID == null }
        abort { "tpost.g: Toolsetter probe ID (nxtToolSetterID) is not configured" }
    if { !exists(global.nxtToolSetterPos) || global.nxtToolSetterPos == null || #global.nxtToolSetterPos < 3 }
        abort { "tpost.g: Toolsetter position (nxtToolSetterPos) must be a 3-value vector" }

    var tsX = global.nxtToolSetterPos[0]
    var tsY = global.nxtToolSetterPos[1]
    var tsZ = global.nxtToolSetterPos[2]
    var tsTravel = { exists(global.nxtToolSetterProbeTravelMm) && global.nxtToolSetterProbeTravelMm > 0 ? global.nxtToolSetterProbeTravelMm : 80.0 }
    var tsProbeTargetZ = { var.tsZ - var.tsTravel }
    if { var.tsProbeTargetZ < move.axes[2].min }
        set var.tsProbeTargetZ = { move.axes[2].min }
    var tsProbeTravelAvail = { var.tsZ - var.tsProbeTargetZ }
    if { var.tsProbeTravelAvail < 5.0 }
        var msgTsShort = "tpost.g: Not enough Z travel below nxtToolSetterPos"
        abort { var.msgTsShort ^ " (need >= 5mm toward Zmin — check platen Z)" }
    var tsSamplesRaw = { exists(global.nxtToolSetterInnerSampleCount) && global.nxtToolSetterInnerSampleCount > 0 ? global.nxtToolSetterInnerSampleCount : global.nxtProbeInnerSampleCount }
    var tsSamples = { var.tsSamplesRaw < 2 ? 2 : var.tsSamplesRaw }
    var tsTol = { exists(global.nxtToolSetterMaxSampleSpreadMm) && global.nxtToolSetterMaxSampleSpreadMm >= 0 ? global.nxtToolSetterMaxSampleSpreadMm : global.nxtProbeMaxSampleSpreadMm }
    var tsHasOuterRetries = { exists(global.nxtToolSetterSampleOuterRetries) && global.nxtToolSetterSampleOuterRetries >= 0 }
    var tsOuterRetries = { var.tsHasOuterRetries ? floor(global.nxtToolSetterSampleOuterRetries) : global.nxtProbeSampleOuterRetries }
    var tsRoughSpeed = { sensors.probes[global.nxtToolSetterID].speeds[0] }
    var tsFineSpeed = { sensors.probes[global.nxtToolSetterID].speeds[1] }
    if { var.tsFineSpeed == var.tsRoughSpeed }
        set var.tsFineSpeed = { var.tsRoughSpeed / 5 }

    ; Measure at configured toolsetter position using explicit two-stage probing:
    ; 1) fast seek to find contact quickly, 2) slow pass for final measurement.
    G53 G0 X{var.tsX} Y{var.tsY}
    echo "tpost.g: Toolsetter fast seek"
    G6512 Z{var.tsProbeTargetZ} I{global.nxtToolSetterID} F{var.tsRoughSpeed} R1 L0 O0
    echo "tpost.g: Toolsetter slow confirm"
    G6512 Z{var.tsProbeTargetZ} I{global.nxtToolSetterID} F{var.tsFineSpeed} R{var.tsSamples} L{var.tsTol} O{var.tsOuterRetries}
    var newToolMeasurement = { global.nxtLastProbeResult }
    
    ; Cache the measurement (read previous tool from scalar cache before overwrite)
    var oldToolMeasurement = null
    var oldToolOffset = 0
    var oldToolIndex = -1

    if { exists(state.previousTool) && state.previousTool >= 0 }
        set var.oldToolIndex = { state.previousTool }

    if { var.oldToolIndex >= 0 && exists(global.nxtToolCacheIdx) && global.nxtToolCacheIdx == var.oldToolIndex }
        if { exists(global.nxtToolCacheZ) && global.nxtToolCacheZ != null }
            set var.oldToolMeasurement = { global.nxtToolCacheZ }
            if { var.oldToolIndex < #tools && tools[var.oldToolIndex] != null }
                set var.oldToolOffset = { tools[var.oldToolIndex].offsets[2] }

    set global.nxtToolCacheIdx = { state.currentTool }
    set global.nxtToolCacheZ = { var.newToolMeasurement }
    
    if { var.oldToolMeasurement != null }
        ; Calculate relative offset: new_offset = old_offset + (new_measurement - old_measurement)
        var lengthDiff = { var.newToolMeasurement - var.oldToolMeasurement }
        var newOffset = { var.oldToolOffset + var.lengthDiff }
        
        ; Apply the calculated offset
        G10 L1 P{state.currentTool} Z{var.newOffset}
        
        echo "tpost.g: Relative offset calculated - Tool " ^ var.oldToolIndex ^ " to Tool " ^ state.currentTool
        echo "tpost.g: Length difference: " ^ var.lengthDiff ^ "mm, New offset: " ^ var.newOffset ^ "mm"
    else
        ; No previous tool data - this is the first measured tool
        ; Set its offset to 0 to establish a reference
        G10 L1 P{state.currentTool} Z0
        echo "tpost.g: First measured tool - offset set to 0 (establishes reference)"
else
    ; No toolsetter — re-zero Z origin in current WCS with the installed tool.
    echo "tpost.g: Toolsetter unavailable — running G37.1 to set Z origin"
    G37.1

; Clear tool change state to indicate completion
set global.nxtToolChangeState = null

echo "tpost.g: Tool " ^ state.currentTool ^ " change process completed"