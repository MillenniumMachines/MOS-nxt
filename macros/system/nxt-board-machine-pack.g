; nxt-board-machine-pack.g
; Loads machine motion pack for global.nxtPlatformProfile.
; M98 P requires a static path or {var} — not "path" ^ global (see nxt-board-pack-loader.g).

if { !exists(global.nxtPlatformProfile) || global.nxtPlatformProfile == null || global.nxtPlatformProfile == "" }
    M99

var machineEntry = ""

if { global.nxtPlatformProfile == "v1.5" }
    set var.machineEntry = "nxt-config/machine/v1.5/entry.g"
if { global.nxtPlatformProfile == "v1.6" }
    set var.machineEntry = "nxt-config/machine/v1.6/entry.g"
if { global.nxtPlatformProfile == "v2.0" }
    set var.machineEntry = "nxt-config/machine/v2.0/entry.g"
if { global.nxtPlatformProfile == "custom" }
    set var.machineEntry = "nxt-config/machine/custom/entry.g"
; one-release alias: former combined pack → v1.6
if { global.nxtPlatformProfile == "v1.6_v2" }
    set var.machineEntry = "nxt-config/machine/v1.6/entry.g"

if { var.machineEntry == "" }
    echo "[nxt] machine pack: unknown nxtPlatformProfile " ^ global.nxtPlatformProfile
    M117 "nxt machine pack unknown"
    M99

if { !fileexists("0:/sys/" ^ var.machineEntry) }
    echo "[nxt] machine pack: missing on SD: " ^ var.machineEntry
    M117 "nxt machine pack missing"
    M99

M117 "nxt machine pack"
M98 P{var.machineEntry}
echo "[nxt] machine pack: loaded " ^ var.machineEntry
M99
