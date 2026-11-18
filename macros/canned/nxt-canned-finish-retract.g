; nxt-canned-finish-retract.g — INTERNAL: final Z retract after hole (G98 / G99)
; Preconditions: global.nxtCannedCycle valid vector; global.nxtCannedRetR = R plane for this cycle

var seriesZ = { global.nxtCannedCycle[5] }
var mode = { global.nxtCannedCycle[6] }
var tR = { global.nxtCannedRetR }
var endZ = { var.mode == 99 ? var.tR : (var.seriesZ > var.tR ? var.seriesZ : var.tR) }

G90 G0 Z{var.endZ}
set global.nxtCannedCycle[8] = { var.endZ }
