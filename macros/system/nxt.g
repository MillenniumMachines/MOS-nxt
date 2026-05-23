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

; Millennium OS migration: run when legacy MOS is present on SD and/or in globals.
; Re-import anytime: touch 0:/sys/nxt-mos-import.requested
; First-time only (default): MOS detected and nxt-user-vars.g not created yet
; (split — RRF rejects if { ... } lines longer than ~255 characters)
var nxtDoMosImport = false
if { fileexists("0:/sys/nxt-mos-import.requested") }
    set var.nxtDoMosImport = true
if { !var.nxtDoMosImport && !fileexists("0:/sys/nxt-user-vars.g") }
    if { fileexists("0:/sys/mos-vars.g") || fileexists("0:/sys/mos-user-vars.g") || fileexists("0:/sys/mos.g") }
        set var.nxtDoMosImport = true
    if { !var.nxtDoMosImport && exists(global.mosSID) }
        set var.nxtDoMosImport = true
    if { !var.nxtDoMosImport && exists(global.mosFeatTouchProbe) }
        set var.nxtDoMosImport = true
    if { !var.nxtDoMosImport && exists(global.mosPTID) }
        set var.nxtDoMosImport = true
    if { !var.nxtDoMosImport && exists(global.mosLdd) }
        set var.nxtDoMosImport = true
if { var.nxtDoMosImport }
    M117 "NeXT MOS import"
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
    set global.nxtUserVarsPresent = true
    set global.nxtConfigPending = false
    M117 "NeXT nxt-user-vars.g"
    M98 P"nxt-user-vars.g"
else
    set global.nxtUserVarsPresent = false
    set global.nxtConfigPending = true
    M117 "NeXT config pending"
    echo "NeXT: nxt-user-vars.g not found — open DWC Configuration, review settings, then Save to create the file."

; Optional: load board pack (drives, limits, spindle, …). After user vars so motor voltage / platform apply.
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

; Optional user overrides last — wins over nxt-vars, nxt-user-vars, board pack, and tool table.
; Shipped template: 0:/sys/nxt-user-overrides.g.example (never loaded). Active file only:
if { fileexists("0:/sys/nxt-user-overrides.g") }
    M117 "NeXT nxt-user-overrides.g"
    M98 P"nxt-user-overrides.g"
elif { fileexists("0:/sys/nxt-user-overrides.g.example") }
    echo "NeXT: nxt-user-overrides.g not found — copy nxt-user-overrides.g.example to nxt-user-overrides.g on SD to apply overrides"

; Final check if NeXT loaded successfully
if { global.nxtLoaded }
    M117 "NeXT ready"
    echo "NeXT v" ^ global.nxtVersion ^ " loaded successfully."
else
    ; Safe message: nxtError may be null if boot aborted before it was set (avoid odd echo / OM values for DWC)
    M117 "NeXT load FAILED"
    var nxtErrMsg = "no details recorded"
    if { exists(global.nxtError) && global.nxtError != null }
        set var.nxtErrMsg = global.nxtError
    echo "FATAL: NeXT failed to load. Error: " ^ var.nxtErrMsg
