; nxt.g
; NeXT Entrypoint
; To be called from config.g using M98 P"nxt.g"
;
; Requires RepRapFirmware 3.5.0+ (global arrays, meta). vector() is 3.5.0+.
; NeXT expects CNC mode (M453): meta if/while must use { }, not ( ) — see RRF_META.txt section 6.
; If metacommands misbehave, read macros/system/RRF_META.txt.

; Set NeXT Version
if { !exists(global.nxtVersion) }
    global nxtVersion = "%%NXT_VERSION%%"
else
    set global.nxtVersion = "%%NXT_VERSION%%"

; Optional: load board kit fragments (spindle.g, limits.g, …) before NeXT globals.
; Requires 0:/sys/nxt-board-bootstrap.requested — see nxt-board-bootstrap.g
M98 P"nxt-board-bootstrap.g"

; Load default variables if not already loaded
if { !exists(global.nxtVarsLoaded) }
    M98 P"nxt-vars.g"
    global nxtVarsLoaded=true

; Optional MOS migration: touch 0:/sys/nxt-mos-import.requested on SD for one-shot import.
; Load order: mos-vars.g -> mos-user-vars.g -> nxt-mos-import.g -> nxt-user-vars.g (below).
if { fileexists("0:/sys/nxt-mos-import.requested") }
    if { fileexists("0:/sys/mos-vars.g") && !exists(global.mosVarsLoaded) }
        M98 P"mos-vars.g"
    if { exists(global.mosVarsLoaded) && fileexists("0:/sys/mos-user-vars.g") }
        M98 P"mos-user-vars.g"
    M98 P"nxt-mos-import.g"

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

if {!exists(global.nxtLoaded)}
    global nxtLoaded = false
    
; Run boot-time sanity checks
M98 P"nxt-boot.g"

; Initialize metadata-driven plugins once boot checks pass.
if { global.nxtLoaded && fileexists("0:/sys/nxt/plugins/nxt-plugin-init-dispatch.g") }
    M98 P"nxt/plugins/nxt-plugin-init-dispatch.g"

; Final check if NeXT loaded successfully
if { global.nxtLoaded }
    echo "NeXT v" ^ global.nxtVersion ^ " loaded successfully."
else
    ; Safe message: nxtError may be null if boot aborted before it was set (avoid odd echo / OM values for DWC)
    echo "FATAL: NeXT failed to load. Error: " ^ (exists(global.nxtError) && global.nxtError != null ? global.nxtError : "no details recorded")
