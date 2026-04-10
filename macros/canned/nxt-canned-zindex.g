; nxt-canned-zindex.g — INTERNAL: find Z axis index, set global.nxtCannedZi
; Called via M98 from canned cycle macros only.

var zi = 0
while { zi < #move.axes }
    if { move.axes[zi].letter == "Z" }
        set global.nxtCannedZi = { zi }
        M99
    set zi = { zi + 1 }

abort { "nxt-canned: no Z axis in machine configuration" }
