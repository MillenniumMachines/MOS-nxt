; M5016.g: STATIC DATUM SETUP (toolsetter + probe reference)
;
; One-time geometry: toolsetter Z_act, reference Z_ref, nxtDeltaMachine = Z_ref - Z_act.
; USAGE: M5016
; Requires: nxtFeatureTouchProbe, nxtFeatureToolSetter, nxtTouchProbeID, nxtToolSetterID.
; After success: park (G27) and T{nxtProbeToolID} from the Calibration UI so tpost runs G6511.

if { !inputs[state.thisInput].active }
    M99

if { !global.nxtFeatureTouchProbe || !global.nxtFeatureToolSetter }
    abort { "M5016: Touch probe and toolsetter features must be enabled" }

if { global.nxtTouchProbeID == null }
    abort { "M5016: nxtTouchProbeID is not configured" }

if { global.nxtToolSetterID == null }
    abort { "M5016: nxtToolSetterID is not configured" }

G90
G21
G94

; --- 1. Install datum tool ---
var msgDatum = "Install a rigid datum tool (gauge pin) in the spindle, then press OK."
M291 P{var.msgDatum} R"nxt: Datum setup" S3
if { result != 0 }
    abort { "M5016: Cancelled — install datum tool" }

; --- 2. Jog over toolsetter ---
var msgTsA = "Jog the datum tool over the center of the toolsetter."
var msgTsB = { var.msgTsA ^ "<br/><b>CAUTION</b>: Jogging does not watch probes. Leave Z clear above the platen." }
M291 P{var.msgTsB} R"nxt: Datum setup" X1 Y1 Z1 J1 T0 S3
if { result != 0 }
    abort { "M5016: Cancelled before toolsetter probe" }

M5000 P0
var tsX = { global.nxtAbsPos[0] }
var tsY = { global.nxtAbsPos[1] }
var tsZ = { global.nxtAbsPos[2] }

var tsTravel = { 80.0 }
if { exists(global.nxtToolSetterProbeTravelMm) && global.nxtToolSetterProbeTravelMm > 0 }
    set var.tsTravel = { global.nxtToolSetterProbeTravelMm }
var tsProbeTargetZ = { var.tsZ - var.tsTravel }

; --- 3. Probe toolsetter with datum ---
echo "M5016: Probing toolsetter at X=" ^ var.tsX ^ " Y=" ^ var.tsY
G53 G0 X{var.tsX} Y{var.tsY}
G6512 Z{var.tsProbeTargetZ} I{global.nxtToolSetterID}
var zAct = { global.nxtLastProbeResult }

set global.nxtToolSetterPos = { var.tsX, var.tsY, var.zAct }
echo "M5016: nxtToolSetterPos = {" ^ var.tsX ^ ", " ^ var.tsY ^ ", " ^ var.zAct ^ "}"

; Park Z before moving to reference surface
G27 Z1

; --- 4. Jog datum onto probe reference surface ---
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

; --- 5. Static datum ---
set global.nxtDeltaMachine = { var.refZ - var.zAct }
echo "M5016: nxtDeltaMachine = " ^ global.nxtDeltaMachine ^ " mm (Z_ref - Z_act)"

G27 Z1

var msgDoneA = "Static datum saved. Next: use Calibration to park,"
var msgDoneB = { var.msgDoneA ^ " install the touch probe, and load the probe tool." }
M291 P{var.msgDoneB} R"nxt: Datum setup" S2

echo "M5016: Datum setup complete — continue in Calibration UI"
