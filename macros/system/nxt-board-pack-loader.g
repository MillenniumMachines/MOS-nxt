; nxt-board-pack-loader.g
; Invoked from nxt.g after nxt-vars.g and nxt-user-vars.g when auto pack load is requested.
;
; Opt-in:  create empty file 0:/sys/nxt-board-bootstrap.requested (Configuration Save with bootstrap Auto)
; Opt-out: create 0:/sys/nxt-board-bootstrap.skip
; Override: 0:/sys/nxt-user-board.g runs instead of resolution below.
;
; Load order: board pack (nxt-config/board/) then machine pack (nxt-config/machine/<profile>/).
; Homing macros are deploy-only (Configuration UI), not M98'd at boot.

if { !fileexists("0:/sys/nxt-board-bootstrap.requested") }
    M99

if { fileexists("0:/sys/nxt-board-bootstrap.skip") }
    echo "[NeXT] board pack: skipped (nxt-board-bootstrap.skip)"
    M117 "NeXT board pack SKIPPED"
    M99

echo "[NeXT] board pack: starting"
M117 "NeXT board pack start"

if { fileexists("0:/sys/nxt-user-board.g") }
    M117 "NeXT nxt-user-board.g"
    set global.nxtBoardPackEntry = "nxt-user-board.g"
    M98 P"nxt-user-board.g"
    echo "[NeXT] board pack: finished (nxt-user-board.g)"
    M99

if { !exists(global.nxtPlatformProfile) || global.nxtPlatformProfile == null || global.nxtPlatformProfile == "" }
    echo "[NeXT] board pack: set global nxtPlatformProfile in nxt-user-vars.g (NeXT Configuration)"
    M117 "NeXT board pack no platform"
    M99

if { !fileexists("0:/sys/nxt-config/machine/" ^ global.nxtPlatformProfile ^ "/OVERVIEW.txt") }
    if { !fileexists("0:/sys/nxt/config/" ^ global.nxtPlatformProfile ^ "/OVERVIEW.txt") }
        echo "[NeXT] board pack: machine profile not on SD — reinstall NeXT plugin"
        M117 "NeXT board pack no machine SD"
        M99

M98 P"nxt-board-pack-resolve.g"
M98 P"nxt-board-machine-pack.g"

if { fileexists("0:/sys/nxt-user-pinmap.g") }
    M98 P"nxt-user-pinmap.g"

echo "[NeXT] board pack: finished"
M99
