; nxt-ts-large-tool.g — INTERNAL (tpost): find the lowest point of a tool wider than the toolsetter pad
;
; As MillenniumOS G37: when the tool radius (nxtTT[tool][0], M4000 R) is larger than the pad
; radius (nxtToolSetterRadius), the cutting edge can be at the rim with a recessed centre (face
; mills, indexable cutters), so measuring only the centre makes the tool cut too deep. Touch the
; pad with points around the tool's radius, enough to cover the rim, and keep the highest trigger.
; Each rim touch goes down only to the centre activation Z, so a rim that is higher than the centre
; doesn't trigger and doesn't count. Points outside the machine limits are skipped.
;
; Params: X/Y toolsetter centre (machine), Z centre activation Z (machine), F probe feed.
; Expects the tool backed off above the pad at the centre. Result: global.nxtTsRimXY = {X, Y} of the
; highest rim trigger when it is above the centre (the tool is left above it at the start Z), else null.

if { !inputs[state.thisInput].active }
    M99

if { !exists(global.nxtTsRimXY) }
    global nxtTsRimXY = null
set global.nxtTsRimXY = null

var padR = 0
if { exists(global.nxtToolSetterRadius) && global.nxtToolSetterRadius != null }
    set var.padR = { global.nxtToolSetterRadius }
var toolR = 0
if { state.currentTool >= 0 && exists(global.nxtTT) && state.currentTool < #global.nxtTT && global.nxtTT[state.currentTool] != null }
    set var.toolR = { global.nxtTT[state.currentTool][0] }
if { var.padR <= 0 || var.toolR <= var.padR }
    M99

var points = { ceil((2 * pi * var.toolR) / (2 * var.padR)) }
var safeZ = { move.axes[2].machinePosition }
var probeId = { global.nxtToolSetterID }
echo { "tpost.g: tool radius " ^ var.toolR ^ " mm is larger than the toolsetter pad (" ^ var.padR ^ " mm): probing " ^ var.points ^ " rim points" }

var bestZ = { param.Z }
var bestX = null
var bestY = null
var probed = 0
while { iterations < var.points }
    var a = { 2 * pi * iterations / var.points }
    var tX = { param.X + var.toolR * cos(var.a) }
    var tY = { param.Y + var.toolR * sin(var.a) }
    if { var.tX < move.axes[0].min || var.tX > move.axes[0].max || var.tY < move.axes[1].min || var.tY > move.axes[1].max }
        echo { "tpost.g: rim point " ^ (iterations + 1) ^ " is outside the machine limits, skipped" }
        continue
    G53 G0 Z{var.safeZ}
    G53 G0 X{var.tX} Y{var.tY}
    G53 G38.3 K{var.probeId} F{param.F} Z{param.Z}
    M400
    set var.probed = { var.probed + 1 }
    if { sensors.probes[var.probeId].value[0] != 0 }
        var hitZ = { move.axes[2].machinePosition }
        if { var.hitZ > var.bestZ }
            set var.bestZ = { var.hitZ }
            set var.bestX = { var.tX }
            set var.bestY = { var.tY }
    G53 G0 Z{var.safeZ}

if { var.bestX == null }
    echo { "tpost.g: no rim point is lower than the centre (" ^ var.probed ^ " of " ^ var.points ^ " probed)" }
    G53 G0 X{param.X} Y{param.Y}
    M99

echo { "tpost.g: lowest rim point at X" ^ var.bestX ^ " Y" ^ var.bestY ^ ", " ^ (var.bestZ - param.Z) ^ " mm below the centre (" ^ var.probed ^ " of " ^ var.points ^ " probed)" }
G53 G0 X{var.bestX} Y{var.bestY}
set global.nxtTsRimXY = { var.bestX, var.bestY }
