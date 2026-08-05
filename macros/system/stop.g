; stop.g - STOP CURRENT JOB
;
; Called on cancelling or finishing a job.
; Historically may also run on pause on some RRF builds — do NOT clear G68 while paused.
; Park the spindle.
G27

; True job end only: clear job-scoped G68 (pause/resume keep rotation)
var nxtStopPaused = { state.status == "paused" || state.status == "pausing" || state.status == "resuming" }
if { !var.nxtStopPaused }
    M98 P"nxt-job-g68-clear.g"

; Run plugin stop hooks, if generated.
if { fileexists("0:/sys/nxt/plugins/nxt-plugin-hooks-stop.g") }
    M98 P"nxt/plugins/nxt-plugin-hooks-stop.g"
