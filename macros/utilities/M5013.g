; M5013.g — set per-axis maintenance service threshold (mm)
; Usage: M5013 A<axisIndex> S<thresholdMm>
; Ensures nxtAxisServiceAt exists and is large enough before writing.
; Needed when nxt-vars.g ran before M584 and sized the vector to 0.

if { !exists(param.A) || param.A == null || param.A < 0 }
    abort { "M5013: need A<axisIndex> >= 0" }

if { !exists(param.S) || param.S == null || param.S < 0 }
    abort { "M5013: need S<thresholdMm> >= 0" }

var nxtIdx = { floor(param.A) }
var nxtNeed = { var.nxtIdx + 1 }
var nxtLen = { max(#move.axes, var.nxtNeed) }
set var.nxtLen = { max(var.nxtLen, 4) }

if { !exists(global.nxtAxisServiceAt) }
    global nxtAxisServiceAt = { vector(var.nxtLen, 0.0) }
elif { #global.nxtAxisServiceAt < var.nxtLen }
    var nxtOld = { global.nxtAxisServiceAt }
    set global.nxtAxisServiceAt = { vector(var.nxtLen, 0.0) }
    var nxtCopy = 0
    while { var.nxtCopy < #var.nxtOld }
        set global.nxtAxisServiceAt[var.nxtCopy] = { var.nxtOld[var.nxtCopy] }
        set var.nxtCopy = { var.nxtCopy + 1 }

set global.nxtAxisServiceAt[var.nxtIdx] = { param.S }
M99
