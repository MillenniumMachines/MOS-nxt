; nxt-board-pack-resolve.g
; Resolves board pack under nxt-config/board/<shortName>/ (see docs/NXT_BOARD_CONFIG.md).
; Legacy fallback: nxt/config/<platform>/boards/<shortName>/ (pre-refactor SD layout).

var brd = ""
if { exists(global.nxtBoardShortNameOverride) && global.nxtBoardShortNameOverride != null && global.nxtBoardShortNameOverride != "" }
    set var.brd = global.nxtBoardShortNameOverride
elif { #boards >= 1 }
    set var.brd = boards[0].shortName
else
    echo "[nxt] board pack resolve: no boards[] and no nxtBoardShortNameOverride"
    M117 "nxt board pack no board id"
    M99

set global.nxtBoardPackShortName = var.brd

var volt = null
if { exists(global.nxtBoardMotorVoltage) && global.nxtBoardMotorVoltage != null }
    set var.volt = global.nxtBoardMotorVoltage
elif { exists(global.nxtScyllaMotorVoltage) && global.nxtScyllaMotorVoltage != null }
    echo "[nxt] board pack: nxtScyllaMotorVoltage is deprecated — use nxtBoardMotorVoltage"
    set var.volt = global.nxtScyllaMotorVoltage

var base = "nxt-config/board/" ^ var.brd
var entry = ""
var legacyBase = ""

if { exists(global.nxtPlatformProfile) && global.nxtPlatformProfile != null && global.nxtPlatformProfile != "" }
    set var.legacyBase = "nxt/config/" ^ global.nxtPlatformProfile ^ "/boards/" ^ var.brd

if { var.volt == 48 && fileexists("0:/sys/" ^ var.base ^ "/motor-48v/entry.g") }
    set var.entry = var.base ^ "/motor-48v/entry.g"
elif { var.volt == 24 && fileexists("0:/sys/" ^ var.base ^ "/motor-24v/entry.g") }
    set var.entry = var.base ^ "/motor-24v/entry.g"
elif { fileexists("0:/sys/" ^ var.base ^ "/entry.g") }
    set var.entry = var.base ^ "/entry.g"
elif { fileexists("0:/sys/" ^ var.base ^ "/motor-24v/entry.g") || fileexists("0:/sys/" ^ var.base ^ "/motor-48v/entry.g") }
    echo "[nxt] board pack: motor variant requires nxtBoardMotorVoltage = 24 or 48"
    M117 "nxt board motor V missing"
    M99

if { var.entry == "" && var.legacyBase != "" }
    if { var.volt == 48 && fileexists("0:/sys/" ^ var.legacyBase ^ "/motor-48v/entry.g") }
        set var.entry = var.legacyBase ^ "/motor-48v/entry.g"
        echo "[nxt] board pack: legacy path " ^ var.entry
    elif { var.volt == 24 && fileexists("0:/sys/" ^ var.legacyBase ^ "/motor-24v/entry.g") }
        set var.entry = var.legacyBase ^ "/motor-24v/entry.g"
        echo "[nxt] board pack: legacy path " ^ var.entry
    elif { fileexists("0:/sys/" ^ var.legacyBase ^ "/entry.g") }
        set var.entry = var.legacyBase ^ "/entry.g"
        echo "[nxt] board pack: legacy path " ^ var.entry

if { var.entry == "" }
    echo "[nxt] board pack: no entry under " ^ var.base
    M117 "nxt board pack not found"
    M99

if { exists(global.nxtBoardPackExpectedEntry) && global.nxtBoardPackExpectedEntry != null && global.nxtBoardPackExpectedEntry != "" && var.entry != global.nxtBoardPackExpectedEntry }
    echo "[nxt] board pack: resolved " ^ var.entry ^ " expected " ^ global.nxtBoardPackExpectedEntry

set global.nxtBoardPackEntry = var.entry
M117 "nxt board pack load"
M98 P{var.entry}
echo "[nxt] board pack: loaded " ^ global.nxtBoardPackEntry
M99
