; M5017.g: CALIBRATION — XY EXTERNAL SPANS (deflection / Phase 1)
;
; Place 1-2-3 with 3in facing operator (∥ X). Jog to approx XY center at safe Z.
; D = dive depth from safe Z (required). O = outside face clearance (default 5).
; Edge inset for outer face points is fixed at 10 mm (corner clearance).
;
; 3 pts per face (near-corner, mid, far-corner). Stay at dive Z along a face;
; raise only when moving to the next face. CCW from −Y/−X corner.
;
; Expect ~76.2 mm on X (3in), ~50.8 mm on Y (2in) from face means.
; Ends at probed XY center at original safe Z; echoes tip/D diagnostics.
; USAGE: M5017 D<diveMm> [O<overshootMm>]
; Results: nxtCalDefSpanX, nxtCalDefSpanY (also nxtCalDefSpan = X for compat)

if { !inputs[state.thisInput].active }
    M99

if { !global.nxtFeatureTouchProbe }
    abort { "M5017: Touch probe feature is not enabled" }

if { global.nxtTouchProbeID == null }
    abort { "M5017: nxtTouchProbeID is not configured" }

if { !exists(param.D) || param.D == null || param.D <= 0 }
    abort { "M5017: D<diveMm> required (Z drop from safe start for side probes)" }

var dive = { param.D }
var overshoot = { 5 }
if { exists(param.O) && param.O != null && param.O > 0 }
    set var.overshoot = { param.O }

var sizeX = 76.2
var sizeY = 50.8
var halfX = { var.sizeX / 2 }
var halfY = { var.sizeY / 2 }
var intoMm = 2.0
var edgeInset = 10

var probeId = { global.nxtTouchProbeID }

G90
G21
G94

var jogA = "1-2-3: 3in ∥ X, 2in ∥ Y."
var jogB = { var.jogA ^ "<br/>Jog to approx XY center at safe Z, then OK." }
M291 P{var.jogB} R"nxt: M5017 XY" X1 Y1 Z1 J1 T0 S3
if { result != 0 }
    abort { "M5017: Operator cancelled" }

M5000 P0
var approach = { global.nxtAbsPos }
var cx = { var.approach[0] }
var cy = { var.approach[1] }
var safeZ = { var.approach[2] }
var diveZ = { var.safeZ - var.dive }

var feed = { 600 }
if { exists(global.nxtManualProbeFeeds) && #global.nxtManualProbeFeeds > 0 }
    set var.feed = { global.nxtManualProbeFeeds[0] }

if { var.halfX <= var.edgeInset || var.halfY <= var.edgeInset }
    abort { "M5017: Edge inset must be < half block size" }

var xOutP = { var.cx + var.halfX + var.overshoot }
var xOutN = { var.cx - var.halfX - var.overshoot }
var yOutP = { var.cy + var.halfY + var.overshoot }
var yOutN = { var.cy - var.halfY - var.overshoot }
var xTgtP = { var.cx + var.halfX - var.intoMm }
var xTgtN = { var.cx - var.halfX + var.intoMm }
var yTgtP = { var.cy + var.halfY - var.intoMm }
var yTgtN = { var.cy - var.halfY + var.intoMm }
var xLow = { var.cx - var.halfX + var.edgeInset }
var xMid = { var.cx }
var xHigh = { var.cx + var.halfX - var.edgeInset }
var yLow = { var.cy - var.halfY + var.edgeInset }
var yMid = { var.cy }
var yHigh = { var.cy + var.halfY - var.edgeInset }

M6515 Z{var.diveZ}
M6515 Z{var.safeZ}
M6515 X{var.xOutP} Y{var.yLow}
M6515 X{var.xOutP} Y{var.yHigh}
M6515 X{var.xOutN} Y{var.yLow}
M6515 X{var.xOutN} Y{var.yHigh}
M6515 X{var.xLow} Y{var.yOutP}
M6515 X{var.xHigh} Y{var.yOutN}
M6515 X{var.xTgtP}
M6515 X{var.xTgtN}
M6515 Y{var.yTgtP}
M6515 Y{var.yTgtN}

echo { "M5017: 3-pt perimeter E=" ^ var.edgeInset ^ " O=" ^ var.overshoot }

var sumYm = 0
var sumXp = 0
var sumYp = 0
var sumXn = 0

; --- Face −Y ---
echo "M5017: Face -Y (3 pts)"
G53 G0 Z{var.safeZ}
G53 G0 X{var.xLow} Y{var.yOutN}
G53 G1 Z{var.diveZ} F{var.feed}
M400
G6512 Y{var.yTgtN} I{var.probeId}
set var.sumYm = { var.sumYm + global.nxtLastProbeResult }
G53 G0 X{var.xMid} Y{var.yOutN}
G6512 Y{var.yTgtN} I{var.probeId}
set var.sumYm = { var.sumYm + global.nxtLastProbeResult }
G53 G0 X{var.xHigh} Y{var.yOutN}
G6512 Y{var.yTgtN} I{var.probeId}
set var.sumYm = { var.sumYm + global.nxtLastProbeResult }

; --- Face +X ---
echo "M5017: Face +X (3 pts)"
G53 G0 Z{var.safeZ}
G53 G0 X{var.xOutP} Y{var.yLow}
G53 G1 Z{var.diveZ} F{var.feed}
M400
G6512 X{var.xTgtP} I{var.probeId}
set var.sumXp = { var.sumXp + global.nxtLastProbeResult }
G53 G0 X{var.xOutP} Y{var.yMid}
G6512 X{var.xTgtP} I{var.probeId}
set var.sumXp = { var.sumXp + global.nxtLastProbeResult }
G53 G0 X{var.xOutP} Y{var.yHigh}
G6512 X{var.xTgtP} I{var.probeId}
set var.sumXp = { var.sumXp + global.nxtLastProbeResult }

; --- Face +Y ---
echo "M5017: Face +Y (3 pts)"
G53 G0 Z{var.safeZ}
G53 G0 X{var.xHigh} Y{var.yOutP}
G53 G1 Z{var.diveZ} F{var.feed}
M400
G6512 Y{var.yTgtP} I{var.probeId}
set var.sumYp = { var.sumYp + global.nxtLastProbeResult }
G53 G0 X{var.xMid} Y{var.yOutP}
G6512 Y{var.yTgtP} I{var.probeId}
set var.sumYp = { var.sumYp + global.nxtLastProbeResult }
G53 G0 X{var.xLow} Y{var.yOutP}
G6512 Y{var.yTgtP} I{var.probeId}
set var.sumYp = { var.sumYp + global.nxtLastProbeResult }

; --- Face −X ---
echo "M5017: Face -X (3 pts)"
G53 G0 Z{var.safeZ}
G53 G0 X{var.xOutN} Y{var.yHigh}
G53 G1 Z{var.diveZ} F{var.feed}
M400
G6512 X{var.xTgtN} I{var.probeId}
set var.sumXn = { var.sumXn + global.nxtLastProbeResult }
G53 G0 X{var.xOutN} Y{var.yMid}
G6512 X{var.xTgtN} I{var.probeId}
set var.sumXn = { var.sumXn + global.nxtLastProbeResult }
G53 G0 X{var.xOutN} Y{var.yLow}
G6512 X{var.xTgtN} I{var.probeId}
set var.sumXn = { var.sumXn + global.nxtLastProbeResult }

G53 G0 Z{var.safeZ}
M400

var hitXp = { var.sumXp / 3 }
var hitXn = { var.sumXn / 3 }
var hitYp = { var.sumYp / 3 }
var hitYn = { var.sumYm / 3 }
var spanX = { abs(var.hitXp - var.hitXn) }
var spanY = { abs(var.hitYp - var.hitYn) }

if { !exists(global.nxtCalDefSpanX) }
    global nxtCalDefSpanX = { var.spanX }
else
    set global.nxtCalDefSpanX = { var.spanX }
if { !exists(global.nxtCalDefSpanY) }
    global nxtCalDefSpanY = { var.spanY }
else
    set global.nxtCalDefSpanY = { var.spanY }
if { !exists(global.nxtCalDefSpan) }
    global nxtCalDefSpan = { var.spanX }
else
    set global.nxtCalDefSpan = { var.spanX }

var tipR = 0
if { exists(global.nxtProbeTipRadius) && global.nxtProbeTipRadius != null }
    set var.tipR = { global.nxtProbeTipRadius }
var curDx = 0
var curDy = 0
if { exists(global.nxtProbeDeflection) && global.nxtProbeDeflection != null }
    if { #global.nxtProbeDeflection >= 1 }
        set var.curDx = { global.nxtProbeDeflection[0] }
    if { #global.nxtProbeDeflection >= 2 }
        set var.curDy = { global.nxtProbeDeflection[1] }

var shortX = { var.sizeX - var.spanX }
var shortY = { var.sizeY - var.spanY }
var propDx = { var.curDx + var.shortX / 2 }
var propDy = { var.curDy + var.shortY / 2 }

echo { "M5017: tipR=" ^ var.tipR ^ " curD={" ^ var.curDx ^ "," ^ var.curDy ^ "}" }
echo { "M5017: spanX=" ^ var.spanX ^ " (expect ~76.2) spanY=" ^ var.spanY ^ " (expect ~50.8)" }
echo { "M5017: shortfallX=" ^ var.shortX ^ " shortfallY=" ^ var.shortY }
echo { "M5017: proposed Dx=" ^ var.propDx ^ " Dy=" ^ var.propDy }

var warnD = { abs(var.propDx) > 0.5 || abs(var.propDy) > 0.5 }
var warnTip = { var.tipR >= 2 }
if { var.warnD || var.warnTip }
    echo { "M5017: WARN check tip radius (half ball dia), not diameter — do not Apply yet" }

var ctrX = { (var.hitXp + var.hitXn) / 2 }
var ctrY = { (var.hitYp + var.hitYn) / 2 }
echo { "M5017: center X=" ^ var.ctrX ^ " Y=" ^ var.ctrY ^ " @ Z=" ^ var.safeZ }
G53 G0 Z{var.safeZ}
G53 G0 X{var.ctrX} Y{var.ctrY}
M400
