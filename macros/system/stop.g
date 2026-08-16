; stop.g - STOP CURRENT JOB
;
; Called on cancelling or finishing a job.
; Historically may also run on pause on some RRF builds — do NOT clear G68 while paused.
; Do not G27 after numbered probe macros (HTTP / 0:/sys/G65xx) — leftover G38 plus
; table park sent XY to machine 0,0 and dropped homed.
echo "stop.g: invoked"

var nxtSkipPark = false
if { exists(global.nxtSkipJobPark) && global.nxtSkipJobPark }
    set var.nxtSkipPark = true
    set global.nxtSkipJobPark = false

var nxtHaveJob = false
if { exists(job.file.fileName) && job.file.fileName != null }
    if { job.file.fileName != "" }
        set var.nxtHaveJob = true
if { !var.nxtHaveJob }
    set var.nxtSkipPark = true

if { !var.nxtSkipPark }
    G27
else
    echo "stop.g: skipped G27 (probe / no gcode job file)"

; True job end only: clear job-scoped G68 (pause/resume keep rotation)
var nxtStopPaused = { state.status == "paused" || state.status == "pausing" || state.status == "resuming" }
if { !var.nxtStopPaused }
    M98 P"nxt-job-g68-clear.g"

; Run plugin stop hooks, if generated.
if { fileexists("0:/sys/nxt/plugins/nxt-plugin-hooks-stop.g") }
    M98 P"nxt/plugins/nxt-plugin-hooks-stop.g"
