; G85.g — Boring: feed in, feed out to R, then rapid clear (LinuxCNC G85 analogue)
; First block: Z, R, F. Sticky parameters. G91 / L not supported.

if { !inputs[state.thisInput].active }
    M99

M98 P"nxt-canned-spindle.g"
M98 P"nxt-canned-zindex.g"

var zi = { global.nxtCannedZi }
var startSeriesZ = { move.axes[zi].userPosition }

if { global.nxtCannedCycle != null && global.nxtCannedCycle[0] != 85 }
    set global.nxtCannedCycle = { null }

var prev = { global.nxtCannedCycle }
var tZ = { exists(param.Z) ? param.Z : (prev != null ? prev[1] : null) }
var tR = { exists(param.R) ? param.R : (prev != null ? prev[2] : null) }
var tF = { exists(param.F) ? param.F : (prev != null ? prev[4] : null) }
var tX = { exists(param.X) ? param.X : null }
var tY = { exists(param.Y) ? param.Y : null }

if { prev == null }
    if { var.tZ == null || var.tR == null || var.tF == null }
        abort { "G85: Z, R, and F required on first use" }
    set global.nxtCannedCycle = { vector(8, null) }
    set global.nxtCannedCycle[0] = { 85 }
    set global.nxtCannedCycle[3] = { null }
    set global.nxtCannedCycle[5] = { var.startSeriesZ }
    set global.nxtCannedCycle[7] = { null }

set global.nxtCannedCycle[1] = { var.tZ }
set global.nxtCannedCycle[2] = { var.tR }
set global.nxtCannedCycle[4] = { var.tF }
set global.nxtCannedCycle[6] = { global.nxtCannedRetractMode }

set var.tZ = { global.nxtCannedCycle[1] }
set var.tR = { global.nxtCannedCycle[2] }
set var.tF = { global.nxtCannedCycle[4] }

if { var.tR <= var.tZ }
    abort { "G85: R must be above Z" }

set global.nxtCannedPreR = { var.tR }
set global.nxtCannedPreX = { var.tX }
set global.nxtCannedPreY = { var.tY }
M98 P"nxt-canned-preliminary.g"

G90 G1 Z{var.tZ} F{var.tF}
G90 G1 Z{var.tR} F{var.tF}

var seriesZ = { global.nxtCannedCycle[5] }
var mode = { global.nxtCannedCycle[6] }
var endZ = { mode == 99 ? var.tR : (var.seriesZ > var.tR ? var.seriesZ : var.tR) }
G90 G0 Z{var.endZ}
