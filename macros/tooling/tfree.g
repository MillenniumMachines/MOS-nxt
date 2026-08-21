; tfree.g: TOOL FREE - EXECUTED BY RRF BEFORE TOOL UNLOAD
;
; This macro is executed automatically by RepRapFirmware before a tool
; is freed (unloaded). It handles probe-on-removal logic for standard
; cutting tools and special handling for the touch probe.
;
; ATC integration: Default path uses M291 for manual unload. An automatic
; changer should replace those prompts with motion and/or M98 P"..." to a
; vendor/extension macro pack (see docs/TOOLCHANGING.md). Keep the same
; nxtToolChangeState sequence (1 -> 2) so tpre/tpost stay valid.
;
; Never abort — abort leaves RRF stuck in Changing Tool. Soft-fail only.
;
; NO PARAMETERS - called automatically by RRF

; Skip if no tool is currently selected
if { state.currentTool < 0 }
    M99

; New Tn sequence — drop leftover cancel from a previous incomplete change.
if { exists(global.nxtToolChangeCancelled) }
    set global.nxtToolChangeCancelled = false

; Validate all axes are homed (soft cancel — do not abort)
var nxtTfHomed = true
while { iterations < #move.axes }
    if { !move.axes[iterations].homed }
        set var.nxtTfHomed = false
if { !var.nxtTfHomed }
    set global.nxtToolChangeCancelled = true
    set global.nxtToolChangeState = 2
    echo "tfree.g: axes not homed — soft cancel (no abort)"
    M99

; Drain leftover G38 before omit-XY park
M98 P"nxt-g38-cancel.g"

; Set tool change state to indicate tfree.g started
set global.nxtToolChangeState = 1

; Full park before operator Remove (Z max, M5.9, table XY)
G27

; S4 Cancel sets input != 0 without aborting the T-stack (S3 Cancel aborts).
if { state.currentTool == global.nxtProbeToolID }
    var probeType = { global.nxtFeatureTouchProbe ? "Touch Probe" : "Datum Tool" }
    ; ATC: replace with magazine unload / pocket deposit sequence for probe
    M291 P{"Please remove the " ^ var.probeType ^ " and confirm when safely stowed."} R{"Remove " ^ var.probeType} S4 K{"OK","Cancel"} F0
    ; Keep nxtToolCacheIdx/Z for probe this session — tpost relative offset needs it
else
    ; Standard cutting tool: removal only. New tool measurement runs in tpost.g.
    M291 P{"Please remove Tool " ^ state.currentTool ^ " and confirm when complete."} R"Remove Tool" S4 K{"OK","Cancel"} F0

; Cancel (input != 0): soft skip — do not abort. tpre skips install; tpost skips measure.
if { input != 0 }
    set global.nxtToolChangeCancelled = true
    set global.nxtToolChangeState = 2
    echo "tfree.g: tool change cancelled — skipping new tool"
    M99

; Set tool change state to indicate tfree.g completed
set global.nxtToolChangeState = 2

echo "tfree.g: Tool " ^ state.currentTool ^ " removal process completed"
