; tpre.g: TOOL PRE-CHANGE - EXECUTED BY RRF BEFORE TOOL LOAD
;
; This macro is executed automatically by RepRapFirmware before a new tool
; is loaded. It validates the tool change state and prepares for offset
; calculation based on the relative offsetting workflow.
;
; ATC integration: Default path uses M291 for manual load. Automatic changer:
; replace prompts with pick-from-pocket motion or M98 to extension macros
; (docs/TOOLCHANGING.md). Preserve nxtToolChangeState (2 -> 3).
; Operator Cancel: do not abort (RRF would still run tpost and measure).
; Set nxtToolChangeCancelled and M99 so tpost skips measure. Never issue T.
;
; NO PARAMETERS - called automatically by RRF

; Validate sequencing: tfree.g should have completed when switching from an active tool.
; First selection from no active tool skips tfree.g in RRF, so allow nxtToolChangeState=null there.
if { state.currentTool >= 0 && global.nxtToolChangeState != 2 }
    abort { "tpre.g: Tool change state invalid. tfree.g must complete before tpre.g" }

; Fresh first-tool select (tfree skipped): drop a leftover cancel flag.
if { global.nxtToolChangeState != 2 }
    if { exists(global.nxtToolChangeCancelled) }
        set global.nxtToolChangeCancelled = false

; Validate all axes are homed
while { iterations < #move.axes }
    if { !move.axes[iterations].homed }
        abort { "tpre.g: Axis " ^ move.axes[iterations].letter ^ " must be homed before tool change" }

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
    echo "tpre.g: no pending tool — skipping install"
    M99

; Prompt user to install the new tool
if { var.newTool == global.nxtProbeToolID }
    var probeType = { global.nxtFeatureTouchProbe ? "Touch Probe" : "Datum Tool" }
    ; ATC: replace with pick from pocket / spindle load sequence for probe
    if { global.nxtFeatureTouchProbe }
        if { global.nxtTouchProbeID == null }
            abort { "tpre.g: Touch probe sensor ID (nxtTouchProbeID) is not configured" }
        var msgTp = "Install Touch Probe (T" ^ var.newTool ^ ") and ensure it is connected."
        set var.msgTp = { var.msgTp ^ " Press Continue, then manually trigger the tip until detected." }
        M291 P{var.msgTp} R"Install Touch Probe" S4 K{"Continue", "Cancel"}
        if { input != 0 }
            set global.nxtToolChangeCancelled = true
            set global.nxtToolChangeState = 3
            echo "tpre.g: tool change cancelled"
            M99
        M98 P"nxt-probe-sensor-wait.g"
    else
        M291 P{"Please install " ^ var.probeType ^ " (T" ^ var.newTool ^ ") and confirm when ready."} R{"Install " ^ var.probeType} S4 K{"Continue", "Cancel"}
        if { input != 0 }
            set global.nxtToolChangeCancelled = true
            set global.nxtToolChangeState = 3
            echo "tpre.g: tool change cancelled"
            M99
else
    ; ATC: replace with pick from pocket / spindle load sequence
    M291 P{"Please install Tool " ^ var.newTool ^ " and confirm when ready."} R"Install Tool" S4 K{"Continue", "Cancel"}
    if { input != 0 }
        set global.nxtToolChangeCancelled = true
        set global.nxtToolChangeState = 3
        echo "tpre.g: tool change cancelled"
        M99

set global.nxtToolChangeState = 3

echo "tpre.g: Ready to load Tool " ^ var.newTool
