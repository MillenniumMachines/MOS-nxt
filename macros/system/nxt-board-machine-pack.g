; nxt-board-machine-pack.g
; Loads machine motion pack for global.nxtPlatformProfile.
; M98 P requires a static path or {var} — not "path" ^ global (see nxt-board-pack-loader.g).

if { !exists(global.nxtPlatformProfile) || global.nxtPlatformProfile == null || global.nxtPlatformProfile == "" }
    M99

var machineEntry = ""

if { global.nxtPlatformProfile == "v1.5" }
    set var.machineEntry = "nxt-config/machine/v1.5/entry.g"
if { global.nxtPlatformProfile == "v1.6_v2" }
    set var.machineEntry = "nxt-config/machine/v1.6_v2/entry.g"

if { var.machineEntry == "" }
    echo "[NeXT] machine pack: unknown nxtPlatformProfile " ^ global.nxtPlatformProfile
    M117 "NeXT machine pack unknown"
    M99

if { !fileexists("0:/sys/" ^ var.machineEntry) }
    echo "[NeXT] machine pack: missing on SD: " ^ var.machineEntry
    M117 "NeXT machine pack missing"
    M99

M117 "NeXT machine pack"
M98 P{var.machineEntry}
echo "[NeXT] machine pack: loaded " ^ var.machineEntry
M99
