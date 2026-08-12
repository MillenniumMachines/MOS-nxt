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
; NO PARAMETERS - called automatically by RRF

; Skip if no tool is currently selected
if { state.currentTool < 0 }
    M99

; New Tn sequence — drop leftover cancel from a previous incomplete change.
if { exists(global.nxtToolChangeCancelled) }
    set global.nxtToolChangeCancelled = false

; Validate all axes are homed
while { iterations < #move.axes }
    if { !move.axes[iterations].homed }
        abort { "tfree.g: Axis " ^ move.axes[iterations].letter ^ " must be homed before tool change" }

; Set tool change state to indicate tfree.g started
set global.nxtToolChangeState = 1

; Stop and park spindle for safety
G27 Z1

; Check if current tool is the probe tool
; Use S4 (not S3): S3 Cancel aborts the file and can kill DCS on USB SBC.
if { state.currentTool == global.nxtProbeToolID }
    ; Handle probe tool removal
    var probeType = { global.nxtFeatureTouchProbe ? "Touch Probe" : "Datum Tool" }
    ; ATC: replace with magazine unload / pocket deposit sequence for probe
    M291 P{"Please remove the " ^ var.probeType ^ " and confirm when safely stowed."} R{"Remove " ^ var.probeType} S4 K{"Continue", "Cancel"}
    ; Keep nxtToolCacheIdx/Z for probe this session — tpost relative offset needs it
    ; (docs/TOOLSETTING.md Scenario B: probe → cutter).
else
    ; Standard cutting tool: removal only. New tool measurement runs in tpost.g.
    ; ATC: replace with magazine unload / pocket deposit sequence.
    M291 P{"Please remove Tool " ^ state.currentTool ^ " and confirm when complete."} R"Remove Tool" S4 K{"Continue", "Cancel"}

; S4 Cancel (input != 0): do not abort. tpre skips install; tpost skips measure.
if { input != 0 }
    set global.nxtToolChangeCancelled = true
    set global.nxtToolChangeState = 2
    echo "tfree.g: tool change cancelled — skipping new tool"
    M99

; Set tool change state to indicate tfree.g completed
set global.nxtToolChangeState = 2

echo "tfree.g: Tool " ^ state.currentTool ^ " removal process completed"