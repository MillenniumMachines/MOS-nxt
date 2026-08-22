; tpre.g: TOOL PRE-CHANGE - EXECUTED BY RRF BEFORE TOOL LOAD
;
; This macro is executed automatically by RepRapFirmware before a new tool
; is loaded. It validates the tool change state and prepares for offset
; calculation based on the relative offsetting workflow.
;
; ATC integration: Default path uses M291 for manual load. Automatic changer:
; replace prompts with pick-from-pocket motion or M98 to extension macros
; (docs/TOOLCHANGING.md). Preserve nxtToolChangeState (2 -> 3).
; Operator Cancel / soft-fail: set nxtToolChangeCancelled and M99 so tpost
; skips measure. Never abort (leaves RRF stuck Changing Tool). Never issue T.
;
; NO PARAMETERS - called automatically by RRF

; Validate sequencing: tfree.g should have completed when switching from an active tool.
; First selection from no active tool skips tfree.g in RRF, so allow nxtToolChangeState=null there.
if { state.currentTool >= 0 && global.nxtToolChangeState != 2 }
    set global.nxtToolChangeCancelled = true
    set global.nxtToolChangeState = 3
    echo "tpre.g: invalid state (expected tfree done) — soft cancel"
    M99

; Fresh first-tool select (tfree skipped): drop a leftover cancel flag.
if { global.nxtToolChangeState != 2 }
    if { exists(global.nxtToolChangeCancelled) }
        set global.nxtToolChangeCancelled = false

; Validate all axes are homed (soft cancel — do not abort)
var nxtTpHomed = true
while { iterations < #move.axes }
    if { !move.axes[iterations].homed }
        set var.nxtTpHomed = false
if { !var.nxtTpHomed }
    set global.nxtToolChangeCancelled = true
    set global.nxtToolChangeState = 3
    echo "tpre.g: axes not homed — soft cancel (no abort)"
    M99

; Drain leftover G38 before omit-XY park
M98 P"nxt-g38-cancel.g"

; tfree Cancel: skip park and install; tpost skips measure.
var nxtTcCancel = false
if { exists(global.nxtToolChangeCancelled) && global.nxtToolChangeCancelled }
    set var.nxtTcCancel = true
if { var.nxtTcCancel }
    set global.nxtToolChangeState = 3
    echo "tpre.g: tool change cancelled — skipping install"
    M99

; Full park before operator Install (Z max, M5.9, table XY)
G27

; Get the tool number that will be loaded (from the pending tool change).
; RRF 3.7+: prefer motionSystems[0].nextTool (state.nextTool is obsolete).
var newTool = -1
if { exists(move.motionSystems) && #move.motionSystems > 0 }
    set var.newTool = { move.motionSystems[0].nextTool }
elif { exists(state.nextTool) }
    set var.newTool = { state.nextTool }

if { var.newTool < 0 }
    set global.nxtToolChangeState = 3
    echo "tpre.g: no pending tool — skipping install"
    M99

; S4 Cancel → input != 0 without aborting the T-stack (S3 Cancel aborts).
if { var.newTool == global.nxtProbeToolID }
    var probeType = { global.nxtFeatureTouchProbe ? "Touch Probe" : "Datum Tool" }
    ; ATC: replace with pick from pocket / spindle load sequence for probe
    if { global.nxtFeatureTouchProbe }
        if { global.nxtTouchProbeID == null }
            set global.nxtToolChangeCancelled = true
            set global.nxtToolChangeState = 3
            echo "tpre.g: nxtTouchProbeID unset — soft cancel"
            M99
        var msgTp = "Install Touch Probe (T" ^ var.newTool ^ ") and ensure it is connected."
        set var.msgTp = { var.msgTp ^ " Press OK, then manually trigger the tip until detected." }
        M291 P{var.msgTp} R"Install Touch Probe" S4 K{"OK","Cancel"} F0
        if { input != 0 }
            set global.nxtToolChangeCancelled = true
            set global.nxtToolChangeState = 3
            echo "tpre.g: tool change cancelled"
            M99
        M98 P"nxt-probe-sensor-wait.g"
        ; sensor-wait soft-fails by setting nxtToolChangeCancelled (never abort)
        if { global.nxtToolChangeCancelled }
            set global.nxtToolChangeState = 3
            echo "tpre.g: tip confirm cancelled or failed"
            M99
    else
        M291 P{"Please install " ^ var.probeType ^ " (T" ^ var.newTool ^ ") and confirm when ready."} R{"Install " ^ var.probeType} S4 K{"OK","Cancel"} F0
        if { input != 0 }
            set global.nxtToolChangeCancelled = true
            set global.nxtToolChangeState = 3
            echo "tpre.g: tool change cancelled"
            M99
else
    ; ATC: replace with pick from pocket / spindle load sequence
    ; Human name = tools[].name (M4000 S); legacy label T{n} — {name}
    var toolLabel = { "T" ^ var.newTool }
    if { var.newTool < #tools && tools[var.newTool] != null }
        if { #tools[var.newTool].name > 0 }
            set var.toolLabel = { "T" ^ var.newTool ^ " — " ^ tools[var.newTool].name }
    var msgInst = { "Please install " ^ var.toolLabel ^ " and confirm when ready." }
    M291 P{var.msgInst} R"Install Tool" S4 K{"OK","Cancel"} F0
    if { input != 0 }
        set global.nxtToolChangeCancelled = true
        set global.nxtToolChangeState = 3
        echo "tpre.g: tool change cancelled"
        M99

set global.nxtToolChangeState = 3

echo "tpre.g: Ready to load Tool " ^ var.newTool
