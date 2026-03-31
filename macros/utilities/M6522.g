; M6522.g: AVERAGE PROBE RESULTS
;
; Averages two probe results and stores the result in the first index.
; Only averages axes that have non-zero values in BOTH results.
;
; USAGE: M6522 P<index1> Q<index2>
;
; Parameters:
;   P: First probe results table index - this will receive the averaged result - REQUIRED
;   Q: Second probe results table index to average with P - REQUIRED

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Validate parameters
if { !exists(param.P) || param.P == null || param.P < 0 }
    abort { "M6522: First result index parameter P is required and must be >= 0" }

if { !exists(param.Q) || param.Q == null || param.Q < 0 }
    abort { "M6522: Second result index parameter Q is required and must be >= 0" }

if { param.P >= #global.nxtProbeResults }
    abort { "M6522: Result index P=" ^ param.P ^ " exceeds table size (" ^ #global.nxtProbeResults ^ ")" }

if { param.Q >= #global.nxtProbeResults }
    abort { "M6522: Result index Q=" ^ param.Q ^ " exceeds table size (" ^ #global.nxtProbeResults ^ ")" }

if { param.P == param.Q }
    abort { "M6522: Cannot average a result with itself (P and Q must be different)" }

; Check if both results exist
if { global.nxtProbeResults[param.P] == null }
    abort { "M6522: No probe result found at index P=" ^ param.P }

if { global.nxtProbeResults[param.Q] == null }
    abort { "M6522: No probe result found at index Q=" ^ param.Q }

; Get both result vectors
var result1 = { global.nxtProbeResults[param.P] }
var result2 = { global.nxtProbeResults[param.Q] }

; Ensure both vectors are properly sized
if { #var.result1 < #move.axes || #var.result2 < #move.axes }
    abort { "M6522: Invalid probe result vectors" }

; Create averaged result vector
var averaged = { vector(#move.axes + 1, 0.0) }

; Average each axis if both results have non-zero values
var axesAveraged = 0

; X axis
if { var.result1[0] != 0 && var.result2[0] != 0 }
    set var.averaged[0] = { (var.result1[0] + var.result2[0]) / 2 }
    set var.axesAveraged = { var.axesAveraged + 1 }
    echo "M6522: Averaged X: " ^ var.result1[0] ^ " + " ^ var.result2[0] ^ " = " ^ var.averaged[0]
else
    set var.averaged[0] = { var.result1[0] != 0 ? var.result1[0] : var.result2[0] }

; Y axis
if { var.result1[1] != 0 && var.result2[1] != 0 }
    set var.averaged[1] = { (var.result1[1] + var.result2[1]) / 2 }
    set var.axesAveraged = { var.axesAveraged + 1 }
    echo "M6522: Averaged Y: " ^ var.result1[1] ^ " + " ^ var.result2[1] ^ " = " ^ var.averaged[1]
else
    set var.averaged[1] = { var.result1[1] != 0 ? var.result1[1] : var.result2[1] }

; Z axis
if { var.result1[2] != 0 && var.result2[2] != 0 }
    set var.averaged[2] = { (var.result1[2] + var.result2[2]) / 2 }
    set var.axesAveraged = { var.axesAveraged + 1 }
    echo "M6522: Averaged Z: " ^ var.result1[2] ^ " + " ^ var.result2[2] ^ " = " ^ var.averaged[2]
else
    set var.averaged[2] = { var.result1[2] != 0 ? var.result1[2] : var.result2[2] }

; A axis (if exists)
if { #move.axes > 3 }
    if { var.result1[3] != 0 && var.result2[3] != 0 }
        set var.averaged[3] = { (var.result1[3] + var.result2[3]) / 2 }
        set var.axesAveraged = { var.axesAveraged + 1 }
        echo "M6522: Averaged A: " ^ var.result1[3] ^ " + " ^ var.result2[3] ^ " = " ^ var.averaged[3]
    else
        set var.averaged[3] = { var.result1[3] != 0 ? var.result1[3] : var.result2[3] }

; Rotation angle (last element)
if { #var.result1 > #move.axes && #var.result2 > #move.axes }
    if { var.result1[#move.axes] != 0 && var.result2[#move.axes] != 0 }
        set var.averaged[#move.axes] = { (var.result1[#move.axes] + var.result2[#move.axes]) / 2 }
        set var.axesAveraged = { var.axesAveraged + 1 }
        echo "M6522: Averaged rotation: " ^ var.result1[#move.axes] ^ " + " ^ var.result2[#move.axes] ^ " = " ^ var.averaged[#move.axes]
    else
        set var.averaged[#move.axes] = { var.result1[#move.axes] != 0 ? var.result1[#move.axes] : var.result2[#move.axes] }

if { var.axesAveraged == 0 }
    abort { "M6522: No common axes found to average between results " ^ param.P ^ " and " ^ param.Q }

; Store averaged result in first index
set global.nxtProbeResults[param.P] = { var.averaged }

echo "M6522: Averaged probe results " ^ param.P ^ " and " ^ param.Q ^ " -> stored in " ^ param.P
echo "M6522: Total axes averaged: " ^ var.axesAveraged
