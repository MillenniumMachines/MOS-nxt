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
;
; Operator Cancel in tpre/tfree: skip measure. Do not abort (abort in
; tool-change macros leaves Tn / Changing Tool stuck). Soft-fail → echo,
; clear nxtToolChangeState, M99. Do not issue T — nested T re-runs tpre.

if { exists(global.nxtToolChangeCancelled) && global.nxtToolChangeCancelled }
    set global.nxtToolChangeCancelled = false
    set global.nxtToolChangeState = null
    echo "tpost.g: tool change cancelled — skip measure"
    M99

; Validate that tpre.g completed properly (soft skip — never abort)
if { global.nxtToolChangeState != 3 }
    set global.nxtToolChangeState = null
    echo "tpost.g: invalid state (expected tpre done) — soft skip measure"
    M99

; Validate that a tool is actually selected
if { state.currentTool < 0 }
    set global.nxtToolChangeState = null
    echo "tpost.g: no tool selected — soft skip measure"
    M99

; Validate all axes are homed
var nxtToHomed = true
while { iterations < #move.axes }
    if { !move.axes[iterations].homed }
        set var.nxtToHomed = false
if { !var.nxtToHomed }
    set global.nxtToolChangeState = null
    echo "tpost.g: axes not homed — soft skip measure"
    M99

; Previous tool (-1 = first select). Same T: RRF usually skips tpost; do not zero L1.
var nxtPrevTool = -1
if { exists(move.motionSystems) && #move.motionSystems > 0 }
    set var.nxtPrevTool = { move.motionSystems[0].previousTool }
elif { exists(state.previousTool) }
    set var.nxtPrevTool = { state.previousTool }
if { var.nxtPrevTool == state.currentTool }
    set global.nxtToolChangeState = null
    echo "tpost.g: same tool T" ^ state.currentTool ^ " — skip measure"
    M99

; Set tool change state to indicate tpost.g started
set global.nxtToolChangeState = 4

; Drain leftover G38 before omit-XY park
M98 P"nxt-g38-cancel.g"

; Incoming mill/probe L1 from last job would contaminate M5000 Z_act
G10 L1 P{state.currentTool} Z0
echo "tpost.g: incoming L1 Z0 (was T" ^ var.nxtPrevTool ^ " -> T" ^ state.currentTool ^ ")"

; Stop and park spindle for safety
G27 Z1

; Handle touch probe special case
if { state.currentTool == global.nxtProbeToolID && global.nxtFeatureTouchProbe }
    ; Every T49: G6511 on saved nxtTouchProbeRefPos (not the setter pad).
    if { global.nxtFeatureToolSetter && global.nxtToolSetterPos != null }
        ; Preflight — G6511 abort would stick Changing Tool; soft-skip instead
        var nxtG6511Ok = true
        if { !exists(global.nxtDeltaMachine) || global.nxtDeltaMachine == null }
            set var.nxtG6511Ok = false
            echo "tpost.g: nxtDeltaMachine unset — skip G6511 (run M5016)"
        if { var.nxtG6511Ok }
            if { !exists(global.nxtTouchProbeRefPos) || global.nxtTouchProbeRefPos == null }
                set var.nxtG6511Ok = false
                echo "tpost.g: nxtTouchProbeRefPos unset — skip G6511 (run M5016)"
        if { var.nxtG6511Ok }
            echo "tpost.g: Probe install — G6511 R1 S0 (reference surface)"
            G6511 R1 S0
            var nxtHaveVirt = false
            if { exists(global.nxtProbeVirtualTsZ) }
                if { global.nxtProbeVirtualTsZ != null }
                    set var.nxtHaveVirt = true
            set global.nxtToolCacheIdx = { state.currentTool }
            if { var.nxtHaveVirt }
                set global.nxtToolCacheZ = { global.nxtProbeVirtualTsZ }
            else
                set global.nxtToolCacheZ = null
            G10 L1 P{state.currentTool} Z0
            echo "tpost.g: Touch probe loaded (L1 Z0); mill datum=" ^ global.nxtProbeVirtualTsZ
        else
            set global.nxtToolCacheIdx = { state.currentTool }
            set global.nxtToolCacheZ = null
            G10 L1 P{state.currentTool} Z0
            echo "tpost.g: Touch probe loaded without G6511 (datum incomplete)"
    else
        ; No toolsetter: keep probe active without a mill length datum.
        set global.nxtToolCacheIdx = -1
        set global.nxtToolCacheZ = null
        G10 L1 P{state.currentTool} Z0
        echo "tpost.g: Touch probe loaded (toolsetter disabled)"
    
elif { global.nxtFeatureToolSetter && global.nxtToolSetterPos != null }
    ; Standard tool with toolsetter available
    echo "tpost.g: Measuring new tool " ^ state.currentTool

    var nxtTsMeasureOk = true
    if { global.nxtToolSetterID == null }
        set var.nxtTsMeasureOk = false
        echo "tpost.g: nxtToolSetterID unset — skip measure"
    if { var.nxtTsMeasureOk }
        if { !exists(global.nxtToolSetterPos) || global.nxtToolSetterPos == null || #global.nxtToolSetterPos < 3 }
            set var.nxtTsMeasureOk = false
            echo "tpost.g: nxtToolSetterPos invalid — skip measure"

    if { !var.nxtTsMeasureOk }
        G27
        set global.nxtToolChangeState = null
        echo "tpost.g: measure skipped — tool change complete (no abort)"
        M99

    var tsX = global.nxtToolSetterPos[0]
    var tsY = global.nxtToolSetterPos[1]
    var tsZ = global.nxtToolSetterPos[2]
    var tsTravel = { exists(global.nxtToolSetterProbeTravelMm) && global.nxtToolSetterProbeTravelMm > 0 ? global.nxtToolSetterProbeTravelMm : 80.0 }
    var tsProbeTargetZ = { var.tsZ - var.tsTravel }
    if { var.tsProbeTargetZ < move.axes[2].min }
        set var.tsProbeTargetZ = { move.axes[2].min }
    var tsProbeTravelAvail = { var.tsZ - var.tsProbeTargetZ }
    if { var.tsProbeTravelAvail < 5.0 }
        echo "tpost.g: not enough Z travel below platen — skip measure"
        G27
        set global.nxtToolChangeState = null
        M99
    var tsSamplesRaw = { exists(global.nxtToolSetterInnerSampleCount) && global.nxtToolSetterInnerSampleCount > 0 ? global.nxtToolSetterInnerSampleCount : global.nxtProbeInnerSampleCount }
    var tsSamples = { var.tsSamplesRaw < 2 ? 2 : var.tsSamplesRaw }
    ; Platen default 0.02 mm — do not inherit touch-probe 0.0075 unless override is set
    var tsTol = 0.02
    if { exists(global.nxtToolSetterMaxSampleSpreadMm) }
        if { global.nxtToolSetterMaxSampleSpreadMm >= 0 }
            set var.tsTol = { global.nxtToolSetterMaxSampleSpreadMm }
    var tsHasOuterRetries = { exists(global.nxtToolSetterSampleOuterRetries) && global.nxtToolSetterSampleOuterRetries >= 0 }
    var tsOuterRetries = { var.tsHasOuterRetries ? floor(global.nxtToolSetterSampleOuterRetries) : global.nxtProbeSampleOuterRetries }
    var tsRoughSpeed = { sensors.probes[global.nxtToolSetterID].speeds[0] }
    var tsFineSpeed = { sensors.probes[global.nxtToolSetterID].speeds[1] }
    if { var.tsFineSpeed == var.tsRoughSpeed }
        set var.tsFineSpeed = { var.tsRoughSpeed / 5 }

    ; XY only after Z max (omit-Z after G38 is unsafe)
    G53 G0 Z{move.axes[2].max}
    G53 G0 X{var.tsX} Y{var.tsY}
    echo "tpost.g: Toolsetter fast seek"
    G6512 Z{var.tsProbeTargetZ} I{global.nxtToolSetterID} F{var.tsRoughSpeed} R1 L0 O0
    echo "tpost.g: Toolsetter slow confirm"
    G6512 Z{var.tsProbeTargetZ} I{global.nxtToolSetterID} F{var.tsFineSpeed} R{var.tsSamples} L{var.tsTol} O{var.tsOuterRetries}
    var newToolMeasurement = { global.nxtLastProbeResult }
    M98 P"nxt-g38-cancel.g"
    ; Raise to machine Z0 off the platen before G10 / dialogs
    G90
    var tsHasA = { #move.axes > 3 }
    if { var.tsHasA }
        var tsA = { move.axes[3].machinePosition }
        G53 G0 X{var.tsX} Y{var.tsY} Z0 A{var.tsA}
    else
        G53 G0 X{var.tsX} Y{var.tsY} Z0
    M400
    echo "tpost.g: raised to machine Z0 off toolsetter"

    var oldToolMeasurement = null
    var oldToolOffset = 0
    var oldToolIndex = { var.nxtPrevTool }

    echo "tpost.g: previousTool=" ^ var.oldToolIndex ^ " cacheIdx=" ^ global.nxtToolCacheIdx

    var nxtHasCacheZ = false
    if { exists(global.nxtToolCacheIdx) }
        if { exists(global.nxtToolCacheZ) }
            if { global.nxtToolCacheZ != null }
                if { global.nxtToolCacheIdx >= 0 }
                    set var.nxtHasCacheZ = true

    var nxtHaveVirt = false
    if { exists(global.nxtProbeVirtualTsZ) }
        if { global.nxtProbeVirtualTsZ != null }
            set var.nxtHaveVirt = true
    if { !var.nxtHaveVirt }
        if { exists(global.nxtToolSetterPos) }
            if { global.nxtToolSetterPos != null }
                if { #global.nxtToolSetterPos >= 3 }
                    if { global.nxtToolSetterPos[2] != null }
                        if { !exists(global.nxtProbeVirtualTsZ) }
                            global nxtProbeVirtualTsZ = { global.nxtToolSetterPos[2] }
                        else
                            set global.nxtProbeVirtualTsZ = { global.nxtToolSetterPos[2] }
                        set var.nxtHaveVirt = true

    var snapCacheZ = { global.nxtToolCacheZ }
    var snapCacheIdx = { global.nxtToolCacheIdx }

    set global.nxtToolCacheIdx = { state.currentTool }
    set global.nxtToolCacheZ = { var.newToolMeasurement }

    if { var.nxtHaveVirt }
        ; MOS G37 with touch probe: L1 = -(Z_act - TSAP); probe stays Z0
        var nxtVirt = { global.nxtProbeVirtualTsZ }
        var lengthDiff = { var.newToolMeasurement - var.nxtVirt }
        var newOffset = { 0 - var.lengthDiff }
        G10 L1 P{state.currentTool} Z{var.newOffset}
        echo "tpost.g: Z_act=" ^ var.newToolMeasurement ^ " virtual=" ^ var.nxtVirt
        echo "tpost.g: Offset=" ^ var.newOffset ^ " mm"
    elif { var.nxtHasCacheZ }
        set var.oldToolMeasurement = { var.snapCacheZ }
        set var.oldToolIndex = { var.snapCacheIdx }
        set var.oldToolOffset = 0
        var nxtCacheIsProbe = false
        if { exists(global.nxtProbeToolID) }
            if { var.snapCacheIdx == global.nxtProbeToolID }
                set var.nxtCacheIsProbe = true
        if { !var.nxtCacheIsProbe }
            if { var.oldToolIndex < #tools }
                if { tools[var.oldToolIndex] != null }
                    set var.oldToolOffset = { tools[var.oldToolIndex].offsets[2] }
        var lengthDiff = { var.newToolMeasurement - var.oldToolMeasurement }
        var newOffset = { var.oldToolOffset - var.lengthDiff }
        G10 L1 P{state.currentTool} Z{var.newOffset}
        echo "tpost.g: Relative offset calculated - Tool " ^ var.oldToolIndex ^ " to Tool " ^ state.currentTool
        echo "tpost.g: Length difference: " ^ var.lengthDiff ^ "mm, Offset=" ^ var.newOffset ^ " mm"
    else
        echo "tpost.g: no mill datum — nxtToolSetterPos Z missing"
        var nxtNeedTs = "Run M5016 (datum on platen) to set mill length datum."
        M291 P{var.nxtNeedTs} R"tpost" S2
        echo "tpost.g: measure incomplete — soft complete (no abort)"
else
    ; No toolsetter — re-zero Z origin in current WCS with the installed tool.
    echo "tpost.g: Toolsetter unavailable — running G37.1 to set Z origin"
    G37.1

; Full park: Z max, M5.9, table XY (CAM M3.9 / G0 XY assume tpost ended parked)
G27

; Re-assert job G68 (native G6512 uses G53; G6512.2 / G37.1 may have issued G69)
if { exists(global.nxtJobG68Deg) && global.nxtJobG68Deg != null }
    M98 P"nxt-job-g68-restore.g"

; Clear tool change state to indicate completion
set global.nxtToolChangeState = null

echo "tpost.g: Tool " ^ state.currentTool ^ " change process completed"