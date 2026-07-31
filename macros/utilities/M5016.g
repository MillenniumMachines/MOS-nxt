; M5016.g: STATIC DATUM SETUP (toolsetter + probe reference)
;
; One-time geometry: toolsetter Z_act, reference Z_ref, nxtDeltaMachine = Z_ref - Z_act.
; USAGE: M5016
; Requires: nxtFeatureTouchProbe, nxtFeatureToolSetter, nxtTouchProbeID, nxtToolSetterID.
; Verifies configured toolsetter input by user toggle, then probes ~20mm from jog Z.
; V2.0 (nxtToolSetterV2): ref pad at ±13mm XY from platen + Z = Z_act - 6 (no jog-to-ref).
; After success: park (G27) and T{nxtProbeToolID} from the Calibration UI so tpost runs G6511.

if { !inputs[state.thisInput].active }
    M99

if { !global.nxtFeatureTouchProbe || !global.nxtFeatureToolSetter }
    abort { "M5016: Touch probe and toolsetter features must be enabled" }

if { global.nxtTouchProbeID == null }
    abort { "M5016: nxtTouchProbeID is not configured" }

if { global.nxtToolSetterID == null }
    abort { "M5016: nxtToolSetterID is not configured — set it in Configuration first" }

G90
G21
G94

; --- 1. Install datum tool ---
var msgDatum = "Install a rigid datum tool (gauge pin) in the spindle, then press OK."
M291 P{var.msgDatum} R"nxt: Datum setup" S3
if { result != 0 }
    abort { "M5016: Cancelled — install datum tool" }

; --- 2. Verify configured toolsetter input is pressed ---
var tsId = { global.nxtToolSetterID }
if { var.tsId < 0 || var.tsId >= #sensors.probes || sensors.probes[var.tsId] == null }
    abort { "M5016: nxtToolSetterID K" ^ var.tsId ^ " is not a valid probe in the object model" }

var tsVal = 0
var tsThr = 0
var tsTripped = false
var tsReady = false

while { !var.tsReady }
    var msgTsInA = { "Press and <b>hold</b> toolsetter (probe K" ^ var.tsId ^ ")," }
    var msgTsInB = { var.msgTsInA ^ " keep holding, then OK. Cancel aborts." }
    M291 P{var.msgTsInB} R"nxt: Toolsetter input" S4 K{"OK","Cancel"} F0
    if { input != 0 }
        abort { "M5016: Cancelled — toolsetter input check" }

    set var.tsVal = { sensors.probes[var.tsId].value[0] }
    set var.tsThr = { sensors.probes[var.tsId].threshold }
    set var.tsTripped = false
    if { var.tsThr == null }
        set var.tsTripped = { var.tsVal != 0 }
    elif { var.tsVal >= var.tsThr }
        set var.tsTripped = true
    elif { var.tsVal != 0 }
        set var.tsTripped = true

    echo { "M5016: K" ^ var.tsId ^ " val=" ^ var.tsVal ^ " thr=" ^ var.tsThr }

    if { var.tsTripped }
        set var.tsReady = true
        var msgOkA = { "Toolsetter input K" ^ var.tsId ^ " confirmed (pressed)." }
        M291 P{var.msgOkA} R"nxt: Toolsetter input" S2
        echo { "M5016: nxtToolSetterID K" ^ var.tsId ^ " confirmed" }
    else
        var msgRetry = { "Probe K" ^ var.tsId ^ " was not active at OK." }
        set var.msgRetry = { var.msgRetry ^ " Hold the platen, then OK again." }
        M291 P{var.msgRetry} R"nxt: Toolsetter input" S2

; --- 3. Jog over toolsetter; leave ~20mm Z clear above platen ---
var msgTsA = "Jog XY over the center of the toolsetter platen."
var msgTsB = { var.msgTsA ^ "<br/>Leave Z about <b>20 mm</b> clear above the platen, then OK." }
var msgTsC = { var.msgTsB ^ "<br/><b>CAUTION</b>: Jogging does not watch probes." }
M291 P{var.msgTsC} R"nxt: Datum setup" X1 Y1 Z1 J1 T0 S3
if { result != 0 }
    abort { "M5016: Cancelled before toolsetter probe" }

M5000 P0
var tsX = { global.nxtAbsPos[0] }
var tsY = { global.nxtAbsPos[1] }
var tsZ = { global.nxtAbsPos[2] }

; Datum probe: 20mm down from jog Z (or until toolsetter triggers)
var tsTravel = 20.0
var tsProbeTargetZ = { var.tsZ - var.tsTravel }
if { var.tsProbeTargetZ < move.axes[2].min }
    set var.tsProbeTargetZ = { move.axes[2].min }

var tsProbeTravelAvail = { var.tsZ - var.tsProbeTargetZ }
if { var.tsProbeTravelAvail < 5.0 }
    var msgShort = "M5016: Not enough Z travel to probe the toolsetter"
    abort { var.msgShort ^ " (need >= 5mm below jog Z toward Zmin)" }

; --- 4. Probe toolsetter with datum ---
echo "M5016: Probing toolsetter at X=" ^ var.tsX ^ " Y=" ^ var.tsY
G53 G0 X{var.tsX} Y{var.tsY}
G6512 Z{var.tsProbeTargetZ} I{global.nxtToolSetterID}
var zAct = { global.nxtLastProbeResult }

set global.nxtToolSetterPos = { var.tsX, var.tsY, var.zAct }
echo "M5016: nxtToolSetterPos = {" ^ var.tsX ^ ", " ^ var.tsY ^ ", " ^ var.zAct ^ "}"

; Park Z before moving / computing reference surface
G27 Z1

; --- 5. Reference surface (V2 fixed geometry vs V1 jog) ---
var nxtTsV2 = false
if { exists(global.nxtToolSetterV2) && global.nxtToolSetterV2 }
    set var.nxtTsV2 = true

if { var.nxtTsV2 }
    ; V2.0: ref pad 13mm from platen center, 6mm below activation plane
    var v2XyMm = 13.0
    var v2DzMm = -6.0
    var refDir = 0
    if { exists(global.nxtToolSetterRefDir) }
        set var.refDir = global.nxtToolSetterRefDir

    var refX = { var.tsX }
    var refY = { var.tsY }
    if { var.refDir == 0 }
        set var.refX = { var.tsX + var.v2XyMm }
    elif { var.refDir == 1 }
        set var.refX = { var.tsX - var.v2XyMm }
    elif { var.refDir == 2 }
        set var.refY = { var.tsY + var.v2XyMm }
    elif { var.refDir == 3 }
        set var.refY = { var.tsY - var.v2XyMm }
    else
        abort { "M5016: nxtToolSetterRefDir must be 0..3 (+X/-X/+Y/-Y)" }

    var refZ = { var.zAct + var.v2DzMm }

    set global.nxtTouchProbeRefPos = { var.refX, var.refY, var.refZ }
    set global.nxtDeltaMachine = { var.refZ - var.zAct }

    var msgV2a = "V2.0 ref pad computed (no jog)."
    var msgV2b = { var.msgV2a ^ "<br/>Ref XYZ ≈ {" ^ var.refX ^ ", " ^ var.refY ^ ", " ^ var.refZ ^ "}" }
    var msgV2c = { var.msgV2b ^ "<br/>nxtDeltaMachine = " ^ global.nxtDeltaMachine ^ " mm" }
    M291 P{var.msgV2c} R"nxt: Datum setup" S2

    echo "M5016: nxtTouchProbeRefPos = {" ^ var.refX ^ ", " ^ var.refY ^ ", " ^ var.refZ ^ "}"
    echo "M5016: nxtDeltaMachine = " ^ global.nxtDeltaMachine ^ " mm (Z_ref - Z_act)"
else
    ; V1: jog datum onto probe reference surface
    var msgRefA = "Jog the datum tool onto the touch-probe reference surface."
    var msgRefB = { var.msgRefA ^ "<br/>Touch the surface with the datum tip, then press OK to store XYZ." }
    M291 P{var.msgRefB} R"nxt: Datum setup" X1 Y1 Z1 J1 T0 S3
    if { result != 0 }
        abort { "M5016: Cancelled before reference surface" }

    M5000 P0
    var refX = { global.nxtAbsPos[0] }
    var refY = { global.nxtAbsPos[1] }
    var refZ = { global.nxtAbsPos[2] }

    set global.nxtTouchProbeRefPos = { var.refX, var.refY, var.refZ }
    echo "M5016: nxtTouchProbeRefPos = {" ^ var.refX ^ ", " ^ var.refY ^ ", " ^ var.refZ ^ "}"

    set global.nxtDeltaMachine = { var.refZ - var.zAct }
    echo "M5016: nxtDeltaMachine = " ^ global.nxtDeltaMachine ^ " mm (Z_ref - Z_act)"

G27 Z1

var msgDoneA = "Static datum saved. Next: use Calibration to park,"
var msgDoneB = { var.msgDoneA ^ " install the touch probe, and load the probe tool." }
M291 P{var.msgDoneB} R"nxt: Datum setup" S2

echo "M5016: Datum setup complete — continue in Calibration UI"
