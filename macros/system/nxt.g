; nxt.g
; nxt Entrypoint
; To be called from config.g using M98 P"nxt.g"
;
; Requires RepRapFirmware 3.5.0+ (global arrays, meta). vector() is 3.5.0+.
; nxt expects CNC mode (M453): meta if/while must use { }, not ( ) — see RRF_META.txt section 6.
; If metacommands misbehave, read macros/system/RRF_META.txt.
;
; Load order (later layers overlay earlier):
;   1) nxt-vars.g              — lean core defaults
;   2) nxt-custom-globals.g    — only if Custom sentinel/overlays (if !exists → null)
;   3) optional MOS import / tool table / probe-wcs
;   4) nxt-user-vars.g         — operator Save overlay (set only)
;   5) board pack, tools, boot checks, plugins, RGB, …
;   6) nxt-user-overrides.g    — last wins, then nxtLoaded

; Set nxt Version
if { !exists(global.nxtVersion) }
    global nxtVersion = "%%NXT_VERSION%%"
else
    set global.nxtVersion = "%%NXT_VERSION%%"

M117 "nxt boot"

; 1) Core defaults (once per power-on — nxt-vars uses bare `global` declares)
if { !exists(global.nxtVarsLoaded) }
    M117 "nxt nxt-vars.g"
    M98 P"nxt-vars.g"
    global nxtVarsLoaded=true

; 2) Custom-platform keys only when Custom is in use (OM ~8KB — avoid ~30 nulls on Milo packs).
;    Sentinel written by Configuration Save; overlays under nxt-user-custom/ also count.
var nxtNeedCustomGlobals = { fileexists("0:/sys/nxt-custom.requested") }
if { !var.nxtNeedCustomGlobals }
    set var.nxtNeedCustomGlobals = { fileexists("0:/sys/nxt-user-custom/limits.g") }
if { !var.nxtNeedCustomGlobals }
    set var.nxtNeedCustomGlobals = { fileexists("0:/sys/nxt-user-custom/endstops.g") }
if { var.nxtNeedCustomGlobals }
    M117 "nxt nxt-custom-globals.g"
    M98 P"nxt-custom-globals.g"

; Millennium OS migration: run when legacy MOS is present on SD and/or in globals.
; Re-import anytime: touch 0:/sys/nxt-mos-import.requested
; First-time only (default): MOS detected and nxt-user-vars.g not created yet
; Nested import skips re-declare of custom-globals / mid-load of user-vars (nxt.g owns those).
; (split conditions — RRF rejects lines > ~200 chars; see docs/RRF_LINE_LENGTH.md)
var nxtMosImportForced = { fileexists("0:/sys/nxt-mos-import.requested") }
var nxtNeedsUserVars = { !fileexists("0:/sys/nxt-user-vars.g") }
var nxtMosOnSd = { fileexists("0:/sys/mos-vars.g") || fileexists("0:/sys/mos-user-vars.g") || fileexists("0:/sys/mos.g") }
var nxtMosInGlobals = { exists(global.mosSID) || exists(global.mosFeatTouchProbe) || exists(global.mosPTID) || exists(global.mosLdd) }
var nxtRunMosImport = { var.nxtMosImportForced || (var.nxtNeedsUserVars && (var.nxtMosOnSd || var.nxtMosInGlobals)) }
if { var.nxtRunMosImport }
    M117 "nxt MOS import"
    M98 P"nxt-mos-import.g"

; Post-processor tool table (nxtTT / nxtET) — sole mosTT→nxtTT owner (see nxt-tooltable.g).
if { !exists(global.nxtTT) }
    M117 "nxt nxt-tooltable.g"
    M98 P"nxt-tooltable.g"

; Dual MOS+nxt tool tables inflate global OM past the SBC 8KB SPI limit.
if { exists(global.mosTT) && exists(global.nxtTT) }
    echo "nxt: WARNING mosTT and nxtTT both exist — remove MOS from config.g after migration (OM global >8KB)"

; WCS probing pack — gate on WP sentinel (not nxtOvertravel; align may set overtravel from MOS).
if { !exists(global.nxtWPCtrPos) }
    M98 P"nxt-probe-wcs.g"

; After WP allocate, copy mos WCS / overtravel into nxt* when MOS data is still present.
if { exists(global.mosWPCtrPos) || exists(global.mosOT) }
    M98 P"nxt-mos-globals-align.g"

; 4) Operator overlay — set only; keys already declared above
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

; Operator overlay done — enter CNC mode before board pack (meta if/exists need { } under M453).
M453

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

; CNC mode (idempotent if already set above; board pack may also M453)
M453

; Run boot-time sanity checks (sets nxtBootOk; does not set nxtLoaded)
M117 "nxt nxt-boot.g"
M98 P"nxt-boot.g"

; Restore persisted maintenance counters (axis travel + tool life) when present.
if { global.nxtBootOk && fileexists("0:/sys/nxt-maintenance.g") }
    if { !exists(global.nxtToolLife) }
        global nxtToolLife = { vector(min(limits.tools, 50), null) }
    elif { global.nxtToolLife == null }
        set global.nxtToolLife = { vector(min(limits.tools, 50), null) }
    M117 "nxt nxt-maintenance.g"
    M98 P"nxt-maintenance.g"

; Initialize metadata-driven plugins once boot checks pass.
if { !exists(global.nxtPluginsInited) }
    global nxtPluginsInited = false
; Cache daemon hook paths (refresh each nxt.g load so soft re-M98 stays accurate).
if { !exists(global.nxtDaemonHookPluginInit) }
    global nxtDaemonHookPluginInit = false
if { !exists(global.nxtDaemonHookPluginDaemon) }
    global nxtDaemonHookPluginDaemon = false
if { !exists(global.nxtDaemonHookToolsReload) }
    global nxtDaemonHookToolsReload = false
set global.nxtDaemonHookPluginInit = { fileexists("0:/sys/nxt/plugins/nxt-plugin-init-dispatch.g") }
set global.nxtDaemonHookPluginDaemon = { fileexists("0:/sys/nxt/plugins/nxt-plugin-daemon-dispatch.g") }
set global.nxtDaemonHookToolsReload = { fileexists("0:/sys/nxt/nxt-user-tools-reload-daemon.g") }

if { global.nxtBootOk && global.nxtDaemonHookPluginInit && !global.nxtPluginsInited }
    M117 "nxt plugin-init"
    M98 P"nxt/plugins/nxt-plugin-init-dispatch.g"
    set global.nxtPluginsInited = true
elif { global.nxtBootOk && global.nxtDaemonHookPluginInit }
    set global.nxtPluginsInited = true

; MosFourthAxis (optional sibling plugin) — only when feature on and files present.
; Prefer 0:/sys/mos-fourth-axis.g (init + M4800). Else init under plugins/ + M4800.
; Feature flag is boolean (same as other nxtFeature*); do not compare to 1.
var nxtFaOn = false
if { exists(global.nxtFeatureFourthAxis) && global.nxtFeatureFourthAxis }
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

; nxtRGBCount is owned by Configuration → nxt-user-vars.g. Legacy colour files may
; still set count; re-apply user-vars so Configuration wins before M950.
if { fileexists("0:/sys/nxt-user-vars.g") }
    M98 P"nxt-user-vars.g"

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
; Single post-colour M950 owner for boot (daemon may lazy-fallback later).
var nxtRgbPinOk = { exists(global.nxtRGBPin) && global.nxtRGBPin != null }
if { var.nxtRgbPinOk }
    M950 E{global.nxtRGBStrip} C{global.nxtRGBPin} T{global.nxtRGBType} U{global.nxtRGBCount}
    if { exists(global.nxtRGBReady) }
        set global.nxtRGBReady = true

; Daemon defaults live in nxt-vars.g (nxtDaemonEnabled / nxtDaemonInterval).

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
