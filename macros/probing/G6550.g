; G6550.g: PROTECTED MOVE
;
; Execution: build full target in machine coords → unless pure +Z retract, run G38.3 with
; probe K so an unexpected trip aborts the move before impact → verify each commanded axis
; reached target within tolerance (else crash or obstruction). +Z retract is G53 G1 with
; current XY (and A) pinned so a leftover G38 interpolator cannot continue toward a wall.
;
; Performs a protected move with probe-aware safety checks.
; If a touch probe is triggered unexpectedly during movement,
; the move is aborted immediately for safety.
;
; USAGE: G6550 [X<pos>] [Y<pos>] [Z<pos>] [A<pos>] I<probeID> [F<speed>]
;
; Parameters:
;   X|Y|Z|A: Target coordinates (any combination allowed)
;   I:       Probe ID to monitor (e.g., global.nxtTouchProbeID)
;   F:       Optional speed override in mm/min

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; --- Parameter Validation ---
; Default to touch probe if no probe ID specified
var probeID = { exists(param.I) ? param.I : global.nxtTouchProbeID }

; Validate probe exists and is a touch probe
if { var.probeID < 0 || var.probeID >= #sensors.probes || sensors.probes[var.probeID] == null }
    abort { "G6550: Invalid probe ID " ^ var.probeID }

; Validate probe ID and type
if { sensors.probes[var.probeID].type < 5 || sensors.probes[var.probeID].type > 8 }
    abort { "G6550: Invalid probe type for probe " ^ var.probeID }

; Build target from current machine pose (G6512-style; safe when #move.axes < 4)
M5000
var targetCoords = { global.nxtAbsPos }
var hasA = { #var.targetCoords > 3 }

if { exists(param.X) }
    set var.targetCoords[0] = { param.X }
if { exists(param.Y) }
    set var.targetCoords[1] = { param.Y }
if { exists(param.Z) }
    set var.targetCoords[2] = { param.Z }
if { var.hasA && exists(param.A) }
    set var.targetCoords[3] = { param.A }

; Validate target against machine limits
if { var.hasA }
    M6515 X{var.targetCoords[0]} Y{var.targetCoords[1]} Z{var.targetCoords[2]} A{var.targetCoords[3]}
else
    M6515 X{var.targetCoords[0]} Y{var.targetCoords[1]} Z{var.targetCoords[2]}

; Determine speed
var feedRate = { exists(param.F) ? param.F : sensors.probes[var.probeID].travelSpeed }

; Check if this is only a positive Z move (safe direction when probe is clear)
var currentZ = { global.nxtAbsPos[2] }
var onlyZ = { exists(param.Z) && !exists(param.X) && !exists(param.Y) }
if { var.hasA && exists(param.A) }
    set var.onlyZ = false
var isOnlyPositiveZ = { var.onlyZ && var.targetCoords[2] > var.currentZ }
var probeTripped = { sensors.probes[var.probeID].value[0] != 0 }

; Pure +Z retract is unprotected only when the stylus is clear.
; Pin XY (and A) from the M5000 snapshot so omit-XY cannot resume a G38 wall target.
if { var.isOnlyPositiveZ }
    if { var.probeTripped }
        abort { "G6550: Probe triggered — clear stylus before Z retract" }
    if { var.hasA }
        G53 G1 F{var.feedRate} X{var.targetCoords[0]} Y{var.targetCoords[1]} Z{var.targetCoords[2]} A{var.targetCoords[3]}
    else
        G53 G1 F{var.feedRate} X{var.targetCoords[0]} Y{var.targetCoords[1]} Z{var.targetCoords[2]}
    M99

; Already triggered: step TOWARD the commanded target to clear the stylus.
; Callers (esp. G6512.1 post-touch retract) pass the clear/retract point as target.
; Stepping away from target (old inverted math) drives deeper into the contact —
; e.g. bore wall hit then "backoff" further +X and destroy the probe.
if { var.probeTripped }
    var backoffDistance = { sensors.probes[var.probeID].diveHeights[0] }

    var deltaX = { var.targetCoords[0] - global.nxtAbsPos[0] }
    var deltaY = { var.targetCoords[1] - global.nxtAbsPos[1] }
    var deltaZ = { var.targetCoords[2] - global.nxtAbsPos[2] }
    var deltaA = 0
    if { var.hasA && exists(param.A) }
        set var.deltaA = { var.targetCoords[3] - global.nxtAbsPos[3] }

    ; RRF ^ is concat — multiply for squares
    var magnitude = { sqrt(var.deltaX * var.deltaX + var.deltaY * var.deltaY + var.deltaZ * var.deltaZ) }

    if { var.magnitude <= 0 }
        abort { "G6550: Probe triggered at target — cannot clear in place" }

    var step = { var.backoffDistance }
    if { var.step > var.magnitude }
        set var.step = { var.magnitude }

    var clearX = { global.nxtAbsPos[0] + (var.deltaX / var.magnitude * var.step) }
    var clearY = { global.nxtAbsPos[1] + (var.deltaY / var.magnitude * var.step) }
    var clearZ = { global.nxtAbsPos[2] + (var.deltaZ / var.magnitude * var.step) }

    if { var.hasA && exists(param.A) }
        var clearA = { global.nxtAbsPos[3] + (var.deltaA / var.magnitude * var.step) }
        G53 G1 F{var.feedRate} X{var.clearX} Y{var.clearY} Z{var.clearZ} A{var.clearA}
    else
        G53 G1 F{var.feedRate} X{var.clearX} Y{var.clearY} Z{var.clearZ}
    M400

    if { sensors.probes[var.probeID].value[0] != 0 }
        abort { "G6550: Probe still triggered after clear move - unsafe to continue" }

; Execute the main protected move using G38.3 (move until probe triggers or target reached)
if { var.hasA }
    G53 G38.3 K{var.probeID} F{var.feedRate} X{var.targetCoords[0]} Y{var.targetCoords[1]} Z{var.targetCoords[2]} A{var.targetCoords[3]}
else
    G53 G38.3 K{var.probeID} F{var.feedRate} X{var.targetCoords[0]} Y{var.targetCoords[1]} Z{var.targetCoords[2]}

; Update position after move and check if target was reached
M5000

; Check if target position was reached within tolerance
; Use maximum of backlash compensation or 0.01mm for tolerance
var tolerance = { max(0.01, move.axes[0].backlash) }
var axisCoords = { global.nxtAbsPos }

while { iterations < #move.axes }
    if { iterations < #var.axisCoords && iterations < #var.targetCoords }
        var diff = { abs(var.axisCoords[iterations] - var.targetCoords[iterations]) }
        if { var.diff > var.tolerance }
            abort { "G6550: Protected move failed - target position not reached on " ^ move.axes[iterations].letter ^ " axis" }

echo "G6550: Protected move completed"
