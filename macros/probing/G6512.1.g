; G6512.1.g: SINGLE SURFACE PROBE - EXECUTE WITH PROBE
;
; Repeatable surface probe in any direction.
;
; NOTE: This macro does very little checking of parameters because it
; is intended to be called from other macros which validate at a higher
; level. If using this macro directly, please check your parameters
; (particularly start and target positions) before calling this macro.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

if { !exists(param.I) || param.I == null || sensors.probes[param.I].type < 5 || sensors.probes[param.I].type > 8 }
    abort { "G6512.1: Must provide a valid probe ID (I..)!" }

if { !exists(param.X) && !exists(param.Y) && !exists(param.Z) }
    abort { "G6512.1: Must provide a valid target position in one or more axes (X.. Y.. Z..)!" }

; Sampling follows G6512's consecutive-pair rule, on fine touches only.
; Defaults: macros/system/nxt-vars.g (Probe repeatability).
; The first touch is a fast touch at the rough feed. It finds the surface
; and is not counted. When nxtProbeMaxSampleSpreadMm > 0, 3 fine touches
; follow (R is ignored) and each consecutive pair must agree within that
; limit (3D distance). A failed set of fine touches is repeated, up to
; 1 + nxtProbeSampleOuterRetries sets in all. When the limit is 0,
; R (or nxtProbeInnerSampleCount) fine touches are averaged, no pair checks.
var limitMm = { global.nxtProbeMaxSampleSpreadMm }
var tolOn = { var.limitMm > 0 }
var fineCount = { (exists(param.R) && param.R != null) ? floor(param.R) : floor(global.nxtProbeInnerSampleCount) }
if { var.tolOn }
    set var.fineCount = 3
elif { var.fineCount < 1 }
    set var.fineCount = 1
var outerLimit = { var.tolOn ? floor(global.nxtProbeSampleOuterRetries) + 1 : 1 }
if { var.outerLimit < 1 }
    set var.outerLimit = 1

; Whether to throw an error if the probe is not activated
; when it reaches the target position.
var errors = { !exists(param.E) || param.E != 0 }

; Use absolute positions in mm and feeds in mm/min
G90
G21
G94

; Temporary G69 for probe (G53/position checks). Do not clear nxtJobG68Deg —
; tpost / resume restore while a job owns rotation.
G69

; Progress: the fast touch plus every fine touch that may run
set global.nxtProbeRetryTotal = { 1 + var.fineCount * var.outerLimit }
set global.nxtProbeRetryStep = 0

; Get current machine position
M5000 P0

; Set start position based on current position
var sP = { global.nxtAbsPos }

; Set target positions - if not provided, use start positions.
; The machine will not move in one or more axes if the target
; and start positions are the same.
var tP = { exists(param.X)? param.X : var.sP[0], exists(param.Y)? param.Y : var.sP[1], exists(param.Z)? param.Z : var.sP[2] }

; Check if the positions are within machine limits
M6515 X{ var.tP[0] } Y{ var.tP[1] } Z{ var.tP[2] }

; We have to store these, as we apply them manually to
; the probe before triggering a single probe. We must
; be able to access the original values after the probe
; to restore the probe speed after completing each probe.
var roughSpeed   = { sensors.probes[param.I].speeds[0] }
var fineSpeed    = { sensors.probes[param.I].speeds[1] }

var roughDivider = 5

var singleFeed = { var.roughSpeed == var.fineSpeed }
if { var.singleFeed }
    set var.fineSpeed = { var.roughSpeed / var.roughDivider }

; Touch probe: clamp to <=200 / <=50 mm/min (reliable trigger; matches G6512 and G6511).
; Keep this block in sync with the caps in G6512.g.
var isTouchProbe = false
if { exists(global.nxtTouchProbeID) && global.nxtTouchProbeID != null }
    if { param.I == global.nxtTouchProbeID }
        set var.isTouchProbe = true
if { var.isTouchProbe }
    if { var.roughSpeed > 200 || var.roughSpeed <= 0 }
        set var.roughSpeed = 200
    if { var.fineSpeed > 50 || var.fineSpeed <= 0 }
        set var.fineSpeed = 50

; Warn after the caps, so the message shows the feed that is actually used
if { var.singleFeed && !global.nxtExpertMode }
    echo { "nxt: Probe " ^ param.I ^ " is configured with a single feed rate, which will be used for the initial probe. Subsequent probes will run at " ^ var.fineSpeed ^ "mm/min." }
    echo { "nxt: Please use M558 K" ^ param.I ^ " F" ^ var.roughSpeed ^ ":" ^ var.fineSpeed ^ " in your config to silence this warning." }

; Feed for the current touch: rough for the fast touch, fine after that
var curSpeed = { var.roughSpeed }

; Latest touch position. We track position in all 3 axes, as our
; probing direction may be rotated so we are not moving in a single axis.
var cP = { vector(3, 0) }

; Sampling state that is needed after the loops
var attempt = 0
var passed = false
var notTriggered = false
var touchesDone = 0
var fineN = 0
var sumX = 0.0
var sumY = 0.0
var sumZ = 0.0
var lastPairLabel = ""
var lastPairDeltaMm = 0.0
var lastPairOverMm = 0.0

; Each attempt is one set of fine touches; the first attempt starts with
; the fast touch. Stop when a set passes, after outerLimit sets, or when
; an E0 touch does not trigger.
while { var.attempt < var.outerLimit && !var.passed && !var.notTriggered }
    set var.attempt = { var.attempt + 1 }
    set var.fineN = 0
    set var.sumX = 0.0
    set var.sumY = 0.0
    set var.sumZ = 0.0
    var pairsOk = true
    var prevX = 0.0
    var prevY = 0.0
    var prevZ = 0.0
    var touchCount = { var.fineCount + (var.attempt == 1 ? 1 : 0) }

    while { iterations < var.touchCount }
        ; Inner index 0 of the first attempt is the fast touch
        var isFast = { var.attempt == 1 && iterations == 0 }
        set var.curSpeed = { var.isFast ? var.roughSpeed : var.fineSpeed }

        ; Probe towards surface
        ; NOTE: This has potential to move in all 3 axes!

        ; If errors are enabled then use G38.2 which will error
        ; if the probe is not activated by the time we reach the target.
        ; This is not always what we want, so allow specification of E0 to
        ; disable error reporting. This is used for features like tool
        ; offsetting where we don't want to error if the toolsetter is not
        ; activated at one probe point.

        if { var.errors }
            G53 G38.2 K{ param.I } F{ var.curSpeed } X{ var.tP[0] } Y{ var.tP[1] } Z{ var.tP[2] }
            ; Abort if an error was encountered
            if { result != 0 }

                ; Park at Z max.
                ; This is a safety precaution to prevent subsequent X/Y moves from
                ; crashing the probe.
                ; Retrace along the probe line to the start point first: a Z-only
                ; move right after a triggered G38 can run on toward the wall.
                M400
                var peHasA = { #move.axes > 3 }
                if { var.peHasA }
                    var peA = { move.axes[3].machinePosition }
                    G53 G0 X{var.sP[0]} Y{var.sP[1]} Z{var.sP[2]} A{var.peA}
                else
                    G53 G0 X{var.sP[0]} Y{var.sP[1]} Z{var.sP[2]}
                M400
                G27 Z1
                M98 P"nxt-g38-cancel.g"

                abort { "G6512.1: Probe " ^ param.I ^ " experienced an error, aborting!" }
        else
            ; Disable errors by using G38.3
            G53 G38.3 K{ param.I } F{ var.curSpeed } X{ var.tP[0] } Y{ var.tP[1] } Z{ var.tP[2] }

        ; Get current machine position
        M5000 P0

        set var.cP = { global.nxtAbsPos }

        set var.touchesDone = { var.touchesDone + 1 }
        set global.nxtProbeRetryStep = { var.touchesDone }

        ; E0: a touch that ends at the target (within the probe tolerance
        ; on every moved axis) did not trigger. That position is the result.
        if { !var.errors }
            var atTarget = true
            if { var.tP[0] != var.sP[0] && abs(var.cP[0] - var.tP[0]) > sensors.probes[param.I].tolerance }
                set var.atTarget = false
            if { var.tP[1] != var.sP[1] && abs(var.cP[1] - var.tP[1]) > sensors.probes[param.I].tolerance }
                set var.atTarget = false
            if { var.tP[2] != var.sP[2] && abs(var.cP[2] - var.tP[2]) > sensors.probes[param.I].tolerance }
                set var.atTarget = false
            set var.notTriggered = { var.atTarget }

        ; If we have not moved from the starting position, do not back off.
        ; bN will return NaN if the start and current positions are the same
        ; and this will cause unintended behaviour.
        if { var.sP[0] != var.cP[0] || var.sP[1] != var.cP[1] || var.sP[2] != var.cP[2] }

            ; Apply correct back-off distance
            var backoff = { var.isFast ? sensors.probes[param.I].diveHeights[0] : sensors.probes[param.I].diveHeights[1] }

            ; Calculate normal
            ; This is the distance between the current and starting position
            ; in a straight line.
            var bN = { sqrt(pow(var.sP[0] - var.cP[0], 2) + pow(var.sP[1] - var.cP[1], 2) + pow(var.sP[2] - var.cP[2], 2)) }

            ; In some cases, our back-off distance might be higher than
            ; the distance we've travelled from the starting location.
            ; In this case, we should travel back to the starting location
            ; instead, because otherwise we risk crashing into things (like
            ; the other side of a bore that we just probed).
            ; If the backoff distance is higher than the normal from from the
            ; starting location, then we use the normal as the backoff distance.
            ; This is essentially the same as multiplying var.d{X,Y,Z} by 1.


            ; Calculate normalized direction and backoff per axis,
            ; and apply to current position.
            var bPX = { var.cP[0] + ((var.sP[0] - var.cP[0]) / var.bN * ((var.backoff > var.bN) ? var.bN : var.backoff)) }
            var bPY = { var.cP[1] + ((var.sP[1] - var.cP[1]) / var.bN * ((var.backoff > var.bN) ? var.bN : var.backoff)) }
            var bPZ = { var.cP[2] + ((var.sP[2] - var.cP[2]) / var.bN * ((var.backoff > var.bN) ? var.bN : var.backoff)) }

            ; Rapid backoff toward start — unprotected G0, all axes pinned
            M400
            var boHasA = { #move.axes > 3 }
            if { var.boHasA }
                var boA = { move.axes[3].machinePosition }
                G53 G0 X{var.bPX} Y{var.bPY} Z{var.bPZ} A{var.boA}
            else
                G53 G0 X{var.bPX} Y{var.bPY} Z{var.bPZ}
            M400

        ; An E0 touch that did not trigger stops all sampling. break only
        ; leaves this loop; the attempt loop stops on var.notTriggered.
        if { var.notTriggered }
            break

        ; The fast touch only finds the surface and is not counted.
        if { !var.isFast }
            set var.fineN = { var.fineN + 1 }
            set var.sumX = { var.sumX + var.cP[0] }
            set var.sumY = { var.sumY + var.cP[1] }
            set var.sumZ = { var.sumZ + var.cP[2] }
            echo { "G6512.1: touch " ^ var.fineN ^ "/" ^ var.fineCount ^ " X=" ^ var.cP[0] ^ " Y=" ^ var.cP[1] ^ " Z=" ^ var.cP[2] }

            ; Compare with the previous fine touch of this attempt (3D distance)
            if { var.tolOn && var.fineN > 1 }
                var pairDeltaMm = { sqrt(pow(var.cP[0] - var.prevX, 2) + pow(var.cP[1] - var.prevY, 2) + pow(var.cP[2] - var.prevZ, 2)) }
                if { var.pairDeltaMm > var.limitMm }
                    set var.pairsOk = false
                    set var.lastPairDeltaMm = { var.pairDeltaMm }
                    set var.lastPairOverMm = { var.pairDeltaMm - var.limitMm }
                    set var.lastPairLabel = { (var.fineN - 1) ^ "-" ^ var.fineN }
                    echo { "G6512.1: pair " ^ var.lastPairLabel ^ " delta " ^ var.pairDeltaMm ^ " mm exceeds limit " ^ var.limitMm ^ " mm (over by " ^ var.lastPairOverMm ^ " mm)" }

            set var.prevX = { var.cP[0] }
            set var.prevY = { var.cP[1] }
            set var.prevZ = { var.cP[2] }

        ; Dwell so machine can settle, if necessary
        if { sensors.probes[param.I].recoveryTime > 0.0 }
            G4 P{ ceil(sensors.probes[param.I].recoveryTime * 1000) }

    ; A set passes when pair checks are off or every consecutive pair agreed
    if { !var.notTriggered }
        if { !var.tolOn || var.pairsOk }
            set var.passed = true
        else
            echo { "G6512.1: Consecutive-pair tolerance failed — probe cycle retry " ^ var.attempt ^ " of " ^ var.outerLimit }

; Every set failed: park Z, as the probe error path does, and abort rather
; than average inconsistent touches into the result.
if { !var.passed && !var.notTriggered }
    ; Retrace to the start point before the Z park (see the probe error path)
    M400
    var rfHasA = { #move.axes > 3 }
    if { var.rfHasA }
        var rfA = { move.axes[3].machinePosition }
        G53 G0 X{var.sP[0]} Y{var.sP[1]} Z{var.sP[2]} A{var.rfA}
    else
        G53 G0 X{var.sP[0]} Y{var.sP[1]} Z{var.sP[2]}
    M400
    G27 Z1
    M98 P"nxt-g38-cancel.g"
    var failMsg = { "G6512.1: Repeatability failed: pair " ^ var.lastPairLabel }
    set var.failMsg = { var.failMsg ^ " delta " ^ var.lastPairDeltaMm ^ " mm > " ^ var.limitMm }
    set var.failMsg = { var.failMsg ^ " mm (over by " ^ var.lastPairOverMm ^ " mm) after " ^ var.outerLimit ^ " cycle(s)" }
    abort { var.failMsg }

; global.nxtAbsPos still holds the latest touch (M5000 P0 runs after each
; probe move, not after the back-off), so the result keeps every axis it
; reports, A included. A passing set replaces X/Y/Z with the mean of its
; fine touches; an E0 touch that did not trigger is returned as it is.
var result = { global.nxtAbsPos }
if { var.passed }
    set var.result[0] = { var.sumX / var.fineN }
    set var.result[1] = { var.sumY / var.fineN }
    set var.result[2] = { var.sumZ / var.fineN }

; Save output variable.
set global.nxtAbsPos = { var.result }
