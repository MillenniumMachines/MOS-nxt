; G73.g — Chip-break drilling cycle (LinuxCNC G73 analogue: short retract between pecks, not full R)
; Absolute Z R Q F. G91 / L not supported. Use G98/G99 for final retract. Spindle on required.

if { !inputs[state.thisInput].active }
    M99

M98 P"nxt-canned-spindle.g"
M98 P"nxt-canned-zindex.g"

var zi = { global.nxtCannedZi }
var startSeriesZ = { move.axes[var.zi].userPosition }

if { global.nxtCannedCycle != null && global.nxtCannedCycle[0] != 73 }
    set global.nxtCannedCycle = { null }

var prev = { global.nxtCannedCycle }
var tZ = { exists(param.Z) ? param.Z : (var.prev != null ? var.prev[1] : null) }
var tR = { exists(param.R) ? param.R : (var.prev != null ? var.prev[2] : null) }
var tQ = { exists(param.Q) ? param.Q : (var.prev != null ? var.prev[3] : null) }
var tF = { exists(param.F) ? param.F : (var.prev != null ? var.prev[4] : null) }
var tX = { exists(param.X) ? param.X : null }
var tY = { exists(param.Y) ? param.Y : null }

if { var.prev == null }
    if { var.tZ == null || var.tR == null || var.tQ == null || var.tF == null }
        abort { "G73: Z, R, Q, and F required on first use after G80 or other cycle" }
    if { var.tQ <= 0 }
        abort { "G73: Q (peck increment) must be positive" }
    set global.nxtCannedCycle = { vector(9, null) }
    set global.nxtCannedCycle[0] = { 73 }
    set global.nxtCannedCycle[7] = { null }

; G98 initial Z: taken at the start of a series, i.e. the first cycle after G80 or another
; cycle, or when Z has moved since the last final retract ([8]), e.g. a CAM G0 between operations.
if { global.nxtCannedCycle[8] == null || abs(var.startSeriesZ - global.nxtCannedCycle[8]) > 0.001 }
    set global.nxtCannedCycle[5] = { var.startSeriesZ }

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
    abort { "G73: Q must be positive" }

if { var.tR <= var.tZ }
    abort { "G73: R must be above Z" }

set global.nxtCannedPreR = { var.tR }
set global.nxtCannedPreX = { var.tX }
set global.nxtCannedPreY = { var.tY }
M98 P"nxt-canned-preliminary.g"

var chipClear = 0.254
var curBottom = { var.tR }
var eps = 0.0005

; Each pass feeds one peck deeper; the last peck lands exactly on Z and ends the loop.
while { var.curBottom > var.tZ + var.eps }
    var nextZ = { (var.curBottom - var.tQ <= var.tZ + var.eps) ? var.tZ : var.curBottom - var.tQ }
    G90 G1 Z{var.nextZ} F{var.tF}
    set var.curBottom = { var.nextZ }
    if { var.nextZ > var.tZ + var.eps }
        G90 G0 Z{var.nextZ + var.chipClear}

set global.nxtCannedRetR = { var.tR }
M98 P"nxt-canned-finish-retract.g"
