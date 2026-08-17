; G6511.g: REFERENCE SURFACE PROBE (CAM preamble)
;
; Probes the configured touch-probe reference surface when both touch probe and toolsetter
; are enabled. No-op if already probed this session unless R1. S0 skips tool selection.
;
; USAGE: G6511 [R1] [S0]

if { !inputs[state.thisInput].active }
    M99

var needRef = { global.nxtFeatureTouchProbe && global.nxtFeatureToolSetter }
if { !var.needRef }
    M99

if { global.nxtDeltaMachine == null }
    abort { "G6511: nxtDeltaMachine not set — configure in DWC" }

if { global.nxtTouchProbeRefPos == null || #global.nxtTouchProbeRefPos < 3 }
    abort { "G6511: nxtTouchProbeRefPos not configured" }

var forceReprobe = { exists(param.R) && param.R == 1 }
if { !var.forceReprobe && global.nxtRefSurfaceProbed }
    echo "G6511: Reference surface already probed this session"
    M99

var standalone = { !(exists(param.S) && param.S == 0) }

if { var.standalone }
    M98 P"nxt-probe-tool-ready.g"

var refX = { global.nxtTouchProbeRefPos[0] }
var refY = { global.nxtTouchProbeRefPos[1] }
var refZ = { global.nxtTouchProbeRefPos[2] }
var safeZ = { var.refZ + 10 }

M5000
M6515 X{var.refX} Y{var.refY} Z{var.refZ}
M6515 Z{var.safeZ}

echo "G6511: Probing reference surface at Z=" ^ var.refZ

G53 G0 X{var.refX} Y{var.refY}
G53 G0 Z{var.safeZ}

var tpSamples = { exists(global.nxtTouchProbeInnerSampleCount) && global.nxtTouchProbeInnerSampleCount > 0 ? global.nxtTouchProbeInnerSampleCount : global.nxtProbeInnerSampleCount }
var tpTol = { exists(global.nxtTouchProbeMaxSampleSpreadMm) && global.nxtTouchProbeMaxSampleSpreadMm >= 0 ? global.nxtTouchProbeMaxSampleSpreadMm : global.nxtProbeMaxSampleSpreadMm }
var tpHasOuter = { exists(global.nxtTouchProbeSampleOuterRetries) && global.nxtTouchProbeSampleOuterRetries >= 0 }
var tpOuter = { var.tpHasOuter ? floor(global.nxtTouchProbeSampleOuterRetries) : global.nxtProbeSampleOuterRetries }

G6512 Z{var.refZ} I{global.nxtTouchProbeID} R{var.tpSamples} L{var.tpTol} O{var.tpOuter}

set global.nxtRefSurfaceProbed = true
echo "G6511: Reference surface Z=" ^ global.nxtLastProbeResult ^ " mm"

G27 Z1
