; G6511.g: REFERENCE SURFACE PROBE (CAM preamble)
;
; Probes the saved touch-probe reference surface when touch probe + toolsetter
; are enabled. No-op if already probed this session unless R1. S0 skips tool
; selection (tip wait already done in tpre for probe installs).
;
; Speeds capped: fast ≤200 mm/min, slow ≤50 mm/min.
; Motion: Z0 → ref XY → refZ+50 → fast find → short slow validate → rough Dz.
; V2 probe target uses Z_act−8; V1 targets saved refZ.
; No per-call jog-confirm — ref XYZ from Phase 0 / M5016 + Save.
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
var probeId = { global.nxtTouchProbeID }

; Max allowable standard-probe feeds (clamp configured speeds down)
var fastCap = 200
var slowCap = 50
var cfgFast = { sensors.probes[var.probeId].speeds[0] }
var cfgSlow = { sensors.probes[var.probeId].speeds[1] }
var fastSpd = { var.cfgFast }
if { var.fastSpd > var.fastCap || var.fastSpd <= 0 }
    set var.fastSpd = { var.fastCap }
var slowSpd = { var.cfgSlow }
if { var.slowSpd > var.slowCap || var.slowSpd <= 0 }
    set var.slowSpd = { var.slowCap }

var tpTol = { global.nxtProbeMaxSampleSpreadMm }
if { exists(global.nxtTouchProbeMaxSampleSpreadMm) }
    if { global.nxtTouchProbeMaxSampleSpreadMm >= 0 }
        set var.tpTol = { global.nxtTouchProbeMaxSampleSpreadMm }
var tpOuter = { global.nxtProbeSampleOuterRetries }
if { exists(global.nxtTouchProbeSampleOuterRetries) }
    if { global.nxtTouchProbeSampleOuterRetries >= 0 }
        set var.tpOuter = { floor(global.nxtTouchProbeSampleOuterRetries) }

; Zero Z deflection for raw-ish hits (restore after); XY unchanged
var dxKeep = 0
var dyKeep = 0
var dzKeep = 0
if { exists(global.nxtProbeDeflection) && global.nxtProbeDeflection != null }
    if { #global.nxtProbeDeflection >= 1 }
        set var.dxKeep = { global.nxtProbeDeflection[0] }
    if { #global.nxtProbeDeflection >= 2 }
        set var.dyKeep = { global.nxtProbeDeflection[1] }
    if { #global.nxtProbeDeflection >= 3 }
        set var.dzKeep = { global.nxtProbeDeflection[2] }
set global.nxtProbeDeflection = { var.dxKeep, var.dyKeep, 0 }

var isV2 = false
if { exists(global.nxtToolSetterV2) && global.nxtToolSetterV2 }
    set var.isV2 = true

var approachClearance = 50
var approachZ = { var.refZ + var.approachClearance }
var probeTargetZ = { var.refZ }

if { var.isV2 }
    if { !exists(global.nxtToolSetterPos) || global.nxtToolSetterPos == null }
        abort { "G6511: V2 requires nxtToolSetterPos — run Phase 0 / M5016" }
    if { #global.nxtToolSetterPos < 3 }
        abort { "G6511: V2 nxtToolSetterPos must be {X,Y,Z}" }
    var zAct = { global.nxtToolSetterPos[2] }
    ; 10 mm toward pad + 2 mm overtravel from prior Z_act+4 approach
    set var.probeTargetZ = { var.zAct - 8 }

M5000
M6515 X{var.refX} Y{var.refY} Z{var.approachZ}
M6515 Z0
M6515 Z{var.probeTargetZ}

var nxtG6511Mode = { var.isV2 ? "V2" : "V1" }
echo { "G6511: " ^ var.nxtG6511Mode ^ " refZ+50 fast≤" ^ var.fastSpd ^ " slow≤" ^ var.slowSpd }

G53 G0 Z0
G53 G0 X{var.refX} Y{var.refY}
G53 G0 Z{var.approachZ}

; Fast single find (L0 = no pair tolerance / one rough path via R1)
G6512 Z{var.probeTargetZ} I{var.probeId} F{var.fastSpd} L0 R1
var fastHit = { global.nxtLastProbeResult }
echo { "G6511: fast hit Z=" ^ var.fastHit ^ " mm" }

; Short slow validate: target 2 mm past fast hit (G6512 backs off between)
var shortTarget = { var.fastHit - 2 }
M6515 Z{var.shortTarget}
G6512 Z{var.shortTarget} I{var.probeId} F{var.slowSpd} L{var.tpTol} O{var.tpOuter}
var meanZ = { global.nxtLastProbeResult }
echo { "G6511: slow validate mean Z=" ^ var.meanZ ^ " mm" }

set global.nxtProbeDeflection = { var.dxKeep, var.dyKeep, var.dzKeep }
set global.nxtLastProbeResult = { var.meanZ }

var tipR = 0
if { exists(global.nxtProbeTipRadius) && global.nxtProbeTipRadius != null }
    set var.tipR = { global.nxtProbeTipRadius }
; Rough Dz: tip-center ≈ refZ+R with D=0; stylus pre-travel lowers trigger
var roughDz = { (var.refZ + var.tipR) - var.meanZ }
if { var.roughDz < 0 }
    set var.roughDz = 0

if { !exists(global.nxtCalDefZ) }
    global nxtCalDefZ = { var.roughDz }
else
    set global.nxtCalDefZ = { var.roughDz }

set global.nxtRefSurfaceProbed = true
echo { "G6511: mean Z=" ^ var.meanZ ^ " roughDz=" ^ var.roughDz }
echo "G6511: Reference surface Z=" ^ global.nxtLastProbeResult ^ " mm"

G27 Z1
