; G6550.g: PROTECTED MOVE
;
; Execution: build full target in machine coords → unless pure +Z retract, run G38.3 with
; probe K so an unexpected trip aborts the move before impact → verify each commanded axis
; reached target within tolerance (else crash or obstruction).
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

; Build target coordinates using loop, defaulting to current position for unspecified axes
M5000
var targetCoords = { global.nxtAbsPos }
var axisParams = { param.X, param.Y, param.Z, param.A }

while { iterations < #var.axisParams }
    if { var.axisParams[iterations] != null }
        set var.targetCoords[iterations] = { var.axisParams[iterations] }

; Validate target against machine limits
M6515 X{var.targetCoords[0]} Y{var.targetCoords[1]} Z{var.targetCoords[2]} A{var.targetCoords[3]}

; Determine speed
var feedRate = { exists(param.F) ? param.F : sensors.probes[var.probeID].travelSpeed }

; Check if this is only a positive Z move (safe direction)
var currentZ = { global.nxtAbsPos[2] }
var isOnlyPositiveZ = { exists(param.Z) && var.targetCoords[2] > var.currentZ && 
                       !exists(param.X) && !exists(param.Y) && !exists(param.A) }

; If only moving up in Z, this is safe - no probe protection needed
if { var.isOnlyPositiveZ }
    G53 G1 F{var.feedRate} Z{var.targetCoords[2]}
    M99

; Check if probe is already triggered
if { sensors.probes[var.probeID].value[0] != 0 }
    ; Probe is triggered - calculate backoff position
    var backoffDistance = { sensors.probes[var.probeID].diveHeights[0] }
    
    ; Calculate direction vector from current to target
    var deltaX = { var.targetCoords[0] - global.nxtAbsPos[0] }
    var deltaY = { var.targetCoords[1] - global.nxtAbsPos[1] }
    var deltaZ = { var.targetCoords[2] - global.nxtAbsPos[2] }
    var deltaA = { exists(param.A) ? (var.targetCoords[3] - global.nxtAbsPos[3]) : 0 }
    
    ; Calculate magnitude of movement vector
    var magnitude = { sqrt(var.deltaX^2 + var.deltaY^2 + var.deltaZ^2) }
    
    if { var.magnitude > 0 }
        ; Normalize and scale by backoff distance
        var backoffX = { global.nxtAbsPos[0] - (var.deltaX / var.magnitude * var.backoffDistance) }
        var backoffY = { global.nxtAbsPos[1] - (var.deltaY / var.magnitude * var.backoffDistance) }
        var backoffZ = { global.nxtAbsPos[2] - (var.deltaZ / var.magnitude * var.backoffDistance) }
        var backoffA = { global.nxtAbsPos[3] - (var.deltaA / var.magnitude * var.backoffDistance) }
        
        ; Move to backoff position
        G53 G1 F{var.feedRate} X{var.backoffX} Y{var.backoffY} Z{var.backoffZ} A{var.backoffA}
        M400
        
        ; Check if probe is still triggered after backoff
        if { sensors.probes[var.probeID].value[0] != 0 }
            abort { "G6550: Probe still triggered after backoff - unsafe to continue" }

; Execute the main protected move using G38.3 (move until probe triggers or target reached)
; G38.3 stops when the probe triggers, which provides the protection we need
G53 G38.3 K{var.probeID} F{var.feedRate} X{var.targetCoords[0]} Y{var.targetCoords[1]} Z{var.targetCoords[2]} A{var.targetCoords[3]}

; Update position after move and check if target was reached
M5000

; Check if target position was reached within tolerance
; Use maximum of backlash compensation or 0.01mm for tolerance
var tolerance = { max(0.01, move.axes[0].backlash) }
var axisCoords = { global.nxtAbsPos[0], global.nxtAbsPos[1], global.nxtAbsPos[2], global.nxtAbsPos[3] }

while { iterations < #move.axes }
    if { iterations < #var.axisCoords && iterations < #var.targetCoords }
        var diff = { abs(var.axisCoords[iterations] - var.targetCoords[iterations]) }
        if { var.diff > var.tolerance }
            abort { "G6550: Protected move failed - target position not reached on " ^ move.axes[iterations].letter ^ " axis" }

echo "G6550: Protected move completed"