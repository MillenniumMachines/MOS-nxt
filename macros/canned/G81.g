; G81.g — Simple drilling cycle (LinuxCNC G81 analogue)
; Absolute X Y Z R F in work coordinates. G91 incremental hole patterns and L repeats are NOT supported.
; Set retract mode with G98 / G99 before the cycle. Spindle must be on (M3/M4).

if { !inputs[state.thisInput].active }
    M99

M98 P"nxt-canned-spindle.g"
M98 P"nxt-canned-zindex.g"

var zi = { global.nxtCannedZi }
var startSeriesZ = { move.axes[var.zi].userPosition }

if { global.nxtCannedCycle != null && global.nxtCannedCycle[0] != 81 }
    set global.nxtCannedCycle = { null }

var prev = { global.nxtCannedCycle }
var tZ = { exists(param.Z) ? param.Z : (var.prev != null ? var.prev[1] : null) }
var tR = { exists(param.R) ? param.R : (var.prev != null ? var.prev[2] : null) }
var tF = { exists(param.F) ? param.F : (var.prev != null ? var.prev[4] : null) }
var tX = { exists(param.X) ? param.X : null }
var tY = { exists(param.Y) ? param.Y : null }

if { var.prev == null }
    if { var.tZ == null || var.tR == null || var.tF == null }
        abort { "G81: Z, R, and F required on first use after G80 or other cycle" }
    set global.nxtCannedCycle = { vector(9, null) }
    set global.nxtCannedCycle[0] = { 81 }
    set global.nxtCannedCycle[3] = { null }
    set global.nxtCannedCycle[7] = { null }

; G98 initial Z: taken at the start of a series, i.e. the first cycle after G80 or another
; cycle, or when Z has moved since the last final retract ([8]), e.g. a CAM G0 between operations.
if { global.nxtCannedCycle[8] == null || abs(var.startSeriesZ - global.nxtCannedCycle[8]) > 0.001 }
    set global.nxtCannedCycle[5] = { var.startSeriesZ }

set global.nxtCannedCycle[1] = { var.tZ }
set global.nxtCannedCycle[2] = { var.tR }
set global.nxtCannedCycle[4] = { var.tF }
set global.nxtCannedCycle[6] = { global.nxtCannedRetractMode }

set var.tZ = { global.nxtCannedCycle[1] }
set var.tR = { global.nxtCannedCycle[2] }
set var.tF = { global.nxtCannedCycle[4] }

if { var.tR <= var.tZ }
    abort { "G81: R must be above Z (tool clearance above hole bottom)" }

set global.nxtCannedPreR = { var.tR }
set global.nxtCannedPreX = { var.tX }
set global.nxtCannedPreY = { var.tY }
M98 P"nxt-canned-preliminary.g"

G90 G1 Z{var.tZ} F{var.tF}

set global.nxtCannedRetR = { var.tR }
M98 P"nxt-canned-finish-retract.g"

; Wait for the hole's moves before returning. RRF holds a pause until the cycle macro
; returns, so it lands between holes. Without this the macro returns as soon as the moves
; are queued, a pause can land mid-hole, and the job resumes after the cycle (#78).
M400
