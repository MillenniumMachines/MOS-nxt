; nxt-daemon.g
; nxt plugin host hook called by system/daemon.g

; nxtDaemonHooks bits: 1=plugin-init, 2=plugin-daemon, 4=tools-reload
var nxtHookInit = false
var nxtHookDaemon = false
var nxtHookTools = false
if { exists(global.nxtDaemonHooks) }
    set var.nxtHookInit = { mod(global.nxtDaemonHooks, 2) == 1 }
    set var.nxtHookDaemon = { mod(floor(global.nxtDaemonHooks / 2), 2) == 1 }
    set var.nxtHookTools = { mod(floor(global.nxtDaemonHooks / 4), 2) == 1 }

; Discover and initialize plugins once (boot usually already set nxtPluginsInited).
if { var.nxtHookInit }
    if { !exists(global.nxtPluginsInited) || !global.nxtPluginsInited }
        M98 P"nxt/plugins/nxt-plugin-init-dispatch.g"
        if { !exists(global.nxtPluginsInited) }
            global nxtPluginsInited = true
        else
            set global.nxtPluginsInited = true

; Run periodic daemon entrypoints for loaded plugins.
if { var.nxtHookDaemon }
    M98 P"nxt/plugins/nxt-plugin-daemon-dispatch.g"

; Optional: reload persisted tool definitions when 0:/sys/nxt-user-tools.reload.requested exists
if { var.nxtHookTools }
    M98 P"nxt/nxt-user-tools-reload-daemon.g"

; Coolant pulse phase advance (mist / flood)
if { exists(global.nxtCoolantPulseActive) && global.nxtCoolantPulseActive }
    M98 P"nxt-coolant-pulse-daemon.g"

; Variable Spindle Speed Control (M7000 / M7001)
if { exists(global.nxtVSEnabled) && global.nxtVSEnabled }
    M98 P"nxt-run-vssc.g"

; RGB status LED renderer
if { global.nxtFeatureRgbLight }
    M98 P"nxt/nxt-run-rgb.g"

; Maintenance counters (axis travel + tool life)
if { exists(global.nxtFeatMaint) && global.nxtFeatMaint }
    M98 P"nxt/nxt-run-maintenance.g"
