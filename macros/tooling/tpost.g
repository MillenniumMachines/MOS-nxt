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
    ; Touch probe must be measured against reference surface to establish
    ; its length relative to the toolsetter for accurate offset calculations
    
    if { global.nxtDeltaMachine == null }
        M291 P"Touch probe installed but nxtDeltaMachine not calibrated. Please run configuration wizard first." R"Configuration Required" S2
        abort { "tpost.g: nxtDeltaMachine calibration required for touch probe" }
    
    ; Probe the reference surface with the touch probe
    ; This establishes the probe's position relative to the static datum
    echo "tpost.g: Measuring touch probe against reference surface"
    
    ; User must manually position probe near reference surface
    ; ATC: replace with known reference approach position if changer defines it
    M291 P"Please jog the touch probe close to the reference surface, then press OK to continue with automatic measurement." R"Position Touch Probe" S3
    
    ; Probe the reference surface (this should be implemented as a specific cycle)
    ; For now, we'll use a simple Z probe - this may need enhancement
    G6512 Z{move.axes[2].min + 50} I{global.nxtTouchProbeID} R{global.nxtProbeInnerSampleCount}
    
    ; Calculate the touch probe's "virtual" toolsetter position
    ; This allows it to be used in relative offset calculations
    var probeRefPos = { global.nxtLastProbeResult }
    var probeVirtualToolsetterPos = { var.probeRefPos - global.nxtDeltaMachine }
    
    ; Cache this virtual measurement
    set global.nxtToolCache[state.currentTool] = { var.probeVirtualToolsetterPos }
    
    ; Set tool offset to 0 for the touch probe (it defines the reference)
    G10 L1 P{state.currentTool} Z0
    
    echo "tpost.g: Touch probe measured, virtual toolsetter position: " ^ var.probeVirtualToolsetterPos
    
elif { global.nxtFeatureToolSetter && global.nxtToolSetterPos != null }
    ; Standard tool with toolsetter available
    echo "tpost.g: Measuring new tool " ^ state.currentTool
    
    ; Measure the new tool
    G37
    var newToolMeasurement = { global.nxtLastProbeResult }
    
    ; Cache the measurement
    set global.nxtToolCache[state.currentTool] = { var.newToolMeasurement }
    
    ; Calculate relative offset if we have previous tool data
    ; This implements the relative offsetting workflow from TOOLSETTING.md
    
    ; Find the previous tool that was cached (most recent non-null entry)
    var oldToolMeasurement = null
    var oldToolOffset = 0
    var oldToolIndex = -1
    
    ; Look through tool cache to find the most recently measured tool
    while { iterations < #global.nxtToolCache }
        if { iterations != state.currentTool && global.nxtToolCache[iterations] != null }
            set var.oldToolMeasurement = { global.nxtToolCache[iterations] }
            set var.oldToolIndex = { iterations }
            if { iterations < #tools && tools[iterations] != null }
                set var.oldToolOffset = { tools[iterations].offsets[2] } ; Z offset
    
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
    ; No toolsetter available - manual offset required
    M291 P"Toolsetter not available. Please set tool offset manually." R"Manual Offset Required" S2
    echo "tpost.g: Manual tool offset required - no automatic measurement available"

; Clear tool change state to indicate completion
set global.nxtToolChangeState = null

echo "tpost.g: Tool " ^ state.currentTool ^ " change process completed"