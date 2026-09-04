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
;   4b) nxt-probe-virtual.g    — persisted datum platen Z (after user-vars)
;   5) board pack, tools, workplaces (nxt-user-wcs.g), boot checks, plugins, RGB, …
;   6) nxt-user-overrides.g    — last wins, then nxtLoaded
; Arm motor/VFD via Status / M80.9 only — never block boot with M291 (locks nxt.g on SD).

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

; Apply plugin-shipped daemon.install → daemon.g (avoids DSF overwriting open loop file).
if { fileexists("0:/sys/daemon.install") }
    M117 "nxt daemon.install"
    M98 P"nxt-daemon-install.g"

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

; Probe scalars + nxtWPDeg — gate on Deg (not overtravel / CtrPos).
; Ctr/Dims/Rad: nxt-wp-ensure.g. Corners: nxt-wp-ensure-cnr.g. Surfaces: nxt-wp-ensure-sfc.g.
if { !exists(global.nxtWPDeg) }
    M98 P"nxt-probe-wcs.g"

; After Deg/scalars, copy mos WCS / overtravel into nxt* when MOS data is still present.
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

; Persisted mill length datum (M5016 platen Z). After user-vars.
if { fileexists("0:/sys/nxt-probe-virtual.g") }
    echo "nxt: loading persisted probe virtual (nxt-probe-virtual.g)"
    M117 "nxt nxt-probe-virtual.g"
    M98 P"nxt-probe-virtual.g"
else
    echo "nxt: nxt-probe-virtual.g not found"

var nxtVirtOk = false
if { exists(global.nxtProbeVirtualTsZ) }
    if { global.nxtProbeVirtualTsZ != null }
        set var.nxtVirtOk = true
if { !var.nxtVirtOk }
    var nxtHaveTsZ = false
    if { exists(global.nxtToolSetterPos) }
        if { global.nxtToolSetterPos != null }
            if { #global.nxtToolSetterPos >= 3 }
                if { global.nxtToolSetterPos[2] != null }
                    set var.nxtHaveTsZ = true
    if { var.nxtHaveTsZ }
        if { !exists(global.nxtProbeVirtualTsZ) }
            global nxtProbeVirtualTsZ = { global.nxtToolSetterPos[2] }
        else
            set global.nxtProbeVirtualTsZ = { global.nxtToolSetterPos[2] }
        set var.nxtVirtOk = true
        echo "nxt: nxtProbeVirtualTsZ from nxtToolSetterPos Z=" ^ global.nxtProbeVirtualTsZ
if { var.nxtVirtOk }
    echo "nxt: nxtProbeVirtualTsZ=" ^ global.nxtProbeVirtualTsZ
else
    echo "nxt: nxtProbeVirtualTsZ unset — mill tpost needs M5016 platen Z"

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

; Persisted workplaces (G10 L2). After board pack so axes exist. Not G68.
if { fileexists("0:/sys/nxt-user-wcs.g") }
    echo "nxt: loading persisted workplaces (nxt-user-wcs.g)"
    M117 "nxt nxt-user-wcs.g"
    M98 P"nxt-user-wcs.g"
else
    M117 "nxt no nxt-user-wcs.g"
    echo "nxt: nxt-user-wcs.g not found — workplaces reset until next probe apply"

if { !exists(global.nxtLoaded) }
    global nxtLoaded = false
if { !exists(global.nxtBootOk) }
    global nxtBootOk = false

; CNC mode (idempotent if already set above; board pack may also M453)
M453

; Run boot-time sanity checks (sets nxtBootOk; does not set nxtLoaded)
M117 "nxt nxt-boot.g"
M98 P"nxt-boot.g"

; Restore persisted maintenance counters. Do not pre-expand nxtToolLife
; (OM ~8KB) — nxt-maintenance.g M98s nxt-tool-life-ensure.g only when rows exist.
if { global.nxtBootOk && fileexists("0:/sys/nxt-maintenance.g") }
    M117 "nxt nxt-maintenance.g"
    M98 P"nxt-maintenance.g"

; Initialize metadata-driven plugins once boot checks pass.
if { !exists(global.nxtPluginsInited) }
    global nxtPluginsInited = false
; nxtDaemonHooks bits: 1=plugin-init, 2=plugin-daemon, 4=tools-reload
set global.nxtDaemonHooks = 0
if { fileexists("0:/sys/nxt/plugins/nxt-plugin-init-dispatch.g") }
    set global.nxtDaemonHooks = { global.nxtDaemonHooks + 1 }
if { fileexists("0:/sys/nxt/plugins/nxt-plugin-daemon-dispatch.g") }
    set global.nxtDaemonHooks = { global.nxtDaemonHooks + 2 }
if { fileexists("0:/sys/nxt/nxt-user-tools-reload-daemon.g") }
    set global.nxtDaemonHooks = { global.nxtDaemonHooks + 4 }

var nxtHookInit = { mod(global.nxtDaemonHooks, 2) == 1 }
if { global.nxtBootOk && var.nxtHookInit && !global.nxtPluginsInited }
    M117 "nxt plugin-init"
    M98 P"nxt/plugins/nxt-plugin-init-dispatch.g"
    set global.nxtPluginsInited = true
elif { global.nxtBootOk && var.nxtHookInit }
    set global.nxtPluginsInited = true

; MosFourthAxis loads via nxt-plugin-init-dispatch.g when nxtFeatureFourthAxis is
; on (catalog plugin). Mapping in rotary-plugin-config.g is skipped if A already
; exists (Scylla axis-a.g). Do not M98 rotary-plugin-config.g from config.g.

; MosAtc (optional sibling plugin) — only when feature on and init macros present.
; Init is NOT via nxt-plugin-init-dispatch (OM budget for atc* globals).
var nxtAtcOn = false
var nxtAtcLoaded = false
if { exists(global.nxtFeatureAtc) && global.nxtFeatureAtc }
    set var.nxtAtcOn = true

if { var.nxtAtcOn }
    if { fileexists("0:/sys/mos-atc.g") }
        M117 "nxt mos-atc"
        M98 P"mos-atc.g"
        set var.nxtAtcLoaded = true
    elif { fileexists("0:/sys/plugins/mos-atc/mos-atc-init.g") }
        M117 "nxt mos-atc-init"
        M98 P"plugins/mos-atc/mos-atc-init.g"
        set var.nxtAtcLoaded = true
    elif { fileexists("0:/plugins/mos-atc/mos-atc-init.g") }
        M117 "nxt mos-atc-init"
        M98 P"0:/plugins/mos-atc/mos-atc-init.g"
        set var.nxtAtcLoaded = true
    else
        echo "nxt: nxtFeatureAtc on but MosAtc macros missing on SD"

if { var.nxtAtcLoaded }
    if { !exists(global.nxtPluginLoaded_mosatc) }
        global nxtPluginLoaded_mosatc = false
    set global.nxtPluginLoaded_mosatc = true

; Persisted RGB colour map (written by nxt-save-rgb.g from Status / RGB panel).
if { fileexists("0:/sys/nxt-rgb-colours.g") }
    M98 P"nxt-rgb-colours.g"

; nxtRGBCount / type / order are owned by Configuration → nxt-user-vars.g.
; Legacy colour files may still set them; re-apply user-vars so Configuration wins.
if { fileexists("0:/sys/nxt-user-vars.g") }
    M98 P"nxt-user-vars.g"

; Legacy docs used T3 for RGBW; RRF M950 uses T2. Coerce once before M950.
if { exists(global.nxtRGBType) && global.nxtRGBType == 3 }
    set global.nxtRGBType = 2

; Colour order (M950 K) — declare if upgrading from a build without nxtRGBOrder.
if { !exists(global.nxtRGBOrder) }
    global nxtRGBOrder = 5

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
    M950 E{global.nxtRGBStrip} C{global.nxtRGBPin} T{global.nxtRGBType} K{global.nxtRGBOrder} U{global.nxtRGBCount}
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
    echo "nxt " ^ global.nxtVersion ^ " loaded successfully."
else
    ; Safe message: nxtError may be null if boot aborted before it was set (avoid odd echo / OM values for DWC)
    M117 "nxt load FAILED"
    var nxtErrMsg = "no details recorded"
    if { exists(global.nxtError) && global.nxtError != null }
        set var.nxtErrMsg = global.nxtError
    echo "FATAL: nxt failed to load. Error: " ^ var.nxtErrMsg

; UEB hints only — do not M98 nxt-relay.g here (blocking M291 keeps nxt.g open on SD).
; Arm via Status Activate or M80.9 after boot returns.
if { global.nxtLoaded }
    if { fileexists("0:/sys/estop.g") }
        if { !fileexists("0:/sys/trigger2.g") }
            echo "nxt: estop.g present but trigger2.g missing — copy trigger2.g.example to 0:/sys/"
        elif { exists(global.nxtFeatureMachinePower) && global.nxtFeatureMachinePower }
            echo "nxt: UEB estop ready — arm motor/VFD with Status Activate or M80.9"
    elif { fileexists("0:/sys/estop.g.example") }
        echo "nxt: UEB estop not enabled — copy estop.g.example and trigger2.g.example to 0:/sys/"
