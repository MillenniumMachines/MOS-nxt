; nxt-daemon.g
; nxt plugin host hook called by system/daemon.g

; Discover and initialize plugins that are not loaded yet.
if { fileexists("0:/sys/nxt/plugins/nxt-plugin-init-dispatch.g") }
    M98 P"nxt/plugins/nxt-plugin-init-dispatch.g"

; Run periodic daemon entrypoints for loaded plugins.
if { fileexists("0:/sys/nxt/plugins/nxt-plugin-daemon-dispatch.g") }
    M98 P"nxt/plugins/nxt-plugin-daemon-dispatch.g"

; Optional: reload persisted tool definitions when 0:/sys/nxt-user-tools.reload.requested exists
if { fileexists("0:/sys/nxt/nxt-user-tools-reload-daemon.g") }
    M98 P"nxt/nxt-user-tools-reload-daemon.g"
