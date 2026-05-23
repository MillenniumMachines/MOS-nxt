; nxt-board-pack-loader.g
; Invoked from nxt.g after nxt-vars.g and nxt-user-vars.g when auto pack load is requested.
;
; Opt-in:  create empty file 0:/sys/nxt-board-bootstrap.requested (Configuration Save with bootstrap Auto)
; Opt-out: create 0:/sys/nxt-board-bootstrap.skip
; Override: 0:/sys/nxt-user-board.g runs instead of resolution below.
;
; Requires global nxtPlatformProfile in nxt-user-vars.g (any platform under nxt/config/<id>/).
; Board id: global nxtBoardShortNameOverride (optional) else boards[0].shortName.
; Motor variants: global nxtBoardMotorVoltage = 24 or 48 when motor-24v / motor-48v packs exist.

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

if { !fileexists("0:/sys/nxt/config/" ^ global.nxtPlatformProfile ^ "/OVERVIEW.txt") }
    echo "[NeXT] board pack: platform not on SD: nxt/config/" ^ global.nxtPlatformProfile ^ " — reinstall NeXT plugin"
    M117 "NeXT board pack no platform SD"
    M99

var brd = ""
if { exists(global.nxtBoardShortNameOverride) && global.nxtBoardShortNameOverride != null && global.nxtBoardShortNameOverride != "" }
    set var.brd = global.nxtBoardShortNameOverride
elif { #boards >= 1 }
    set var.brd = boards[0].shortName
else
    echo "[NeXT] board pack: no boards[] and no nxtBoardShortNameOverride — add nxt-user-board.g or set override"
    M117 "NeXT board pack no board id"
    M99

; Local var.* does not pass into child macros via M98 — use a global scratch (see RRF_META.txt).
set global.nxtBoardPackResolveBrd = var.brd
M98 P"nxt-board-pack-resolve.g"
M99
