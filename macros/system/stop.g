; stop.g - STOP CURRENT JOB

; Called on cancelling or finishing a job.
; Apparently also triggered when pausing.
; Park the spindle.
G27

; Run plugin stop hooks, if generated.
if { fileexists("0:/sys/nxt/plugins/nxt-plugin-hooks-stop.g") }
    M98 P"nxt/plugins/nxt-plugin-hooks-stop.g"
