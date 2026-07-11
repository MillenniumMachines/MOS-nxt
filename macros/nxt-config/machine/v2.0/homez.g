; homez.g — nxt platform v2.0 (Milo v2.0)
; Requirements: see docs/NXT_BOARD_HOMING.md (v2.0 — Z reversed drive, G92 at top)

; homez.g - Homes Z.

; Relative positioning in mm and mm/min
G91
G21
G94

; G92 to set the Z height takes existing tool offsets into
; account, which can cause us to try to move outside of
; machine limits.
; To avoid this, we store the tool Z offset and restore it
; after homing.
var toolZ = null

if { state.currentTool != -1 }
    set var.toolZ = { tools[state.currentTool].offsets[2] }
    G10 L1 P{state.currentTool} Z0

; Move toward Z endstop at high speed (inverted drive vs v1.5)
G53 G1 H1 Z{move.axes[2].max - move.axes[2].min + 5} F{1800}

; Endstop should now be triggered, verify
if { ! sensors.endstops[2].triggered }
    abort {"Z endstop not triggered after full axis travel. Check that your Z motor is connected and the endstop is working!"}

; Move away from Z endstop
G53 G1 H2 Z{-5}

; Repeat Z home at low speed. Do not move further than
; 2 * 5 above the expected endstop location.
G53 G1 H1 Z{5*2} F{180}

; Set Z position to axis maximum
G53 G92 Z{move.axes[2].max}

; Restore tool offset after homing
if { var.toolZ != null }
    G10 L1 P{state.currentTool} Z{var.toolZ}
