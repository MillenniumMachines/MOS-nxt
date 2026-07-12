; nxt-daemon.g
; nxt plugin host hook called by system/daemon.g

; Discover and initialize plugins once (boot usually already set nxtPluginsInited).
if { exists(global.nxtDaemonHookPluginInit) && global.nxtDaemonHookPluginInit }
    if { !exists(global.nxtPluginsInited) || !global.nxtPluginsInited }
        M98 P"nxt/plugins/nxt-plugin-init-dispatch.g"
        if { !exists(global.nxtPluginsInited) }
            global nxtPluginsInited = true
        else
            set global.nxtPluginsInited = true

; Run periodic daemon entrypoints for loaded plugins.
if { exists(global.nxtDaemonHookPluginDaemon) && global.nxtDaemonHookPluginDaemon }
    M98 P"nxt/plugins/nxt-plugin-daemon-dispatch.g"

; Optional: reload persisted tool definitions when 0:/sys/nxt-user-tools.reload.requested exists
if { exists(global.nxtDaemonHookToolsReload) && global.nxtDaemonHookToolsReload }
    M98 P"nxt/nxt-user-tools-reload-daemon.g"

; Coolant pulse phase advance (mist / flood)
if { exists(global.nxtCoolantPulseActive) && global.nxtCoolantPulseActive }
    M98 P"nxt-coolant-pulse-daemon.g"

; RGB status LED renderer
if { global.nxtFeatureRgbLight }
    M98 P"nxt/nxt-run-rgb.g"

; Maintenance counters (axis travel + tool life)
if { exists(global.nxtFeatMaint) && global.nxtFeatMaint }
    M98 P"nxt/nxt-run-maintenance.g"
