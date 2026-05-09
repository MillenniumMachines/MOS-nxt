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

M117 "NeXT boot"

; Load default variables if not already loaded
if { !exists(global.nxtVarsLoaded) }
    M117 "NeXT nxt-vars.g"
    M98 P"nxt-vars.g"
    global nxtVarsLoaded=true

; Optional MOS migration: touch 0:/sys/nxt-mos-import.requested on SD for one-shot import.
; Load order: mos-vars.g -> mos-user-vars.g -> nxt-mos-import.g -> nxt-user-vars.g (below).
if { fileexists("0:/sys/nxt-mos-import.requested") }
    M117 "NeXT MOS import"
    if { fileexists("0:/sys/mos-vars.g") && !exists(global.mosVarsLoaded) }
        M98 P"mos-vars.g"
    if { exists(global.mosVarsLoaded) && fileexists("0:/sys/mos-user-vars.g") }
        M98 P"mos-user-vars.g"
    M98 P"nxt-mos-import.g"

; Post-processor tool table (mosTT / mosET) unless MOS vars already defined them
if { !exists(global.mosTT) }
    M117 "NeXT nxt-tooltable.g"
    M98 P"nxt-tooltable.g"

; Load user-defined variables if they exist
; This MUST set already-defined globals and
; not define new ones as it can be loaded 
; multiple times without restarting the system.
if { fileexists("0:/sys/nxt-user-vars.g") }
    M117 "NeXT nxt-user-vars.g"
    M98 P"nxt-user-vars.g"
else
    ; In the future, the UI will handle this. For now, we halt.
    M117 "NeXT ERROR no nxt-user-vars"
    echo "ERROR: nxt-user-vars.g not found. NeXT requires configuration."
    M99

; Optional: load board pack (drives, limits, spindle, …). After user vars so Scylla motor voltage applies.
; Requires 0:/sys/nxt-board-bootstrap.requested — see nxt-board-pack-loader.g
M117 "NeXT board-pack"
M98 P"nxt-board-pack-loader.g"

; Persisted tool library (M4000 + G10 L1) — optional; written by DWC Tool Library or by hand.
; When absent, tools are still defined from CAM / console M4000; DWC can save a library later.
if { fileexists("0:/sys/nxt-user-tools.g") }
    set global.nxtUserToolsFilePresent = true
    echo "NeXT: loading persisted tool library (nxt-user-tools.g)"
    M117 "NeXT nxt-user-tools.g"
    M98 P"nxt-user-tools.g"
else
    set global.nxtUserToolsFilePresent = false
    M117 "NeXT no nxt-user-tools.g"
    echo "NeXT: nxt-user-tools.g not found — optional; define tools via M4000 or add this file to persist them"

if {!exists(global.nxtLoaded)}
    global nxtLoaded = false
    
; Run boot-time sanity checks
M117 "NeXT nxt-boot.g"
M98 P"nxt-boot.g"

; Initialize metadata-driven plugins once boot checks pass.
if { global.nxtLoaded && fileexists("0:/sys/nxt/plugins/nxt-plugin-init-dispatch.g") }
    M117 "NeXT plugin-init"
    M98 P"nxt/plugins/nxt-plugin-init-dispatch.g"

; Final check if NeXT loaded successfully
if { global.nxtLoaded }
    M117 "NeXT ready"
    echo "NeXT v" ^ global.nxtVersion ^ " loaded successfully."
else
    ; Safe message: nxtError may be null if boot aborted before it was set (avoid odd echo / OM values for DWC)
    M117 "NeXT load FAILED"
    echo "FATAL: NeXT failed to load. Error: " ^ (exists(global.nxtError) && global.nxtError != null ? global.nxtError : "no details recorded")
