; nxt-canned-preliminary.g — INTERNAL: LinuxCNC-style canned preliminary XY/Z moves
; Preconditions: M98 P"nxt-canned-zindex.g" already run; G90 work coordinates.
; Inputs (globals): nxtCannedPreR (required), nxtCannedPreX / nxtCannedPreY (optional, nullable)

var zi = { global.nxtCannedZi }
var curZ = { move.axes[zi].userPosition }
var tR = { global.nxtCannedPreR }

if { curZ < tR }
    G90 G0 Z{tR}

if { global.nxtCannedPreX != null || global.nxtCannedPreY != null }
    var tx = { null }
    var ty = { null }
    var ai = 0
    while { ai < #move.axes }
        if { move.axes[ai].letter == "X" }
            set var.tx = { global.nxtCannedPreX != null ? global.nxtCannedPreX : move.axes[ai].userPosition }
        if { move.axes[ai].letter == "Y" }
            set var.ty = { global.nxtCannedPreY != null ? global.nxtCannedPreY : move.axes[ai].userPosition }
        set ai = { ai + 1 }
    if { var.tx == null || var.ty == null }
        abort { "nxt-canned: machine needs X and Y axes for canned XY positioning" }
    G90 G0 X{var.tx} Y{var.ty}

if { move.axes[zi].userPosition < tR }
    G90 G0 Z{tR}
