; nxt-canned-finish-retract.g — INTERNAL: final Z retract after hole (G98 / G99)
; Preconditions: global.nxtCannedCycle valid vector; global.nxtCannedRetR = R plane for this cycle

var seriesZ = { global.nxtCannedCycle[5] }
var mode = { global.nxtCannedCycle[6] }
var tR = { global.nxtCannedRetR }
var endZ = { mode == 99 ? tR : (seriesZ > tR ? seriesZ : tR) }

G90 G0 Z{var.endZ}
