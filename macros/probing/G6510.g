; G6510.g: SINGLE SURFACE PROBE
;
; One G6512 against exactly one axis word (X, Y, or Z); target coordinate is the destination on
; that axis, others stay at current. Writes only the probed axis into nxtProbeResults[row];
; θ slot unchanged unless zero-filled on first use — M6520 with X/Y/Z singly does not apply G68.
; U chains M6520 with the matching axis letter(s) for WCS update.
; Z: G6512 raw trigger (no D, no tip R); M6520 Z1 sets WCS; return to startZ.
;
; USAGE: G6510 P|U [X|Y|Z] [F] [R] [Q]

if { !inputs[state.thisInput].active }
    M99

if { !global.nxtFeatureTouchProbe }
    abort { "G6510: Touch probe feature not enabled" }

if { global.nxtTouchProbeID == null }
    abort { "G6510: Touch probe ID not configured" }

var pSlot = null
if { exists(param.U) && param.U != null }
    if { param.U < 1 || param.U > 9 }
        abort { "G6510: U must be 1-9" }
    set var.pSlot = { param.U - 1 }
elif { exists(param.P) && param.P != null }
    set var.pSlot = { param.P }
else
    abort { "G6510: P or U required" }

if { var.pSlot < 0 || var.pSlot >= #global.nxtProbeResults }
    abort { "G6510: Result slot out of range" }

var axisParams = { null, null, null }
if { exists(param.X) }
    set var.axisParams[0] = { param.X }
if { exists(param.Y) }
    set var.axisParams[1] = { param.Y }
if { exists(param.Z) }
    set var.axisParams[2] = { param.Z }
var probeAxis = -1
var targetCoord = 0

while { iterations < #var.axisParams }
    if { var.axisParams[iterations] != null }
        if { var.probeAxis != -1 }
            abort { "G6510: Exactly one of X, Y, or Z" }
        set var.probeAxis = { iterations }
        set var.targetCoord = { var.axisParams[iterations] }

if { var.probeAxis == -1 }
    abort { "G6510: One axis required" }

if { state.currentTool != global.nxtProbeToolID }
    abort { "G6510: Touch probe (T" ^ global.nxtProbeToolID ^ ") must be selected" }

echo "G6510: Single surface " ^ move.axes[var.probeAxis].letter

M5000
var startZ = { global.nxtAbsPos[2] }

var probeFeed = { exists(param.F) ? param.F : null }
var probeRetries = { exists(param.R) ? param.R : global.nxtProbeInnerSampleCount }

; G6512 accepts exactly one axis word — dispatch the validated probe axis only
if { var.probeAxis == 0 }
    G6512 X{var.targetCoord} I{global.nxtTouchProbeID} F{var.probeFeed} R{var.probeRetries}
elif { var.probeAxis == 1 }
    G6512 Y{var.targetCoord} I{global.nxtTouchProbeID} F{var.probeFeed} R{var.probeRetries}
else
    G6512 Z{var.targetCoord} I{global.nxtTouchProbeID} F{var.probeFeed} R{var.probeRetries}

if { global.nxtProbeResults[var.pSlot] == null || #global.nxtProbeResults[var.pSlot] < 3 }
    set global.nxtProbeResults[var.pSlot] = { vector(#move.axes + 1, 0.0) }

set global.nxtProbeResults[var.pSlot][var.probeAxis] = { global.nxtLastProbeResult }

echo "G6510: Index " ^ var.pSlot ^ " " ^ move.axes[var.probeAxis].letter ^ "=" ^ global.nxtLastProbeResult

if { exists(param.U) && param.U != null }
    if { var.probeAxis == 0 }
        if { exists(param.Q) && param.Q != null }
            M6520 P{var.pSlot} W{param.U} X1 Q{param.Q}
        else
            M6520 P{var.pSlot} W{param.U} X1
    elif { var.probeAxis == 1 }
        if { exists(param.Q) && param.Q != null }
            M6520 P{var.pSlot} W{param.U} Y1 Q{param.Q}
        else
            M6520 P{var.pSlot} W{param.U} Y1
    else
        if { exists(param.Q) && param.Q != null }
            M6520 P{var.pSlot} W{param.U} Z1 Q{param.Q}
        else
            M6520 P{var.pSlot} W{param.U} Z1
        ; Return to jog start height (not work Z0 / Z max)
        G53 G0 Z{var.startZ}
        echo "G6510: Returned to start Z=" ^ var.startZ
elif { var.probeAxis == 2 }
    ; No U — still leave Z at start height after probe
    G53 G0 Z{var.startZ}
    echo "G6510: Returned to start Z=" ^ var.startZ