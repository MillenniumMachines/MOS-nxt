; G37.g: TOOL LENGTH PROBE
;
; Measures tool length using the toolsetter.
;
; USAGE: G37
;
; Assumes tool is installed and toolsetter is configured.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

; Validate toolsetter
if { global.nxtToolSetterPos == null }
    abort { "G37: Toolsetter position not configured" }

; Use configured toolsetter probe ID from global.nxtToolSetterID
var probeID = {global.nxtToolSetterID}

; Move to toolsetter XY position
G53 G0 X{global.nxtToolSetterPos[0]} Y{global.nxtToolSetterPos[1]}

; Move down to safe Z above toolsetter
G53 G0 Z{global.nxtToolSetterPos[2] + 10}  ; 10mm above

; Probe down to toolsetter (G6512 strict 3-touch pair tolerance when nxtProbeMaxSampleSpreadMm > 0)
G6512 Z{global.nxtToolSetterPos[2]} I{var.probeID} R{global.nxtProbeInnerSampleCount}

; The result is in nxtLastProbeResult
; This would be the tool length or used to set offset

echo "G37: Tool probed at Z=" ^ global.nxtLastProbeResult