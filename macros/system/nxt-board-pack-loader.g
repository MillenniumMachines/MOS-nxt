; nxt-board-pack-loader.g
; Invoked from nxt.g after nxt-vars.g and nxt-user-vars.g when auto pack load is requested.
;
; Opt-in:  nxtBoardBootstrapMode=auto (nxt-user-vars) and/or
;          0:/sys/nxt-board-bootstrap.requested (Configuration Save)
; Opt-out: create 0:/sys/nxt-board-bootstrap.skip
; Override: 0:/sys/nxt-user-board.g runs instead of resolution below.
;
; Load order: board pack (nxt-config/board/) then machine pack (nxt-config/machine/<profile>/).
; Homing macros are deploy-only (Configuration UI), not M98'd at boot.
;
; After M999, fileexists on a zero-byte .requested can race false — also trust mode=auto.

var wantPack = false
var hasRequested = { fileexists("0:/sys/nxt-board-bootstrap.requested") }
var modeAuto = false
if { exists(global.nxtBoardBootstrapMode) && global.nxtBoardBootstrapMode == "auto" }
    set var.modeAuto = true

if { var.hasRequested }
    set var.wantPack = true
elif { var.modeAuto }
    set var.wantPack = true
    ; Recreate sentinel so the next cold boot does not depend on a missing/empty file
    echo >"0:/sys/nxt-board-bootstrap.requested" {"; nxt board bootstrap auto"}
    echo "[nxt] board pack: restored nxt-board-bootstrap.requested (mode=auto)"

if { !var.wantPack }
    echo "[nxt] board pack: skipped (bootstrap off — set Configuration Bootstrap to Auto)"
    M117 "nxt board pack off"
    M99

if { fileexists("0:/sys/nxt-board-bootstrap.skip") }
    echo "[nxt] board pack: skipped (nxt-board-bootstrap.skip)"
    M117 "nxt board pack SKIPPED"
    M99

echo "[nxt] board pack: starting"
M117 "nxt board pack start"

if { fileexists("0:/sys/nxt-user-board.g") }
    M117 "nxt nxt-user-board.g"
    if { !exists(global.nxtBoardPackEntry) }
        global nxtBoardPackEntry = "nxt-user-board.g"
    else
        set global.nxtBoardPackEntry = "nxt-user-board.g"
    M98 P"nxt-user-board.g"
    echo "[nxt] board pack: finished (nxt-user-board.g)"
    M99

if { !exists(global.nxtPlatformProfile) || global.nxtPlatformProfile == null || global.nxtPlatformProfile == "" }
    echo "[nxt] board pack: set global nxtPlatformProfile in nxt-user-vars.g (nxt Configuration)"
    M117 "nxt board pack no platform"
    M99

if { !fileexists("0:/sys/nxt-config/machine/" ^ global.nxtPlatformProfile ^ "/OVERVIEW.txt") }
    if { !fileexists("0:/sys/nxt/config/" ^ global.nxtPlatformProfile ^ "/OVERVIEW.txt") }
        echo "[nxt] board pack: machine profile not on SD — reinstall nxt plugin"
        M117 "nxt board pack no machine SD"
        M99

M98 P"nxt-board-pack-resolve.g"
M98 P"nxt-board-machine-pack.g"

if { fileexists("0:/sys/nxt-user-pinmap.g") }
    M98 P"nxt-user-pinmap.g"

echo "[nxt] board pack: finished"
M99
