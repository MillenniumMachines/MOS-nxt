; G6512.g: SINGLE-AXIS PROBING
;
; Deflection/tip compensation + optional multi-sample repeatability.
; Defaults: macros/system/nxt-vars.g (Probe repeatability).
; When nxtProbeMaxSampleSpreadMm > 0: strict consecutive-pair tolerance, 3 touches, R ignored.
; Per-invocation override: R = inner sample count when tolerance disabled (limit = 0).
;
; USAGE: G6512 [X|Y|Z|A]<pos> I<probeID> [F] [R] [L] [O] [H]
;   L = tolerance limit override in mm (default global.nxtProbeMaxSampleSpreadMm)
;   O = extra full 3-touch retry cycles when tolerance is enabled

if { !inputs[state.thisInput].active }
    M99

; --- Parameter Validation ---

var axisParams = { null, null, null, null }
if { exists(param.X) }
    set var.axisParams[0] = param.X
if { exists(param.Y) }
    set var.axisParams[1] = param.Y
if { exists(param.Z) }
    set var.axisParams[2] = param.Z
if { exists(param.A) }
    set var.axisParams[3] = param.A
var probeAxisIndex = -1

while { iterations < #var.axisParams }
    if { var.axisParams[iterations] != null }
        if { var.probeAxisIndex != -1 }
            abort { "G6512: Exactly one of X, Y, Z, or A must be specified"}
        set var.probeAxisIndex = { iterations }

if { var.probeAxisIndex == -1 }
    abort { "G6512: Exactly one of X, Y, Z, or A must be specified" }

if { !exists(param.I) || param.I == null || param.I < 0 || sensors.probes[param.I].type < 5 || sensors.probes[param.I].type > 8 }
    abort { "G6512: Invalid probe ID I" }

if { exists(param.L) && param.L < 0 }
    abort { "G6512: Tolerance limit L must be >= 0" }
if { exists(param.O) && param.O < 0 }
    abort { "G6512: Outer retries O must be >= 0" }

var toleranceLimitMm = { exists(param.L) ? param.L : global.nxtProbeMaxSampleSpreadMm }
var outerRetries = { exists(param.O) ? floor(param.O) : global.nxtProbeSampleOuterRetries }
var toleranceEnabled = { var.toleranceLimitMm > 0 }
var retries = { exists(param.R) ? param.R : global.nxtProbeInnerSampleCount }
if { var.toleranceEnabled }
    set var.retries = 3
elif { var.retries < 1 }
    set var.retries = 1

var outerLimit = { var.toleranceEnabled ? var.outerRetries + 1 : 1 }

G90 G21 G94

M5000

var targetVector = { global.nxtAbsPos }
var hasA = { #var.targetVector > 3 }

set var.targetVector[0] = { exists(param.X) ? param.X : var.targetVector[0] }
set var.targetVector[1] = { exists(param.Y) ? param.Y : var.targetVector[1] }
set var.targetVector[2] = { exists(param.Z) ? param.Z : var.targetVector[2] }
if { var.hasA }
    set var.targetVector[3] = { exists(param.A) ? param.A : var.targetVector[3] }

if { var.hasA }
    M6515 X{var.targetVector[0]} Y{var.targetVector[1]} Z{var.targetVector[2]} A{var.targetVector[3]}
else
    M6515 X{var.targetVector[0]} Y{var.targetVector[1]} Z{var.targetVector[2]}

var roughSpeed = { exists(param.F) ? param.F : sensors.probes[param.I].speeds[0] }
var fineSpeed = { exists(param.F) ? param.F : sensors.probes[param.I].speeds[1] }

if { var.roughSpeed == var.fineSpeed && !exists(param.F) }
    set var.fineSpeed = { var.roughSpeed / 5 }

var probeDeflectionUm = { global.nxtProbeDeflection * 1000 }
var probeTipRadiusUm = { global.nxtProbeTipRadius * 1000 }

if { exists(param.H) && param.H != null && (param.H < 0 || param.H > 3) }
    abort { "G6512: Hit slot H must be 0..3 when provided" }

; --- Outer: repeat 3-touch block if consecutive-pair tolerance fails ---

var attempt = 0
var toleranceOk = false
var lastPairDeltaMm = 0.0
var lastPairOverMm = 0.0
var lastFailedPairLabel = ""
var finalSumUm = 0.0
var finalCount = 0
var finalHitX = 0.0
var finalHitY = 0.0
var finalHitN = 0
var finalV1Mm = 0.0
var finalV2Mm = 0.0
var finalV3Mm = 0.0

while { var.attempt < var.outerLimit && var.toleranceOk == false }
    set var.attempt = { var.attempt + 1 }

    var sum = 0.0
    var count = 0
    var speed = var.roughSpeed
    var pairsOk = true
    var v1Um = 0.0
    var v2Um = 0.0
    var v3Um = 0.0
    var hitSumX = 0.0
    var hitSumY = 0.0
    var hitN = 0

    var innerIdx = 0
    while { var.innerIdx < var.retries }
        M5000

        var startPos = global.nxtAbsPos

        if { var.hasA }
            G53 G38.2 K{param.I} F{var.speed} X{var.targetVector[0]} Y{var.targetVector[1]} Z{var.targetVector[2]} A{var.targetVector[3]}
        else
            G53 G38.2 K{param.I} F{var.speed} X{var.targetVector[0]} Y{var.targetVector[1]} Z{var.targetVector[2]}

        if { result != 0 }
            abort { "G6512: Probe failed to trigger" }

        M5000

        var triggeredPos = global.nxtAbsPos[var.probeAxisIndex]
        var direction = { var.targetVector[var.probeAxisIndex] > var.startPos[var.probeAxisIndex] ? 1 : -1 }
        var compensated = { var.triggeredPos * 1000 - var.probeDeflectionUm }

        if { var.probeAxisIndex != 2 }
            set var.compensated = { var.compensated + (var.probeTipRadiusUm * var.direction) }

        if { var.toleranceEnabled }
            echo "G6512: attempt " ^ { var.innerIdx + 1 } ^ "/3 axis " ^ move.axes[var.probeAxisIndex].letter ^ " = " ^ { var.compensated / 1000 } ^ " mm"
        else
            echo "G6512: attempt " ^ { var.innerIdx + 1 } ^ "/" ^ var.retries ^ " axis " ^ move.axes[var.probeAxisIndex].letter ^ " = " ^ { var.compensated / 1000 } ^ " mm"

        if { var.toleranceEnabled && var.innerIdx == 0 }
            set var.v1Um = var.compensated
        elif { var.toleranceEnabled && var.innerIdx == 1 }
            set var.v2Um = var.compensated
            var pairDeltaMm = { abs(var.compensated - var.v1Um) / 1000 }
            if { var.pairDeltaMm > var.toleranceLimitMm }
                set var.pairsOk = false
                set var.lastPairDeltaMm = var.pairDeltaMm
                set var.lastPairOverMm = { var.pairDeltaMm - var.toleranceLimitMm }
                set var.lastFailedPairLabel = "1-2"
                echo "G6512: pair 1-2 delta " ^ var.pairDeltaMm ^ " mm exceeds limit " ^ var.toleranceLimitMm ^ " mm (over by " ^ var.lastPairOverMm ^ " mm)"
        elif { var.toleranceEnabled && var.innerIdx == 2 }
            set var.v3Um = var.compensated
            var pairDeltaMm = { abs(var.compensated - var.v2Um) / 1000 }
            if { var.pairDeltaMm > var.toleranceLimitMm }
                set var.pairsOk = false
                set var.lastPairDeltaMm = var.pairDeltaMm
                set var.lastPairOverMm = { var.pairDeltaMm - var.toleranceLimitMm }
                set var.lastFailedPairLabel = "2-3"
                echo "G6512: pair 2-3 delta " ^ var.pairDeltaMm ^ " mm exceeds limit " ^ var.toleranceLimitMm ^ " mm (over by " ^ var.lastPairOverMm ^ " mm)"

        set var.sum = { var.sum + var.compensated }
        set var.count = { var.count + 1 }

        if { exists(param.H) && param.H != null }
            var hitX = { var.probeAxisIndex == 0 ? var.compensated / 1000 : global.nxtAbsPos[0] }
            var hitY = { var.probeAxisIndex == 1 ? var.compensated / 1000 : global.nxtAbsPos[1] }
            set var.hitSumX = { var.hitSumX + var.hitX }
            set var.hitSumY = { var.hitSumY + var.hitY }
            set var.hitN = { var.hitN + 1 }

        var backoffDistance = { var.innerIdx == 0 ? sensors.probes[param.I].diveHeights[0] : sensors.probes[param.I].diveHeights[1] }
        var backoffTarget = { var.triggeredPos - (var.direction * var.backoffDistance) }

        set var.speed = { var.fineSpeed }

        var backoffVector = { global.nxtAbsPos }
        if { var.hasA }
            while { #var.backoffVector < 4 }
                set var.backoffVector[#var.backoffVector] = 0
        set var.backoffVector[var.probeAxisIndex] = var.backoffTarget

        if { var.hasA }
            G53 G0 X{var.backoffVector[0]} Y{var.backoffVector[1]} Z{var.backoffVector[2]} A{var.backoffVector[3]}
        else
            G53 G0 X{var.backoffVector[0]} Y{var.backoffVector[1]} Z{var.backoffVector[2]}

        if { sensors.probes[param.I].recoveryTime > 0 }
            G4 P{ ceil(sensors.probes[param.I].recoveryTime * 1000) }

        set var.innerIdx = { var.innerIdx + 1 }

    if { var.toleranceEnabled && var.count < 3 }
        set var.pairsOk = false
        set var.lastFailedPairLabel = "sample-count"
        echo "G6512: Expected 3 tolerance touches, got " ^ var.count

    if { !var.toleranceEnabled || var.pairsOk }
        set var.toleranceOk = true
        set var.finalSumUm = var.sum
        set var.finalCount = var.count
        set var.finalHitX = var.hitSumX
        set var.finalHitY = var.hitSumY
        set var.finalHitN = var.hitN
        if { var.toleranceEnabled }
            set var.finalV1Mm = { var.v1Um / 1000 }
            set var.finalV2Mm = { var.v2Um / 1000 }
            set var.finalV3Mm = { var.v3Um / 1000 }
    elif { var.toleranceEnabled }
        echo "G6512: Consecutive-pair tolerance failed — probe cycle retry " ^ var.attempt ^ " of " ^ var.outerLimit

if { var.toleranceOk == false }
    var nxtG6512Abort = { "G6512: Repeatability failed: pair " ^ var.lastFailedPairLabel }
    set var.nxtG6512Abort = { var.nxtG6512Abort ^ " delta " ^ var.lastPairDeltaMm ^ " mm > " ^ var.toleranceLimitMm }
    set var.nxtG6512Abort = { var.nxtG6512Abort ^ " mm (over by " ^ var.lastPairOverMm ^ " mm) after " ^ var.outerLimit ^ " cycle(s)" }
    abort { var.nxtG6512Abort }

set global.nxtLastProbeResult = { round(var.finalSumUm / var.finalCount) / 1000 }

if { exists(param.H) && param.H != null && var.finalHitN > 0 }
    set global.nxtProbeHitXY[2 * param.H] = { var.finalHitX / var.finalHitN }
    set global.nxtProbeHitXY[2 * param.H + 1] = { var.finalHitY / var.finalHitN }

echo "G6512: Compensated probe result for axis " ^ move.axes[var.probeAxisIndex].letter ^ ": " ^ global.nxtLastProbeResult
if { var.toleranceEnabled }
    var nxtG6512Ok = { "G6512: Tolerance ok — average " ^ global.nxtLastProbeResult ^ " mm" }
    set var.nxtG6512Ok = { var.nxtG6512Ok ^ " (v1=" ^ var.finalV1Mm ^ " v2=" ^ var.finalV2Mm ^ " v3=" ^ var.finalV3Mm ^ ")" }
    set var.nxtG6512Ok = { var.nxtG6512Ok ^ ", limit " ^ var.toleranceLimitMm ^ " mm per pair" }
    echo { var.nxtG6512Ok }
