; nxt.g
; nxt Entrypoint
; To be called from config.g using M98 P"nxt.g"
;
; Requires RepRapFirmware 3.5.0+ (global arrays, meta). vector() is 3.5.0+.
; nxt expects CNC mode (M453): meta if/while must use { }, not ( ) — see RRF_META.txt section 6.
; If metacommands misbehave, read macros/system/RRF_META.txt.

; Set nxt Version
if { !exists(global.nxtVersion) }
    global nxtVersion = "%%NXT_VERSION%%"
else
    set global.nxtVersion = "%%NXT_VERSION%%"

M117 "nxt boot"

; Load default variables if not already loaded
if { !exists(global.nxtVarsLoaded) }
    M117 "nxt nxt-vars.g"
    M98 P"nxt-vars.g"
    global nxtVarsLoaded=true

; Millennium OS migration: run when legacy MOS is present on SD and/or in globals.
; Re-import anytime: touch 0:/sys/nxt-mos-import.requested
; First-time only (default): MOS detected and nxt-user-vars.g not created yet
; (split conditions — RRF rejects lines > ~200 chars; see docs/RRF_LINE_LENGTH.md)
var nxtMosImportForced = { fileexists("0:/sys/nxt-mos-import.requested") }
var nxtNeedsUserVars = { !fileexists("0:/sys/nxt-user-vars.g") }
var nxtMosOnSd = { fileexists("0:/sys/mos-vars.g") || fileexists("0:/sys/mos-user-vars.g") || fileexists("0:/sys/mos.g") }
var nxtMosInGlobals = { exists(global.mosSID) || exists(global.mosFeatTouchProbe) || exists(global.mosPTID) || exists(global.mosLdd) }
var nxtRunMosImport = { var.nxtMosImportForced || (var.nxtNeedsUserVars && (var.nxtMosOnSd || var.nxtMosInGlobals)) }
if { var.nxtRunMosImport }
    M117 "nxt MOS import"
    M98 P"nxt-mos-import.g"

; Post-processor tool table (mosTT / mosET) unless MOS vars already defined them
if { !exists(global.mosTT) }
    M117 "nxt nxt-tooltable.g"
    M98 P"nxt-tooltable.g"

; Load user-defined variables if they exist
; This MUST set already-defined globals and
; not define new ones as it can be loaded 
; multiple times without restarting the system.
if { fileexists("0:/sys/nxt-user-vars.g") }
    set global.nxtUserVarsPresent = true
    set global.nxtConfigPending = false
    M117 "nxt nxt-user-vars.g"
    M98 P"nxt-user-vars.g"
else
    set global.nxtUserVarsPresent = false
    set global.nxtConfigPending = true
    M117 "nxt config pending"
    echo "nxt: nxt-user-vars.g not found — open DWC Configuration, review settings, then Save to create the file."

; Optional: load board pack (drives, limits, spindle, …). After user vars so motor voltage / platform apply.
; Requires 0:/sys/nxt-board-bootstrap.requested — see nxt-board-pack-loader.g
M117 "nxt board-pack"
M98 P"nxt-board-pack-loader.g"

; Persisted tool library (M4000 + G10 L1) — optional; written by DWC Tool Library or by hand.
; When absent, tools are still defined from CAM / console M4000; DWC can save a library later.
if { fileexists("0:/sys/nxt-user-tools.g") }
    set global.nxtUserToolsFilePresent = true
    echo "nxt: loading persisted tool library (nxt-user-tools.g)"
    M117 "nxt nxt-user-tools.g"
    M98 P"nxt-user-tools.g"
else
    set global.nxtUserToolsFilePresent = false
    M117 "nxt no nxt-user-tools.g"
    echo "nxt: nxt-user-tools.g not found — optional; define tools via M4000 or add this file to persist them"

if { !exists(global.nxtLoaded) }
    global nxtLoaded = false

; CNC mode before boot checks (board pack may also M453; safe to repeat)
M453

; Run boot-time sanity checks
M117 "nxt nxt-boot.g"
M98 P"nxt-boot.g"

; Initialize metadata-driven plugins once boot checks pass.
if { global.nxtLoaded && fileexists("0:/sys/nxt/plugins/nxt-plugin-init-dispatch.g") }
    M117 "nxt plugin-init"
    M98 P"nxt/plugins/nxt-plugin-init-dispatch.g"

; Optional user overrides last — wins over nxt-vars, nxt-user-vars, board pack, and tool table.
; Shipped template: 0:/sys/nxt-user-overrides.g.example (never loaded). Active file only:
if { fileexists("0:/sys/nxt-user-overrides.g") }
    M117 "nxt nxt-user-overrides.g"
    M98 P"nxt-user-overrides.g"
elif { fileexists("0:/sys/nxt-user-overrides.g.example") }
    echo "nxt: nxt-user-overrides.g not found — copy nxt-user-overrides.g.example to nxt-user-overrides.g on SD to apply overrides"

; Final check if nxt loaded successfully
if { global.nxtLoaded }
    M117 "nxt ready"
    echo "nxt v" ^ global.nxtVersion ^ " loaded successfully."
else
    ; Safe message: nxtError may be null if boot aborted before it was set (avoid odd echo / OM values for DWC)
    M117 "nxt load FAILED"
    var nxtErrMsg = "no details recorded"
    if { exists(global.nxtError) && global.nxtError != null }
        set var.nxtErrMsg = global.nxtError
    echo "FATAL: nxt failed to load. Error: " ^ var.nxtErrMsg
