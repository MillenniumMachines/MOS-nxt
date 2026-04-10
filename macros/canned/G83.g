; G83.g — Peck drilling with full retract to R (LinuxCNC G83 analogue)
; Absolute Z R Q F. G91 / L not supported. Spindle on required.

if { !inputs[state.thisInput].active }
    M99

M98 P"nxt-canned-spindle.g"
M98 P"nxt-canned-zindex.g"

var zi = { global.nxtCannedZi }
var startSeriesZ = { move.axes[zi].userPosition }

if { global.nxtCannedCycle != null && global.nxtCannedCycle[0] != 83 }
    set global.nxtCannedCycle = { null }

var prev = { global.nxtCannedCycle }
var tZ = { exists(param.Z) ? param.Z : (prev != null ? prev[1] : null) }
var tR = { exists(param.R) ? param.R : (prev != null ? prev[2] : null) }
var tQ = { exists(param.Q) ? param.Q : (prev != null ? prev[3] : null) }
var tF = { exists(param.F) ? param.F : (prev != null ? prev[4] : null) }
var tX = { exists(param.X) ? param.X : null }
var tY = { exists(param.Y) ? param.Y : null }

if { prev == null }
    if { var.tZ == null || var.tR == null || var.tQ == null || var.tF == null }
        abort { "G83: Z, R, Q, and F required on first use after G80 or other cycle" }
    if { var.tQ <= 0 }
        abort { "G83: Q (peck increment) must be positive" }
    set global.nxtCannedCycle = { vector(8, null) }
    set global.nxtCannedCycle[0] = { 83 }
    set global.nxtCannedCycle[5] = { var.startSeriesZ }
    set global.nxtCannedCycle[7] = { null }

set global.nxtCannedCycle[1] = { var.tZ }
set global.nxtCannedCycle[2] = { var.tR }
set global.nxtCannedCycle[3] = { var.tQ }
set global.nxtCannedCycle[4] = { var.tF }
set global.nxtCannedCycle[6] = { global.nxtCannedRetractMode }

set var.tZ = { global.nxtCannedCycle[1] }
set var.tR = { global.nxtCannedCycle[2] }
set var.tQ = { global.nxtCannedCycle[3] }
set var.tF = { global.nxtCannedCycle[4] }

if { var.tQ <= 0 }
    abort { "G83: Q must be positive" }

if { var.tR <= var.tZ }
    abort { "G83: R must be above Z" }

set global.nxtCannedPreR = { var.tR }
set global.nxtCannedPreX = { var.tX }
set global.nxtCannedPreY = { var.tY }
M98 P"nxt-canned-preliminary.g"

var chipClear = 0.254
var curBottom = { var.tR }
var eps = 0.0005

while { var.curBottom > var.tZ + var.eps }
    var nextZ = { max(var.tZ, var.curBottom - var.tQ) }
    G90 G1 Z{var.nextZ} F{var.tF}
    if { var.nextZ > var.tZ + var.eps }
        G90 G0 Z{var.tR}
        G90 G0 Z{var.nextZ + var.chipClear}
        set var.curBottom = { var.nextZ }

set global.nxtCannedRetR = { var.tR }
M98 P"nxt-canned-finish-retract.g"
