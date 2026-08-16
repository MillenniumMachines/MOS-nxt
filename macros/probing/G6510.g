; G6510.g: SINGLE SURFACE PROBE
;
; Operator-relative face N (Left/Right/Front/Back/Top) or legacy X|Y|Z target.
; Z/Top: one G6512 (multi-point Z deferred).
; X/Y: optional S = face length along the face; adaptive 1/3-pt about jog station.
; Optional L dives XY from jog Z before the face probe.
;
; USAGE: G6510 P|U N[0-4] [O] [S] [E] [L] [F] [R] [Q]
;   N: 0 Left +X, 1 Right -X, 2 Front +Y, 3 Back -Y, 4 Top -Z
; Legacy: G6510 P|U X|Y|Z [S] [E] [F] [R] [Q] (absolute machine target)

if { !inputs[state.thisInput].active }
    M99

if { !exists(global.nxtSkipJobPark) }
    global nxtSkipJobPark = true
else
    set global.nxtSkipJobPark = true

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

var hasFace = { exists(param.N) && param.N != null }
var axisParams = { null, null, null }
if { exists(param.X) }
    set var.axisParams[0] = { param.X }
if { exists(param.Y) }
    set var.axisParams[1] = { param.Y }
if { exists(param.Z) }
    set var.axisParams[2] = { param.Z }
var probeAxis = -1
var targetCoord = 0
var faceIdx = null

while { iterations < #var.axisParams }
    if { var.axisParams[iterations] != null }
        if { var.probeAxis != -1 }
            abort { "G6510: Exactly one of X, Y, or Z" }
        set var.probeAxis = { iterations }
        set var.targetCoord = { var.axisParams[iterations] }

var hasAxis = { var.probeAxis != -1 }
if { var.hasFace && var.hasAxis }
    abort { "G6510: Use N (face) or one of X, Y, Z — not both" }

if { !var.hasFace && !var.hasAxis }
    abort { "G6510: Face N or one of X, Y, Z is required" }

if { var.hasFace }
    if { param.N < 0 || param.N > 4 }
        abort { "G6510: Face N must be 0-4 (Left Right Front Back Top)" }
    set var.faceIdx = { param.N }

if { state.currentTool != global.nxtProbeToolID }
    abort { "G6510: Touch probe (T" ^ global.nxtProbeToolID ^ ") must be selected" }

M5000
var startX = { global.nxtAbsPos[0] }
var startY = { global.nxtAbsPos[1] }
var startZ = { global.nxtAbsPos[2] }

if { var.hasFace }
    var travel = { exists(param.O) ? param.O : 5.0 }
    if { var.travel == null || var.travel <= 0 }
        abort { "G6510: Travel O must be positive" }
    ; Operator at front: -Y toward operator, +X to the right
    if { var.faceIdx == 0 }
        set var.probeAxis = 0
        set var.targetCoord = { var.startX + var.travel }
    elif { var.faceIdx == 1 }
        set var.probeAxis = 0
        set var.targetCoord = { var.startX - var.travel }
    elif { var.faceIdx == 2 }
        set var.probeAxis = 1
        set var.targetCoord = { var.startY + var.travel }
    elif { var.faceIdx == 3 }
        set var.probeAxis = 1
        set var.targetCoord = { var.startY - var.travel }
    else
        set var.probeAxis = 2
        set var.targetCoord = { var.startZ - var.travel }

var sName = { move.axes[var.probeAxis].letter }
if { var.faceIdx != null && exists(global.nxtSurfaceNames) }
    set var.sName = { global.nxtSurfaceNames[var.faceIdx] }
echo "G6510: Single surface " ^ var.sName

var probeFeed = { exists(param.F) ? param.F : null }
var probeRetries = { exists(param.R) ? param.R : global.nxtProbeInnerSampleCount }
var faceLen = { exists(param.S) ? param.S : null }
var edgeInset = { exists(param.E) ? param.E : global.nxtCornerOffset }
if { var.edgeInset == null || var.edgeInset <= 0 }
    set var.edgeInset = 5.0

; Optional L: dive XY from jog Z. Top ignores L.
var probeZ = { var.startZ }
var hasL = false
if { var.probeAxis != 2 }
    if { exists(param.L) && param.L != null }
        if { param.L <= 0 }
            abort { "G6510: Depth L must be positive" }
        set var.hasL = true
        set var.probeZ = { var.startZ - param.L }

var surfVal = { null }
var thetaDeg = 0

; Z / Top — single point only (multi-Z deferred)
if { var.probeAxis == 2 }
    G6512 Z{var.targetCoord} I{global.nxtTouchProbeID} F{var.probeFeed} R{var.probeRetries}
    set var.surfVal = { global.nxtLastProbeResult }

; X/Y without S — single point (legacy / jog)
elif { var.faceLen == null }
    if { var.hasL }
        G6550 Z{var.probeZ}
    if { var.probeAxis == 0 }
        G6512 X{var.targetCoord} I{global.nxtTouchProbeID} F{var.probeFeed} R{var.probeRetries}
    else
        G6512 Y{var.targetCoord} I{global.nxtTouchProbeID} F{var.probeFeed} R{var.probeRetries}
    set var.surfVal = { global.nxtLastProbeResult }

; X/Y with S — adaptive multi-point centered on jog station
else
    if { var.faceLen <= 0 }
        abort { "G6510: Face length S must be positive" }
    ; Span starts at station − S/2, steps +along away from that origin
    if { var.probeAxis == 0 }
        var along0 = { var.startY - var.faceLen / 2 }
        M98 P"nxt-probe-face-line.g" A0 T{var.targetCoord} W{var.startX} J{var.startX} K{var.along0} D1 S{var.faceLen} E{var.edgeInset} Z{var.probeZ} F{var.probeFeed} R{var.probeRetries}
        var x0 = { global.nxtProbeHitXY[0] }
        var y0 = { global.nxtProbeHitXY[1] }
        var x1 = { global.nxtProbeHitXY[2] }
        var y1 = { global.nxtProbeHitXY[3] }
        if { global.nxtFaceLineN <= 1 }
            set var.surfVal = { var.x0 }
        else
            var dy = { var.y1 - var.y0 }
            if { abs(var.dy) < 0.0005 }
                set var.surfVal = { (var.x0 + var.x1) / 2 }
            else
                set var.surfVal = { var.x0 + (var.x1 - var.x0) * (var.startY - var.y0) / var.dy }
            set var.thetaDeg = { degrees(atan2(var.y1 - var.y0, var.x1 - var.x0)) }
            if { var.thetaDeg > 90 }
                set var.thetaDeg = { var.thetaDeg - 180 }
            elif { var.thetaDeg <= -90 }
                set var.thetaDeg = { var.thetaDeg + 180 }
    else
        var along0Y = { var.startX - var.faceLen / 2 }
        M98 P"nxt-probe-face-line.g" A1 T{var.targetCoord} W{var.startY} J{var.along0Y} K{var.startY} D1 S{var.faceLen} E{var.edgeInset} Z{var.probeZ} F{var.probeFeed} R{var.probeRetries}
        var px0 = { global.nxtProbeHitXY[0] }
        var py0 = { global.nxtProbeHitXY[1] }
        var px1 = { global.nxtProbeHitXY[2] }
        var py1 = { global.nxtProbeHitXY[3] }
        if { global.nxtFaceLineN <= 1 }
            set var.surfVal = { var.py0 }
        else
            var dx = { var.px1 - var.px0 }
            if { abs(var.dx) < 0.0005 }
                set var.surfVal = { (var.py0 + var.py1) / 2 }
            else
                set var.surfVal = { var.py0 + (var.py1 - var.py0) * (var.startX - var.px0) / var.dx }
            set var.thetaDeg = { degrees(atan2(var.py1 - var.py0, var.px1 - var.px0)) }
            if { var.thetaDeg > 90 }
                set var.thetaDeg = { var.thetaDeg - 180 }
            elif { var.thetaDeg <= -90 }
                set var.thetaDeg = { var.thetaDeg + 180 }

if { global.nxtProbeResults[var.pSlot] == null || #global.nxtProbeResults[var.pSlot] < 3 }
    set global.nxtProbeResults[var.pSlot] = { vector(#move.axes + 1, 0.0) }

set global.nxtProbeResults[var.pSlot][var.probeAxis] = { var.surfVal }
if { var.probeAxis != 2 }
    set global.nxtProbeResults[var.pSlot][#move.axes] = { var.thetaDeg }

echo "G6510: Index " ^ var.pSlot ^ " " ^ move.axes[var.probeAxis].letter ^ "=" ^ var.surfVal

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

var nxtParkFeed = { sensors.probes[global.nxtTouchProbeID].travelSpeed }
var nxtPinX = { move.axes[0].machinePosition }
var nxtPinY = { move.axes[1].machinePosition }
var nxtPinA = 0
if { #move.axes > 3 }
    set var.nxtPinA = { move.axes[3].machinePosition }
if { var.probeAxis == 2 }
    if { #move.axes > 3 }
        G53 G1 F{var.nxtParkFeed} X{var.nxtPinX} Y{var.nxtPinY} Z{var.startZ} A{var.nxtPinA}
    else
        G53 G1 F{var.nxtParkFeed} X{var.nxtPinX} Y{var.nxtPinY} Z{var.startZ}
    echo "G6510: Returned to start Z=" ^ var.startZ
M98 P"nxt-g38-cancel.g"
