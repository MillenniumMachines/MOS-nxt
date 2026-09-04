; Call M9 for Coolant Control
M9

; End of job (cancel): drop workplace G68 so the next setup does not inherit it
M98 P"nxt-job-g68-clear.g"

; Run plugin cancel hooks, if generated.
if { fileexists("0:/sys/nxt/plugins/nxt-plugin-hooks-cancel.g") }
    M98 P"nxt/plugins/nxt-plugin-hooks-cancel.g"
