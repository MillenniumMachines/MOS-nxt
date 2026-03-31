; nxt.g
; NeXT Entrypoint
; To be called from config.g using M98 P"nxt.g"

; Set NeXT Version
if { !exists(global.nxtVersion) }
    global nxtVersion = "%%NXT_VERSION%%"
else
    set global.nxtVersion = "%%NXT_VERSION%%"

; Load default variables if not already loaded
if { !exists(global.nxtVarsLoaded) }
    M98 P"nxt-vars.g"
    global nxtVarsLoaded=true

; Load user-defined variables if they exist
; This MUST set already-defined globals and
; not define new ones as it can be loaded 
; multiple times without restarting the system.
if { fileexists("0:/sys/nxt-user-vars.g") }
    M98 P"nxt-user-vars.g"
else
    ; In the future, the UI will handle this. For now, we halt.
    echo "ERROR: nxt-user-vars.g not found. NeXT requires configuration."
    M99

; Run boot-time sanity checks
M98 P"nxt-boot.g"

; Initialize metadata-driven plugins once boot checks pass.
if { global.nxtLoaded && fileexists("0:/sys/nxt/plugins/nxt-plugin-init-dispatch.g") }
    M98 P"nxt/plugins/nxt-plugin-init-dispatch.g"

; Final check if NeXT loaded successfully
if { global.nxtLoaded }
    echo "NeXT v" ^ global.nxtVersion ^ " loaded successfully."
else
    echo "FATAL: NeXT failed to load. Error: " ^ global.nxtError
