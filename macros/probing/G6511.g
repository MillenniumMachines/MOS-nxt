; G6511.g: REFERENCE SURFACE PROBE
;
; CAM preamble: no-op if nxtProbeVirtualTsZ is already set unless R1.
; tpost probe install always uses G6511 R1 S0 (saved nxtTouchProbeRefPos).
; S0 skips tool selection (tip wait already done in tpre).
; R1 writes nxtProbeVirtualTsZ from meanZ − delta and persists sidecar.
; Always probe the saved reference surface — not the toolsetter platen/pad.
;
; Speeds capped: fast ≤200 mm/min, slow ≤50 mm/min.
; Motion: Z0 → ref XY → Z max → fast find → short slow validate.
; Target: saved mill-touch refZ minus nxtToolSetterProbeTravelMm (default 80).
; Clears Z deflection channel (unused).
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
var nxtHaveVirtual = false
if { exists(global.nxtProbeVirtualTsZ) }
    if { global.nxtProbeVirtualTsZ != null }
        set var.nxtHaveVirtual = true
if { !var.forceReprobe && var.nxtHaveVirtual }
    echo "G6511: mill datum already set — skip ref (CAM); tpost uses R1"
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

; Keep XY deflection during hits; Z channel unused (force 0 on restore)
var dxKeep = 0
var dyKeep = 0
if { exists(global.nxtProbeDeflection) && global.nxtProbeDeflection != null }
    if { #global.nxtProbeDeflection >= 1 }
        set var.dxKeep = { global.nxtProbeDeflection[0] }
    if { #global.nxtProbeDeflection >= 2 }
        set var.dyKeep = { global.nxtProbeDeflection[1] }
set global.nxtProbeDeflection = { var.dxKeep, var.dyKeep, 0 }

var approachZ = { move.axes[2].max }
; Mill paper-touch Z (M5016). Seek past it so a shorter probe still triggers.
var refTravel = 80
if { exists(global.nxtToolSetterProbeTravelMm) }
    if { global.nxtToolSetterProbeTravelMm != null }
        if { global.nxtToolSetterProbeTravelMm > 0 }
            set var.refTravel = { global.nxtToolSetterProbeTravelMm }

var probeTargetZ = { var.refZ - var.refTravel }
if { var.probeTargetZ < move.axes[2].min }
    set var.probeTargetZ = { move.axes[2].min }
var refTravelAvail = { var.refZ - var.probeTargetZ }
if { var.refTravelAvail < 5.0 }
    var msgRefShort = "G6511: Not enough Z travel below nxtTouchProbeRefPos"
    abort { var.msgRefShort ^ " (need >= 5mm toward Zmin — mill paper-touch too low)" }

M5000
M6515 X{var.refX} Y{var.refY} Z{var.approachZ}
M6515 Z0
M6515 Z{var.probeTargetZ}

echo { "G6511: ref XY={" ^ var.refX ^ "," ^ var.refY ^ "} Zmax=" ^ var.approachZ }
echo { "G6511: seek travel=" ^ var.refTravel ^ " mm target Z=" ^ var.probeTargetZ }

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

; Clear baked Z D (tipR-era) — Z deflection discarded for now
set global.nxtProbeDeflection = { var.dxKeep, var.dyKeep, 0 }
set global.nxtLastProbeResult = { var.meanZ }

if { !exists(global.nxtCalDefZ) }
    global nxtCalDefZ = null
else
    set global.nxtCalDefZ = null

set global.nxtRefSurfaceProbed = true

var probeVirtual = { var.meanZ - global.nxtDeltaMachine }
if { !exists(global.nxtProbeVirtualTsZ) }
    global nxtProbeVirtualTsZ = { var.probeVirtual }
else
    set global.nxtProbeVirtualTsZ = { var.probeVirtual }
if { exists(global.nxtProbeToolID) && global.nxtProbeToolID != null }
    set global.nxtToolCacheIdx = { global.nxtProbeToolID }
    set global.nxtToolCacheZ = { var.probeVirtual }
M98 P"nxt-probe-virtual-sync.g"

echo { "G6511: mean Z=" ^ var.meanZ ^ " mm (Z deflection unused)" }
echo "G6511: Reference surface Z=" ^ global.nxtLastProbeResult ^ " mm"
echo "G6511: probe virtual toolsetter Z=" ^ global.nxtProbeVirtualTsZ ^ " mm"

M98 P"nxt-g38-cancel.g"
G27 Z1
