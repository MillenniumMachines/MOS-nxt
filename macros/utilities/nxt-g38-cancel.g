; nxt-g38-cancel.g: REPLACE LEFTOVER G38 INTERPOLATOR
;
; Zero-length G53 G1 of the current pose is skipped by the planner, so
; leftover G38 survives and a later G0 X0 Y0 becomes machine home.
; Non-zero G53 Z nudge + restore, then non-G53 G91 all-axis nudge + back.
; Last command must be G90 (never end on G53). Never omit XY.

if { !inputs[state.thisInput].active }
    M99

M400
G90
var pinFeed = { 3000 }
var pinPid = { global.nxtTouchProbeID }
if { var.pinPid != null && sensors.probes[var.pinPid] != null }
    set var.pinFeed = { sensors.probes[var.pinPid].travelSpeed }

var pinX = { move.axes[0].machinePosition }
var pinY = { move.axes[1].machinePosition }
var pinZ = { move.axes[2].machinePosition }
var pinHasA = { #move.axes > 3 }
var pinA = { 0 }
if { var.pinHasA }
    set var.pinA = { move.axes[3].machinePosition }

var nudge = { 0.05 }
var zMax = { move.axes[2].max }
var zMin = { move.axes[2].min }
var nY = { 0 }
var nZ = { var.nudge }
var nxtZUp = { var.pinZ + var.nudge }
var nxtCanUp = { var.nxtZUp <= var.zMax }
if { !var.nxtCanUp }
    set var.nZ = { 0 - var.nudge }
var nxtZDn = { var.pinZ - var.nudge }
var nxtCanDn = { var.nxtZDn >= var.zMin }
if { !var.nxtCanUp && !var.nxtCanDn }
    set var.nZ = { 0 }

if { var.nZ == 0 }
    var yMax = { move.axes[1].max }
    var yMin = { move.axes[1].min }
    var nxtYUp = { var.pinY + var.nudge }
    if { var.nxtYUp <= var.yMax }
        set var.nY = { var.nudge }
    elif { var.pinY - var.nudge >= var.yMin }
        set var.nY = { 0 - var.nudge }

echo "nxt-g38-cancel: drain nudge dY=" ^ var.nY ^ " dZ=" ^ var.nZ

var goY = { var.pinY + var.nY }
var goZ = { var.pinZ + var.nZ }
if { var.pinHasA }
    G53 G1 F{var.pinFeed} X{var.pinX} Y{var.goY} Z{var.goZ} A{var.pinA}
else
    G53 G1 F{var.pinFeed} X{var.pinX} Y{var.goY} Z{var.goZ}
M400
if { var.pinHasA }
    G53 G1 F{var.pinFeed} X{var.pinX} Y{var.pinY} Z{var.pinZ} A{var.pinA}
else
    G53 G1 F{var.pinFeed} X{var.pinX} Y{var.pinY} Z{var.pinZ}
M400

; Non-G53 all-axis relative skip (binds work interpolator, not G53)
G90
G91
var relY = { var.nY }
var relZ = { var.nZ }
if { var.relY == 0 && var.relZ == 0 }
    set var.relZ = { var.nudge }
if { var.pinHasA }
    G1 F{var.pinFeed} X0 Y{var.relY} Z{var.relZ} A0
else
    G1 F{var.pinFeed} X0 Y{var.relY} Z{var.relZ}
M400
if { var.pinHasA }
    G1 F{var.pinFeed} X0 Y{0 - var.relY} Z{0 - var.relZ} A0
else
    G1 F{var.pinFeed} X0 Y{0 - var.relY} Z{0 - var.relZ}
M400
G90

echo "nxt-g38-cancel: machine X=" ^ move.axes[0].machinePosition ^ " Y=" ^ move.axes[1].machinePosition
echo "nxt-g38-cancel: user X=" ^ move.axes[0].userPosition ^ " Y=" ^ move.axes[1].userPosition
echo "nxt-g38-cancel: homed X=" ^ move.axes[0].homed ^ " Y=" ^ move.axes[1].homed
