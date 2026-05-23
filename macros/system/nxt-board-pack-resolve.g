; nxt-board-pack-resolve.g
; Convention-based board pack path resolution (see docs/NXT_BOARD_CONFIG.md).
; Expects global.nxtBoardPackResolveBrd = board shortName (set by nxt-board-pack-loader.g); global.nxtPlatformProfile set.
; Sets var.entry and global.nxtBoardPackEntry, then M98's the entry.

var volt = null
if { exists(global.nxtBoardMotorVoltage) && global.nxtBoardMotorVoltage != null }
    set var.volt = global.nxtBoardMotorVoltage
elif { exists(global.nxtScyllaMotorVoltage) && global.nxtScyllaMotorVoltage != null }
    echo "[NeXT] board pack: nxtScyllaMotorVoltage is deprecated — use nxtBoardMotorVoltage in nxt-user-vars.g"
    set var.volt = global.nxtScyllaMotorVoltage

var base = "nxt/config/" ^ global.nxtPlatformProfile ^ "/boards/" ^ global.nxtBoardPackResolveBrd
var entry = ""

if { var.volt == 48 && fileexists("0:/sys/" ^ var.base ^ "/motor-48v/entry.g") }
    set var.entry = var.base ^ "/motor-48v/entry.g"
elif { var.volt == 24 && fileexists("0:/sys/" ^ var.base ^ "/motor-24v/entry.g") }
    set var.entry = var.base ^ "/motor-24v/entry.g"
elif { fileexists("0:/sys/" ^ var.base ^ "/entry.g") }
    set var.entry = var.base ^ "/entry.g"
elif { fileexists("0:/sys/" ^ var.base ^ "/motor-24v/entry.g") || fileexists("0:/sys/" ^ var.base ^ "/motor-48v/entry.g") }
    echo "[NeXT] board pack: motor variant pack requires global nxtBoardMotorVoltage = 24 or 48 in nxt-user-vars.g"
    M117 "NeXT board motor V missing"
    M99
else
    echo "[NeXT] board pack: no entry.g under " ^ var.base ^ " — reinstall NeXT plugin or check platform/board"
    M117 "NeXT board pack not found"
    M99

if { exists(global.nxtBoardPackExpectedEntry) && global.nxtBoardPackExpectedEntry != null && global.nxtBoardPackExpectedEntry != "" && var.entry != global.nxtBoardPackExpectedEntry }
    echo "[NeXT] board pack: resolved " ^ var.entry ^ " but nxtBoardPackExpectedEntry is " ^ global.nxtBoardPackExpectedEntry

set global.nxtBoardPackEntry = var.entry
M117 "NeXT board pack load"
M98 P{var.entry}
echo "[NeXT] board pack: loaded " ^ global.nxtBoardPackEntry
M99
