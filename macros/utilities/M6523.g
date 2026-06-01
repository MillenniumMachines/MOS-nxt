; M6523.g: PROBE CYCLE OUTPUT CALIBRATION (repeatability)
;
; Runs multiple full G6512 Z cycles at a fixed reference surface (touch probe or toolsetter),
; then reports min, max, range, and mean. Use to tune probe repeatability limits.
;
; USAGE: M6523 [B<0|1>] [C<count>] [Z<targetZ>] [F<feed>] [L<limitMm>] [O<outerRetries>]
;
; Parameters:
;   B: Reference probe — 0 = touch probe, 1 = toolsetter (default: touch if enabled, else toolsetter)
;   C: Number of G6512 cycles (default 10, max 50)
;   Z: Machine Z target for G6512 (default: ref surface Z from configured position)
;   F, L, O: Passed to G6512 (L/O default from nxtTouchProbe* or nxtToolSetter* globals)

if { !inputs[state.thisInput].active }
    M99

var useTouch = false
if { exists(param.B) && param.B != null }
    if { param.B != 0 && param.B != 1 }
        abort { "M6523: B must be 0 (touch probe) or 1 (toolsetter)" }
    set var.useTouch = { param.B == 0 }
elif { global.nxtFeatureTouchProbe }
    set var.useTouch = true
elif { global.nxtFeatureToolSetter }
    set var.useTouch = false
else
    abort { "M6523: No touch probe or toolsetter feature enabled" }

var cycleTotal = { exists(param.C) && param.C != null ? floor(param.C) : 10 }
if { var.cycleTotal < 1 || var.cycleTotal > 50 }
    abort { "M6523: C must be 1..50" }

var refX = 0
var refY = 0
var refZ = 0
var probeId = 0
var limitMm = 0
var outerRetries = 0
var probeLabel = ""

if { var.useTouch }
    if { !global.nxtFeatureTouchProbe }
        abort { "M6523: Touch probe feature not enabled (B0)" }
    if { global.nxtTouchProbeRefPos == null }
        abort { "M6523: nxtTouchProbeRefPos not set — configure in DWC" }
    if { state.currentTool != global.nxtProbeToolID }
        var nxtM6523Tool = { "M6523: Select probe tool T" ^ global.nxtProbeToolID }
        abort { var.nxtM6523Tool }
    set var.refX = { global.nxtTouchProbeRefPos[0] }
    set var.refY = { global.nxtTouchProbeRefPos[1] }
    set var.refZ = { exists(param.Z) && param.Z != null ? param.Z : global.nxtTouchProbeRefPos[2] }
    set var.probeId = { global.nxtTouchProbeID }
    set var.limitMm = { exists(param.L) ? param.L : global.nxtTouchProbeMaxSampleSpreadMm }
    set var.outerRetries = { exists(param.O) ? floor(param.O) : global.nxtTouchProbeSampleOuterRetries }
    set var.probeLabel = "touch"
else
    if { !global.nxtFeatureToolSetter }
        abort { "M6523: Toolsetter feature not enabled (B1)" }
    if { global.nxtToolSetterPos == null }
        abort { "M6523: nxtToolSetterPos not configured" }
    set var.refX = { global.nxtToolSetterPos[0] }
    set var.refY = { global.nxtToolSetterPos[1] }
    set var.refZ = { exists(param.Z) && param.Z != null ? param.Z : global.nxtToolSetterPos[2] }
    set var.probeId = { global.nxtToolSetterID }
    set var.limitMm = { exists(param.L) ? param.L : global.nxtToolSetterMaxSampleSpreadMm }
    set var.outerRetries = { exists(param.O) ? floor(param.O) : global.nxtToolSetterSampleOuterRetries }
    set var.probeLabel = "toolsetter"

var safeZ = { var.refZ + 10 }
M5000
M6515 X{var.refX} Y{var.refY} Z{var.refZ}
M6515 Z{var.safeZ}

var hasFeed = { exists(param.F) && param.F != null }

echo "M6523: " ^ var.cycleTotal ^ " cycles, " ^ var.probeLabel ^ " probe I" ^ var.probeId
echo "M6523: Target Z=" ^ var.refZ ^ " mm, pair limit L=" ^ var.limitMm ^ " mm"

G53 G0 X{var.refX} Y{var.refY}
G53 G0 Z{var.safeZ}

var cycleIdx = 0
var sumZ = 0
var minZ = 0
var maxZ = 0
var haveSample = false

while { var.cycleIdx < var.cycleTotal }
    set var.cycleIdx = { var.cycleIdx + 1 }
    if { var.hasFeed }
        G6512 Z{var.refZ} I{var.probeId} F{param.F} L{var.limitMm} O{var.outerRetries}
    if { !var.hasFeed }
        G6512 Z{var.refZ} I{var.probeId} L{var.limitMm} O{var.outerRetries}
    var z = { global.nxtLastProbeResult }
    if { !var.haveSample }
        set var.minZ = var.z
        set var.maxZ = var.z
        set var.haveSample = true
    if { var.haveSample && var.z < var.minZ }
        set var.minZ = var.z
    if { var.haveSample && var.z > var.maxZ }
        set var.maxZ = var.z
    set var.sumZ = { var.sumZ + var.z }
    var nxtM6523Line = { "M6523: cycle " ^ var.cycleIdx ^ "/" ^ var.cycleTotal ^ " Z=" ^ var.z }
    echo { var.nxtM6523Line ^ " mm" }
    if { var.cycleIdx < var.cycleTotal }
        G27 Z1

var meanZ = { var.sumZ / var.cycleTotal }
var rangeZ = { var.maxZ - var.minZ }

echo "M6523: Summary — min=" ^ var.minZ ^ " max=" ^ var.maxZ ^ " range=" ^ var.rangeZ ^ " mean=" ^ var.meanZ
if { var.limitMm > 0 && var.rangeZ > var.limitMm }
    var nxtM6523Warn = { "M6523: Range exceeds L=" ^ var.limitMm }
    echo { var.nxtM6523Warn ^ " mm — tune nxt-user-overrides.g or Configuration" }
elif { var.limitMm > 0 }
    echo "M6523: Range within configured pair limit L=" ^ var.limitMm ^ " mm"
echo "M6523: Target repeatability < 0.005 mm — see docs/CALIBRATION.md"
