; G6512.g: SINGLE SURFACE PROBE - EXECUTE MANUALLY
;
; Surface probe in any direction.
;
; This macro is designed to be called directly with parameters set. To gather
; parameters from the user, use the G6510 macro which will prompt the operator
; for the required parameters.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

if { !exists(param.X) && !exists(param.Y) && !exists(param.Z) }
    abort { "G6512: Must provide a valid target position in one or more axes (X.. Y.. Z..)!" }

if { !exists(global.nxtAbsPos) }
    global nxtAbsPos = { null }

; Use absolute positions in mm and feeds in mm/min
G90
G21
G94

; Temporary G69 for probe (G53/position checks). Do not clear nxtJobG68Deg —
; tpost / resume restore while a job owns rotation.
G69

; Get current machine position
M5000 P0

; Assume current location is start point.
var sP = { global.nxtAbsPos }

; Our target positions do not take probe tool radius
; into account on the X and Y axes. We need to account
; for this so that when say, we move to a position that
; should be 10mm away from the target, we actually move
; the edge of the tool 10mm away from the target rather
; than the center. This becomes important if

; Successively approach target position until operator is happy that there is contact.
; We choose the increments based on the distance to the target position.

var dN = { "50mm", "10mm", "5mm", "1mm", "0.1mm", "0.01mm", "Finish", "Back-Off 1mm" }
var dD = { 50, 10, 5, 1, 0.1, 0.01, 0, -1 }

; This is the index of the speed in the distances array to switch to fine probing speed
var slowSpeed = 3

; Current position, defaults to start position
var cP  = var.sP

while { true }
    ; Distance between current position and target in each axis
    var dC = { var.cP[0] - (exists(param.X)? param.X : var.sP[0] ), var.cP[1] - (exists(param.Y)? param.Y : var.sP[1] ), var.cP[2] - (exists(param.Z)? param.Z : var.sP[2] ) }

    if { var.dC[0] == 0 && var.dC[1] == 0 && var.dC[2] == 0 }
        abort { "G6512.2: Reached target position without operator selecting Finish!" }

    ; Calculate the magnitude (distance) of the direction vector
    var mag = { sqrt(pow(var.dC[0], 2) + pow(var.dC[1], 2) + pow(var.dC[2], 2)) }

    if { var.mag == 0 }
        abort { "G6512.2: Target position is the same as the current position!" }

    ; Find the valid distances less than the distance to the target
    var vDC = null
    var vD  = null
    var vDN = null
    var vDI = 0

    ; Find the index of the first valid distance
    while { iterations < #global.nxtManualProbeDistances }
        ; If the distance of a step is less than the distance to the target,
        ; then it is valid.
        ; If the distance is valid, then all subsequent distances are also
        ; valid.
        set var.vDI = { iterations }
        if { global.nxtManualProbeDistances[iterations] < var.mag }
            break

    if { var.vDI == #global.nxtManualProbeDistances }
        abort { "G6512.2: No valid distances found!" }

    ; Length of valid distances
    set var.vDC = { #global.nxtManualProbeDistances - var.vDI }

    ; Valid distance indexes and names
    set var.vD = { vector(var.vDC, 0) }

    ; Names is one longer than the distances to allow for a
    ; cancel option.
    set var.vDN = { vector(var.vDC+1, "Unknown") }

    var nxtDistN = { "50mm", "10mm", "5mm", "1mm", "0.1mm", "0.01mm", "Finish", "Back-Off 1mm" }

    ; Append the valid distance to the list of valid distances and names
    while { iterations < var.vDC }
        set var.vD[iterations] = { global.nxtManualProbeDistances[iterations + var.vDI] }
        set var.vDN[iterations] = { var.nxtDistN[iterations + var.vDI] }

    ; Add cancel button
    set var.vDN[#var.vDN-1] = "Cancel"

    ; Ask operator to select a distance to move towards the target point.
    var m291Pos = { "Position: X=" ^ var.cP[0] ^ " Y=" ^ var.cP[1] ^ " Z=" ^ var.cP[2] }
    var m291Dist = { "<br/>Distance to target: " ^ (floor(var.mag*1000)/1000) ^ "mm." }
    var m291Prompt = { var.m291Pos ^ var.m291Dist ^ "<br/>Select distance to move towards target." }
    M291 P{var.m291Prompt} R"nxt: Manual Probe" S4 K{ var.vDN } F{var.vDC} T0
    if { result != 0 || input == (#var.vDN-1) }
        abort { "G6512.2: Operator cancelled probing!" }

    ; Validate selected distance
    if { input < 0 || input >= (#var.vDN-1) }
        abort { "G6512.2: Invalid distance selected!" }

    ; Otherwise, pick the operator selected distance
    var dI = { var.vD[input] }

    ; Break if operator picks the 'zero' distance.
    if { var.dI == 0 }
        break

    ; Use a lower movement speed for the smallest increments
    var moveSpeed = { (input >= (global.nxtManualProbeSlowIdx - (#global.nxtManualProbeDistances - var.vDC))) ? global.nxtManualProbeFeeds[2] : global.nxtManualProbeFeeds[1] }

    ; Generate the new position based on the increment chosen
    ; and move to the new position.
    ; TODO: Check this move is within machine bounds
    ; Can this be done using G6550?
    G53 G1 X{ var.cP[0] - ((var.dC[0] / var.mag) * var.dI) } Y{ var.cP[1] - ((var.dC[1] / var.mag) * var.dI) } Z{ var.cP[2] - ((var.dC[2] / var.mag) * var.dI) } F{ var.moveSpeed }

    ; Get current machine position
    M5000 P0

    ; Update the current position
    set var.cP = { global.nxtAbsPos }

; Save output variable
set global.nxtAbsPos = { var.cP }

; If we have not moved from the starting position, do not back off.
; bN will return NaN if the start and current positions are the same
; and this will cause unintended behaviour.
if { var.sP[0] == var.cP[0] && var.sP[1] == var.cP[1] && var.sP[2] == var.cP[2] }
    M99

; Calculate back-off normal
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
var bP = { 0, 0, 0 }

    var nxtMbo = { global.nxtProtectedMoveBackOff }
    set var.bP[0] = { var.cP[0] + ((var.sP[0] - var.cP[0]) / var.bN * ((var.nxtMbo > var.bN) ? var.bN : var.nxtMbo)) }
    set var.bP[1] = { var.cP[1] + ((var.sP[1] - var.cP[1]) / var.bN * ((var.nxtMbo > var.bN) ? var.bN : var.nxtMbo)) }
    set var.bP[2] = { var.cP[2] + ((var.sP[2] - var.cP[2]) / var.bN * ((var.nxtMbo > var.bN) ? var.bN : var.nxtMbo)) }

; Rapid backoff toward start — unprotected G0, all axes pinned
M400
var boHasA = { #move.axes > 3 }
if { var.boHasA }
    var boA = { move.axes[3].machinePosition }
    G53 G0 X{var.bP[0]} Y{var.bP[1]} Z{var.bP[2]} A{var.boA}
else
    G53 G0 X{var.bP[0]} Y{var.bP[1]} Z{var.bP[2]}
M400
