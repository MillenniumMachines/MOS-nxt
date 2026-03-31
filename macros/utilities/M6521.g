; M6521.g: CLEAR PROBE RESULT
;
; Clears one or all entries in the probe results table.
;
; USAGE: M6521 [P<resultIndex>]
;
; Parameters:
;   P: Probe results table index (0-9) to clear. If omitted, clears all results.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

if { exists(param.P) }
    ; Clear specific index
    if { param.P < 0 || param.P >= #global.nxtProbeResults }
        abort { "M6521: Result index P=" ^ param.P ^ " exceeds table size (" ^ #global.nxtProbeResults ^ ")" }
    
    set global.nxtProbeResults[param.P] = null
    echo "M6521: Cleared probe result at index " ^ param.P
else
    ; Clear all results
    while { iterations < #global.nxtProbeResults }
        set global.nxtProbeResults[iterations] = null
    
    echo "M6521: Cleared all probe results"
