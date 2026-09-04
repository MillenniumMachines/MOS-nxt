; nxt-wcs-g10-apply.g: shared G10 L2 combinatorics (M6520 / nxt-wcs-apply)
;
; Caller sets declare-on-use offsets (null = omit axis):
;   global.nxtWcsG10X / Y / Z / A
; USAGE: M98 P"nxt-wcs-g10-apply.g" W<wcsNumber>
;
; Never G10 L20. Does not select WCS, park, or clear G68.

if { !inputs[state.thisInput].active }
    M99

if { !exists(param.W) || param.W == null || param.W < 1 || param.W > 9 }
    abort { "nxt-wcs-g10-apply: W must be 1-9" }

if { !exists(global.nxtWcsG10X) }
    global nxtWcsG10X = null
if { !exists(global.nxtWcsG10Y) }
    global nxtWcsG10Y = null
if { !exists(global.nxtWcsG10Z) }
    global nxtWcsG10Z = null
if { !exists(global.nxtWcsG10A) }
    global nxtWcsG10A = null

var wcsNumber = { param.W }
var offsetX = { global.nxtWcsG10X }
var offsetY = { global.nxtWcsG10Y }
var offsetZ = { global.nxtWcsG10Z }
var offsetA = { global.nxtWcsG10A }

M400

if { var.offsetX != null && var.offsetY != null && var.offsetZ != null && var.offsetA != null }
    G10 L2 P{var.wcsNumber} X{var.offsetX} Y{var.offsetY} Z{var.offsetZ} A{var.offsetA}
elif { var.offsetX != null && var.offsetY != null && var.offsetZ != null }
    G10 L2 P{var.wcsNumber} X{var.offsetX} Y{var.offsetY} Z{var.offsetZ}
elif { var.offsetX != null && var.offsetY != null && var.offsetA != null }
    G10 L2 P{var.wcsNumber} X{var.offsetX} Y{var.offsetY} A{var.offsetA}
elif { var.offsetX != null && var.offsetZ != null && var.offsetA != null }
    G10 L2 P{var.wcsNumber} X{var.offsetX} Z{var.offsetZ} A{var.offsetA}
elif { var.offsetY != null && var.offsetZ != null && var.offsetA != null }
    G10 L2 P{var.wcsNumber} Y{var.offsetY} Z{var.offsetZ} A{var.offsetA}
elif { var.offsetX != null && var.offsetY != null }
    G10 L2 P{var.wcsNumber} X{var.offsetX} Y{var.offsetY}
elif { var.offsetX != null && var.offsetZ != null }
    G10 L2 P{var.wcsNumber} X{var.offsetX} Z{var.offsetZ}
elif { var.offsetX != null && var.offsetA != null }
    G10 L2 P{var.wcsNumber} X{var.offsetX} A{var.offsetA}
elif { var.offsetY != null && var.offsetZ != null }
    G10 L2 P{var.wcsNumber} Y{var.offsetY} Z{var.offsetZ}
elif { var.offsetY != null && var.offsetA != null }
    G10 L2 P{var.wcsNumber} Y{var.offsetY} A{var.offsetA}
elif { var.offsetZ != null && var.offsetA != null }
    G10 L2 P{var.wcsNumber} Z{var.offsetZ} A{var.offsetA}
elif { var.offsetX != null }
    G10 L2 P{var.wcsNumber} X{var.offsetX}
elif { var.offsetY != null }
    G10 L2 P{var.wcsNumber} Y{var.offsetY}
elif { var.offsetZ != null }
    G10 L2 P{var.wcsNumber} Z{var.offsetZ}
elif { var.offsetA != null }
    G10 L2 P{var.wcsNumber} A{var.offsetA}
