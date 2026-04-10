; G89.g — Boring: feed in, dwell, feed out to clear height (LinuxCNC G89 analogue)
; First block: Z, R, F, P (dwell seconds). Sticky parameters. G91 / L not supported.

if { !inputs[state.thisInput].active }
    M99

M98 P"nxt-canned-spindle.g"
M98 P"nxt-canned-zindex.g"

var zi = { global.nxtCannedZi }
var startSeriesZ = { move.axes[zi].userPosition }

if { global.nxtCannedCycle != null && global.nxtCannedCycle[0] != 89 }
    set global.nxtCannedCycle = { null }

var prev = { global.nxtCannedCycle }
var tZ = { exists(param.Z) ? param.Z : (prev != null ? prev[1] : null) }
var tR = { exists(param.R) ? param.R : (prev != null ? prev[2] : null) }
var tF = { exists(param.F) ? param.F : (prev != null ? prev[4] : null) }
var tP = { exists(param.P) ? param.P : (prev != null ? prev[7] : null) }
var tX = { exists(param.X) ? param.X : null }
var tY = { exists(param.Y) ? param.Y : null }

if { prev == null }
    if { var.tZ == null || var.tR == null || var.tF == null || var.tP == null }
        abort { "G89: Z, R, F, and P required on first use" }
    if { var.tP < 0 }
        abort { "G89: P (dwell) must be non-negative" }
    set global.nxtCannedCycle = { vector(8, null) }
    set global.nxtCannedCycle[0] = { 89 }
    set global.nxtCannedCycle[3] = { null }
    set global.nxtCannedCycle[5] = { var.startSeriesZ }

set global.nxtCannedCycle[1] = { var.tZ }
set global.nxtCannedCycle[2] = { var.tR }
set global.nxtCannedCycle[4] = { var.tF }
set global.nxtCannedCycle[6] = { global.nxtCannedRetractMode }
set global.nxtCannedCycle[7] = { var.tP }

set var.tZ = { global.nxtCannedCycle[1] }
set var.tR = { global.nxtCannedCycle[2] }
set var.tF = { global.nxtCannedCycle[4] }
set var.tP = { global.nxtCannedCycle[7] }

if { var.tR <= var.tZ }
    abort { "G89: R must be above Z" }

set global.nxtCannedPreR = { var.tR }
set global.nxtCannedPreX = { var.tX }
set global.nxtCannedPreY = { var.tY }
M98 P"nxt-canned-preliminary.g"

var seriesZ = { global.nxtCannedCycle[5] }
var mode = { global.nxtCannedCycle[6] }
var endZ = { mode == 99 ? var.tR : (var.seriesZ > var.tR ? var.seriesZ : var.tR) }

G90 G1 Z{var.tZ} F{var.tF}
G4 S{var.tP}
G90 G1 Z{var.endZ} F{var.tF}
