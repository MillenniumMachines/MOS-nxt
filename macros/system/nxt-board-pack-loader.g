; nxt-board-pack-loader.g
; Invoked from nxt.g after nxt-vars.g and nxt-user-vars.g when auto pack load is requested.
;
; Opt-in:  create empty file 0:/sys/nxt-board-bootstrap.requested
; Opt-out: create 0:/sys/nxt-board-bootstrap.skip
; Override: 0:/sys/nxt-user-board.g runs instead of resolution below.
;
; Requires global nxtPlatformProfile "v1.5" or "v1.6_v2" in nxt-user-vars.g for auto paths.
; Board id: global nxtBoardShortNameOverride (optional) else boards[0].shortName (see OM / M409).
; Scylla (scylla1_0_h723): set global nxtScyllaMotorVoltage = 24 or 48.

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

if { !exists(global.nxtPlatformProfile) || global.nxtPlatformProfile == null }
    echo "[NeXT] board pack: set global nxtPlatformProfile to v1.5 or v1.6_v2 in nxt-user-vars.g"
    M117 "NeXT board pack no platform"
    M99

if { global.nxtPlatformProfile != "v1.5" && global.nxtPlatformProfile != "v1.6_v2" }
    echo "[NeXT] board pack: nxtPlatformProfile not supported for bundled packs: " ^ global.nxtPlatformProfile ^ " (use nxt-user-board.g)"
    M117 "NeXT board pack bad platform"
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

if { global.nxtPlatformProfile == "v1.6_v2" }
    if { var.brd == "cdy3_f4" }
        set global.nxtBoardPackEntry = "nxt/config/v1.6_v2/boards/cdy3_f4/entry.g"
        M117 "NeXT board pack v1.6 cdy3_f4"
        M98 P"nxt/config/v1.6_v2/boards/cdy3_f4/entry.g"
        echo "[NeXT] board pack: loaded " ^ global.nxtBoardPackEntry
        M99
    if { var.brd == "scylla1_0_h723" }
        if { !exists(global.nxtScyllaMotorVoltage) || global.nxtScyllaMotorVoltage == null }
            echo "[NeXT] board pack: Scylla requires global nxtScyllaMotorVoltage = 24 or 48 in nxt-user-vars.g (NeXT Configuration UI or hand edit)"
            M117 "NeXT Scylla motor V missing"
            M99
        if { global.nxtScyllaMotorVoltage == 48 }
            set global.nxtBoardPackEntry = "nxt/config/v1.6_v2/boards/scylla1_0_h723/motor-48v/entry.g"
            M117 "NeXT board pack v1.6 Scylla 48V"
            M98 P"nxt/config/v1.6_v2/boards/scylla1_0_h723/motor-48v/entry.g"
            echo "[NeXT] board pack: loaded " ^ global.nxtBoardPackEntry
            M99
        if { global.nxtScyllaMotorVoltage == 24 }
            set global.nxtBoardPackEntry = "nxt/config/v1.6_v2/boards/scylla1_0_h723/motor-24v/entry.g"
            M117 "NeXT board pack v1.6 Scylla 24V"
            M98 P"nxt/config/v1.6_v2/boards/scylla1_0_h723/motor-24v/entry.g"
            echo "[NeXT] board pack: loaded " ^ global.nxtBoardPackEntry
            M99
        echo "[NeXT] board pack: nxtScyllaMotorVoltage must be 24 or 48, got: " ^ global.nxtScyllaMotorVoltage
        M117 "NeXT Scylla motor V bad"
        M99

if { global.nxtPlatformProfile == "v1.5" }
    if { var.brd == "cdy3_f4" }
        set global.nxtBoardPackEntry = "nxt/config/v1.5/boards/cdy3_f4/entry.g"
        M117 "NeXT board pack v1.5 cdy3_f4"
        M98 P"nxt/config/v1.5/boards/cdy3_f4/entry.g"
        echo "[NeXT] board pack: loaded " ^ global.nxtBoardPackEntry
        M99
    if { var.brd == "scylla1_0_h723" }
        if { !exists(global.nxtScyllaMotorVoltage) || global.nxtScyllaMotorVoltage == null }
            echo "[NeXT] board pack: Scylla requires global nxtScyllaMotorVoltage = 24 or 48 in nxt-user-vars.g (NeXT Configuration UI or hand edit)"
            M117 "NeXT Scylla motor V missing"
            M99
        if { global.nxtScyllaMotorVoltage == 48 }
            set global.nxtBoardPackEntry = "nxt/config/v1.5/boards/scylla1_0_h723/motor-48v/entry.g"
            M117 "NeXT board pack v1.5 Scylla 48V"
            M98 P"nxt/config/v1.5/boards/scylla1_0_h723/motor-48v/entry.g"
            echo "[NeXT] board pack: loaded " ^ global.nxtBoardPackEntry
            M99
        if { global.nxtScyllaMotorVoltage == 24 }
            set global.nxtBoardPackEntry = "nxt/config/v1.5/boards/scylla1_0_h723/motor-24v/entry.g"
            M117 "NeXT board pack v1.5 Scylla 24V"
            M98 P"nxt/config/v1.5/boards/scylla1_0_h723/motor-24v/entry.g"
            echo "[NeXT] board pack: loaded " ^ global.nxtBoardPackEntry
            M99
        echo "[NeXT] board pack: nxtScyllaMotorVoltage must be 24 or 48, got: " ^ global.nxtScyllaMotorVoltage
        M117 "NeXT Scylla motor V bad"
        M99

echo "[NeXT] board pack: unknown board id '" ^ var.brd ^ "' — add 0:/sys/nxt-user-board.g or set global.nxtBoardShortNameOverride"
M117 "NeXT board pack UNKNOWN"
