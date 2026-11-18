; nxt-canned-zindex.g — INTERNAL: find Z axis index, set global.nxtCannedZi
; Called via M98 from canned cycle macros only.

var zi = 0
while { var.zi < #move.axes }
    if { move.axes[var.zi].letter == "Z" }
        set global.nxtCannedZi = { var.zi }
        M99
    set var.zi = { var.zi + 1 }

abort { "nxt-canned: no Z axis in machine configuration" }
