; Call M9 for Coolant Control
M9

; Run plugin cancel hooks, if generated.
if { fileexists("0:/sys/nxt/plugins/nxt-plugin-hooks-cancel.g") }
    M98 P"nxt/plugins/nxt-plugin-hooks-cancel.g"
