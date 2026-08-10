; M5018.g: CALIBRATION — Phase 3 safe outside + probe-find face
;
; From post-M5017 XY center at safe Z: raise → outside (S/2+O) → dive →
; G6512 find edge → backoff. Default: return to saved center. R0: stay outside.
;
; USAGE: M5018 X|Y{±1} S<sizeMm> [O<mm>] [D<diveMm>] [I<probeId>] [R0]
;   X|Y dir: -1 = minus face, +1 = plus face (exactly one of X or Y)
;   S: full nominal face length along that axis (e.g. 50.8 / 76.2)
;   O: outside clearance beyond the face (default 15)
;   D: optional Z dive from safe Z (same meaning as M5017 D)
;   I: probe tool ID (default nxtTouchProbeID)
;   R0: stay at outside approach after find (e.g. before G9000)

if { !inputs[state.thisInput].active }
    M99

if { !global.nxtFeatureTouchProbe }
    abort { "M5018: Touch probe feature is not enabled" }

var axisParams = { null, null }
if { exists(param.X) }
    set var.axisParams[0] = param.X
if { exists(param.Y) }
    set var.axisParams[1] = param.Y

var axisIdx = -1
var dir = 0
while { iterations < #var.axisParams }
    if { var.axisParams[iterations] != null }
        if { var.axisIdx != -1 }
            abort { "M5018: Specify exactly one of X or Y" }
        set var.axisIdx = { iterations }
        set var.dir = { var.axisParams[iterations] }

if { var.axisIdx < 0 }
    abort { "M5018: Specify X or Y with dir ±1" }

if { var.dir != 1 && var.dir != -1 }
    abort { "M5018: Dir must be 1 or -1" }

if { !exists(param.S) || param.S == null || param.S <= 0 }
    abort { "M5018: S<sizeMm> required (full face length)" }

var size = { param.S }
var overshoot = { 15 }
if { exists(param.O) && param.O != null && param.O > 0 }
    set var.overshoot = { param.O }

var dive = { 0 }
var doDive = { false }
if { exists(param.D) && param.D != null && param.D > 0 }
    set var.dive = { param.D }
    set var.doDive = { true }

var probeId = { null }
if { exists(param.I) && param.I != null }
    set var.probeId = { param.I }
elif { exists(global.nxtTouchProbeID) && global.nxtTouchProbeID != null }
    set var.probeId = { global.nxtTouchProbeID }

if { var.probeId == null }
    abort { "M5018: Probe ID I.. or nxtTouchProbeID required" }

var stayOut = { false }
if { exists(param.R) && param.R == 0 }
    set var.stayOut = { true }

var intoMm = { 2.0 }

G90
G21
G94

var confirmA = "Post-M5017: still at XY center / safe Z?"
var confirmB = { var.confirmA ^ "<br/>OK: outside O=" ^ var.overshoot ^ ", then probe-find." }
M291 P{var.confirmB} R"nxt: M5018 find" X1 Y1 Z1 J1 T0 S3
if { result != 0 }
    abort { "M5018: Operator cancelled" }

M5000 P0
var pos = { global.nxtAbsPos }
var cx = { var.pos[0] }
var cy = { var.pos[1] }
var safeZ = { var.pos[2] }
var half = { var.size / 2 }
var out = { var.half + var.overshoot }

var ax = { var.cx }
var ay = { var.cy }
if { var.axisIdx == 0 }
    set var.ax = { var.cx + var.dir * var.out }
else
    set var.ay = { var.cy + var.dir * var.out }

var diveZ = { var.safeZ }
if { var.doDive }
    set var.diveZ = { var.safeZ - var.dive }

; Target slightly inside nominal face (M5017-style) so G6512 finds the edge
var tgt = { 0 }
if { var.axisIdx == 0 }
    set var.tgt = { var.cx + var.dir * (var.half - var.intoMm) }
else
    set var.tgt = { var.cy + var.dir * (var.half - var.intoMm) }

M6515 Z{var.safeZ}
M6515 X{var.ax} Y{var.ay}
if { var.doDive }
    M6515 Z{var.diveZ}

var feed = { 600 }
if { exists(global.nxtManualProbeFeeds) && #global.nxtManualProbeFeeds > 0 }
    set var.feed = { global.nxtManualProbeFeeds[0] }

; Raise first, then XY outside, then dive — never dive over the block
G53 G0 Z{var.safeZ}
G53 G0 X{var.ax} Y{var.ay}
if { var.doDive }
    G53 G1 Z{var.diveZ} F{var.feed}
M400

if { var.axisIdx == 0 }
    G6512 X{var.tgt} I{var.probeId}
else
    G6512 Y{var.tgt} I{var.probeId}

; Back off to outside approach (G6512 already lifts by dive height)
G53 G1 X{var.ax} Y{var.ay} F{var.feed}
M400

var letter = { "X" }
if { var.axisIdx == 1 }
    set var.letter = { "Y" }

echo { "M5018: found " ^ var.letter ^ " dir=" ^ var.dir ^ " hit=" ^ global.nxtLastProbeResult }
echo { "M5018: approach X=" ^ var.ax ^ " Y=" ^ var.ay ^ " Z=" ^ var.diveZ }

if { !var.stayOut }
    G53 G0 Z{var.safeZ}
    G53 G0 X{var.cx} Y{var.cy}
    M400
    echo { "M5018: returned to center X=" ^ var.cx ^ " Y=" ^ var.cy }
