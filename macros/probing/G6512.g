; G6512.g: SINGLE-AXIS PROBING
;
; Deflection/tip compensation + optional multi-sample repeatability.
; All default counts, spread limit, and outer retries: see macros/system/nxt-vars.g (Probe repeatability).
; Per-invocation override: R = inner sample count only.
;
; USAGE: G6512 [X|Y|Z|A]<pos> I<probeID> [F] [R] [H]

; --- Parameter Validation ---

var axisParams = { param.X, param.Y, param.Z, param.A }
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

var retries = { exists(param.R) ? param.R : global.nxtProbeInnerSampleCount }
if { var.retries < 1 }
    set var.retries = 1

var outerLimit = { global.nxtProbeMaxSampleSpreadMm > 0 ? global.nxtProbeSampleOuterRetries + 1 : 1 }

G90 G21 G94

M5000

var targetVector = { global.nxtAbsPos }

set var.targetVector[0] = { exists(param.X) ? param.X : var.targetVector[0] }
set var.targetVector[1] = { exists(param.Y) ? param.Y : var.targetVector[1] }
set var.targetVector[2] = { exists(param.Z) ? param.Z : var.targetVector[2] }
set var.targetVector[3] = { exists(param.A) ? param.A : var.targetVector[3] }

M6515 X{var.targetVector[0]} Y{var.targetVector[1]} Z{var.targetVector[2]} A{var.targetVector[3]}

var roughSpeed = { exists(param.F) ? param.F : sensors.probes[param.I].speeds[0] }
var fineSpeed = { exists(param.F) ? param.F : sensors.probes[param.I].speeds[1] }

if { var.roughSpeed == var.fineSpeed && !exists(param.F) }
    set var.fineSpeed = { var.roughSpeed / 5 }

var probeDeflectionUm = { global.nxtProbeDeflection * 1000 }
var probeTipRadiusUm = { global.nxtProbeTipRadius * 1000 }

if { exists(param.H) && param.H != null && (param.H < 0 || param.H > 3) }
    abort { "G6512: Hit slot H must be 0..3 when provided" }

; --- Outer: repeat inner measurement if spread too high ---

var attempt = 0
var spreadOk = false
var lastSpreadMm = 0.0
var finalSumUm = 0.0
var finalCount = 0
var finalHitX = 0.0
var finalHitY = 0.0
var finalHitN = 0

while { var.attempt < var.outerLimit && var.spreadOk == false }
    set var.attempt = { var.attempt + 1 }

    var sum = 0.0
    var count = 0
    var speed = var.roughSpeed
    var sMinUm = null
    var sMaxUm = null
    var hitSumX = 0.0
    var hitSumY = 0.0
    var hitN = 0

    var innerIdx = 0
    while { var.innerIdx < var.retries }
        M5000

        var startPos = global.nxtAbsPos

        G53 G38.2 K{param.I} F{var.speed} X{var.targetVector[0]} Y{var.targetVector[1]} Z{var.targetVector[2]} A{var.targetVector[3]}

        if { result != 0 }
            abort { "G6512: Probe failed to trigger" }

        M5000

        var triggeredPos = global.nxtAbsPos[var.probeAxisIndex]
        var direction = { var.targetVector[var.probeAxisIndex] > var.startPos ? 1 : -1 }
        var compensated = { var.triggeredPos * 1000 - var.probeDeflectionUm }

        if { var.probeAxisIndex != 2 }
            set var.compensated = { var.compensated + (var.probeTipRadiusUm * var.direction) }

        if { var.sMinUm == null || var.compensated < var.sMinUm }
            set var.sMinUm = var.compensated
        if { var.sMaxUm == null || var.compensated > var.sMaxUm }
            set var.sMaxUm = var.compensated

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
        while { #var.backoffVector < 4 }
            set var.backoffVector[#var.backoffVector] = 0
        set var.backoffVector[var.probeAxisIndex] = var.backoffTarget

        G53 G0 X{var.backoffVector[0]} Y{var.backoffVector[1]} Z{var.backoffVector[2]} A{var.backoffVector[3]}

        if { sensors.probes[param.I].recoveryTime > 0 }
            G4 P{ ceil(sensors.probes[param.I].recoveryTime * 1000) }

        set var.innerIdx = { var.innerIdx + 1 }

    set var.lastSpreadMm = { (var.sMaxUm - var.sMinUm) / 1000 }

    if { global.nxtProbeMaxSampleSpreadMm <= 0 || var.lastSpreadMm <= global.nxtProbeMaxSampleSpreadMm }
        set var.spreadOk = true
        set var.finalSumUm = var.sum
        set var.finalCount = var.count
        set var.finalHitX = var.hitSumX
        set var.finalHitY = var.hitSumY
        set var.finalHitN = var.hitN
    else
        echo "G6512: Sample spread " ^ var.lastSpreadMm ^ " mm exceeds configured " ^ global.nxtProbeMaxSampleSpreadMm ^ " mm — probe cycle retry " ^ var.attempt ^ " of " ^ var.outerLimit

if { var.spreadOk == false }
    abort { "G6512: Repeatability failed: spread " ^ var.lastSpreadMm ^ " mm > " ^ global.nxtProbeMaxSampleSpreadMm ^ " mm after " ^ var.outerLimit ^ " cycle(s)" }

set global.nxtLastProbeResult = { round(var.finalSumUm / var.finalCount) / 1000 }

if { exists(param.H) && param.H != null && var.finalHitN > 0 }
    set global.nxtProbeHitXY[2 * param.H] = { var.finalHitX / var.finalHitN }
    set global.nxtProbeHitXY[2 * param.H + 1] = { var.finalHitY / var.finalHitN }

echo "G6512: Compensated probe result for axis " ^ move.axes[var.probeAxisIndex].letter ^ ": " ^ global.nxtLastProbeResult
if { global.nxtProbeMaxSampleSpreadMm > 0 }
    echo "G6512: Inner samples=" ^ var.retries ^ " peak-to-peak=" ^ var.lastSpreadMm ^ " mm (limit " ^ global.nxtProbeMaxSampleSpreadMm ^ " mm)"
