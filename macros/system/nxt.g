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

; Legacy MOS globals on SD (pre-nxtTT rename) — align once per boot when needed.
if { exists(global.mosTT) && !exists(global.nxtTT) }
    M98 P"nxt-mos-globals-align.g"

; Post-processor tool table (nxtTT / nxtET) unless already allocated
if { !exists(global.nxtTT) }
    M117 "nxt nxt-tooltable.g"
    M98 P"nxt-tooltable.g"

; Dual MOS+nxt tool tables inflate global OM past the SBC 8KB SPI limit.
if { exists(global.mosTT) && exists(global.nxtTT) }
    echo "nxt: WARNING mosTT and nxtTT both exist — remove MOS from config.g after migration (OM global >8KB)"

; WCS probing metadata + jog probe distances (unless mos-vars.g already loaded them)
if { !exists(global.nxtOvertravel) }
    M98 P"nxt-probe-wcs.g"

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
if { !exists(global.nxtBootOk) }
    global nxtBootOk = false

; CNC mode before boot checks (board pack may also M453; safe to repeat)
M453

; Run boot-time sanity checks (sets nxtBootOk; does not set nxtLoaded)
M117 "nxt nxt-boot.g"
M98 P"nxt-boot.g"

; Restore persisted maintenance counters (axis travel + tool life) when present.
if { global.nxtBootOk && fileexists("0:/sys/nxt-maintenance.g") }
    M117 "nxt nxt-maintenance.g"
    M98 P"nxt-maintenance.g"

; Initialize metadata-driven plugins once boot checks pass.
if { global.nxtBootOk && fileexists("0:/sys/nxt/plugins/nxt-plugin-init-dispatch.g") }
    M117 "nxt plugin-init"
    M98 P"nxt/plugins/nxt-plugin-init-dispatch.g"

; MosFourthAxis (optional sibling plugin) — only when feature on and files present.
; Prefer 0:/sys/mos-fourth-axis.g (init + M4800). Else init under plugins/ + M4800.
var nxtFaOn = false
if { exists(global.nxtFeatureFourthAxis) }
    if { global.nxtFeatureFourthAxis == true || global.nxtFeatureFourthAxis == 1 }
        set var.nxtFaOn = true

if { var.nxtFaOn }
    if { fileexists("0:/sys/mos-fourth-axis.g") }
        M117 "nxt mos-fourth-axis"
        M98 P"mos-fourth-axis.g"
    elif { fileexists("0:/sys/plugins/mos-fourth-axis/mos-fourth-axis-init.g") }
        M117 "nxt mos-fourth-axis-init"
        M98 P"plugins/mos-fourth-axis/mos-fourth-axis-init.g"
        if { fileexists("0:/sys/M4800.g") }
            M4800
    elif { fileexists("0:/plugins/mos-fourth-axis/mos-fourth-axis-init.g") }
        M117 "nxt mos-fourth-axis-init"
        M98 P"0:/plugins/mos-fourth-axis/mos-fourth-axis-init.g"
        if { fileexists("0:/sys/M4800.g") }
            M4800
    else
        echo "nxt: nxtFeatureFourthAxis on but MosFourthAxis macros missing on SD"

; Do not M98 rotary-plugin-config.g here — Scylla axis-a.g already maps A; avoid duplicate M584/M574.

; Persisted RGB colour map (written by nxt-save-rgb.g from Status / RGB panel).
if { fileexists("0:/sys/nxt-rgb-colours.g") }
    M98 P"nxt-rgb-colours.g"

; Migrate legacy per-state RGB globals into nxtRGBCol, then rewrite the file so
; the next boot does not recreate nxtRGBIdle/Home/... (OM bloat).
var nxtRgbLegacy = { exists(global.nxtRGBIdle) || exists(global.nxtRGBHome) || exists(global.nxtRGBErr) }
if { var.nxtRgbLegacy && exists(global.nxtRGBCol) }
    if { exists(global.nxtRGBIdle) }
        set global.nxtRGBCol[0] = global.nxtRGBIdle
    if { exists(global.nxtRGBHome) }
        set global.nxtRGBCol[1] = global.nxtRGBHome
    if { exists(global.nxtRGBProbe) }
        set global.nxtRGBCol[2] = global.nxtRGBProbe
    if { exists(global.nxtRGBTool) }
        set global.nxtRGBCol[3] = global.nxtRGBTool
    if { exists(global.nxtRGBRun) }
        set global.nxtRGBCol[4] = global.nxtRGBRun
    if { exists(global.nxtRGBPause) }
        set global.nxtRGBCol[5] = global.nxtRGBPause
    if { exists(global.nxtRGBErr) }
        set global.nxtRGBCol[6] = global.nxtRGBErr
    M98 P"nxt/nxt-save-rgb.g"
    echo "nxt: migrated RGB colours to nxtRGBCol — reboot once more to drop legacy globals from OM"

; Re-apply M950 after colour/count load (board rgb.g may have run earlier with defaults).
var nxtRgbPinOk = { exists(global.nxtRGBPin) && global.nxtRGBPin != null }
if { var.nxtRgbPinOk }
    M950 E{global.nxtRGBStrip} C{global.nxtRGBPin} T{global.nxtRGBType} U{global.nxtRGBCount}
    if { exists(global.nxtRGBReady) }
        set global.nxtRGBReady = true

; Daemon loop defaults (coolant pulse and future periodic tasks)
if { !exists(global.nxtDaemonEnabled) }
    global nxtDaemonEnabled = true
if { !exists(global.nxtDaemonInterval) }
    global nxtDaemonInterval = 250

; Optional user overrides last — wins over everything above; then nxtLoaded is set.
; Shipped template: 0:/sys/nxt-user-overrides.g.example (never loaded). Active file only:
if { fileexists("0:/sys/nxt-user-overrides.g") }
    M117 "nxt nxt-user-overrides.g"
    M98 P"nxt-user-overrides.g"
elif { fileexists("0:/sys/nxt-user-overrides.g.example") }
    echo "nxt: nxt-user-overrides.g not found — copy nxt-user-overrides.g.example to nxt-user-overrides.g on SD to apply overrides"

; Flag loaded only after overrides (and the rest of boot) have run.
if { global.nxtBootOk }
    set global.nxtLoaded = true
    M117 "nxt ready"
    echo "nxt v" ^ global.nxtVersion ^ " loaded successfully."
else
    ; Safe message: nxtError may be null if boot aborted before it was set (avoid odd echo / OM values for DWC)
    M117 "nxt load FAILED"
    var nxtErrMsg = "no details recorded"
    if { exists(global.nxtError) && global.nxtError != null }
        set var.nxtErrMsg = global.nxtError
    echo "FATAL: nxt failed to load. Error: " ^ var.nxtErrMsg
