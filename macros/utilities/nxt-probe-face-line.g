; nxt-probe-face-line.g: SAMPLE ONE FACE (1 OR 3 PTS) ALONG AWAY FROM CORNER
;
; M98 steals P — do not pass P. Writes endpoints into nxtProbeHitXY[0..3] and
; point count into global.nxtFaceLineN.
;
; USAGE:
;   M98 P"nxt-probe-face-line.g" A<0|1> T<target> W<airNormal> J<cx> K<cy>
;     D<alongSense> S<faceLen> E<inset> Z<diveZ> [I] [F] [R]
;
;   A: 0 = probe X (step along Y); 1 = probe Y (step along X)
;   T: Probe target on the normal axis
;   W: Air-side position on the normal axis (held while stepping along)
;   J/K: Corner origin X/Y (along distances measured from here)
;   D: Along-sense +1/−1 (away from corner on the along axis)
;   S: Face length along the face (mm)
;   E: First/last inset from corner (mm)
;   Z: Dive / work Z for face probes
;   I/F/R: Probe id / feed / retries (optional)

if { !inputs[state.thisInput].active }
    M99

if { !exists(param.A) || param.A == null || (param.A != 0 && param.A != 1) }
    abort { "nxt-probe-face-line: A must be 0 (probe X) or 1 (probe Y)" }

if { !exists(param.T) || param.T == null }
    abort { "nxt-probe-face-line: T (probe target) is required" }

if { !exists(param.W) || param.W == null }
    abort { "nxt-probe-face-line: W (air-side normal) is required" }

if { !exists(param.J) || param.J == null || !exists(param.K) || param.K == null }
    abort { "nxt-probe-face-line: J/K corner origin required" }

if { !exists(param.D) || param.D == null || param.D == 0 }
    abort { "nxt-probe-face-line: D along-sense (+1 or -1) required" }

if { !exists(param.S) || param.S == null || param.S <= 0 }
    abort { "nxt-probe-face-line: S face length must be positive" }

if { !exists(param.E) || param.E == null || param.E <= 0 }
    abort { "nxt-probe-face-line: E inset must be positive" }

if { !exists(param.Z) || param.Z == null }
    abort { "nxt-probe-face-line: Z dive height required" }

if { param.S <= param.E }
    abort { "nxt-probe-face-line: Face length S must be greater than inset E" }

var tipR = { 0 }
if { exists(global.nxtProbeTipRadius) && global.nxtProbeTipRadius != null }
    set var.tipR = { global.nxtProbeTipRadius }
var tipDiam = { 2 * var.tipR }
var faceLen = { param.S }
var inset = { param.E }
var alongSense = { param.D > 0 ? 1 : -1 }

; 1 pt if shorter than 2× tip diameter, or not enough span for two insets
var nPts = 3
var tooShortForTip = { var.faceLen < (2 * var.tipDiam) }
var tooShortFor3 = { var.faceLen <= (2 * var.inset) }
if { var.tooShortForTip || var.tooShortFor3 }
    set var.nPts = 1

var probeId = { global.nxtTouchProbeID }
if { exists(param.I) && param.I != null }
    set var.probeId = { param.I }
var feedRate = { exists(param.F) ? param.F : null }
var retries = { exists(param.R) ? param.R : global.nxtProbeInnerSampleCount }

var d0 = { var.inset }
var d1 = { var.faceLen / 2 }
var d2 = { var.faceLen - var.inset }

if { !exists(global.nxtProbeHitXY) }
    global nxtProbeHitXY = { vector(8, 0.0) }
elif { global.nxtProbeHitXY == null }
    set global.nxtProbeHitXY = { vector(8, 0.0) }
elif { #global.nxtProbeHitXY < 8 }
    set global.nxtProbeHitXY = { vector(8, 0.0) }

if { !exists(global.nxtFaceLineN) }
    global nxtFaceLineN = 0
else
    set global.nxtFaceLineN = 0

echo { "nxt-probe-face-line: A=" ^ param.A ^ " nPts=" ^ var.nPts ^ " S=" ^ var.faceLen }

; --- point 0 (near corner): XY at current Z, then Z dive (never XYZ) ---
; Probed axis: G6512 compensated hit. Along axis: M5000 after the hit
; (legacy G6512.1 records actual pose, not commanded J/K).
var along0 = { var.d0 }
if { param.A == 0 }
    G6550 X{param.W} Y{param.K + var.alongSense * var.along0}
    G6550 Z{param.Z}
    G6512 X{param.T} I{var.probeId} F{var.feedRate} R{var.retries}
    M5000
    set global.nxtProbeHitXY[0] = { global.nxtLastProbeResult }
    set global.nxtProbeHitXY[1] = { global.nxtAbsPos[1] }
else
    G6550 X{param.J + var.alongSense * var.along0} Y{param.W}
    G6550 Z{param.Z}
    G6512 Y{param.T} I{var.probeId} F{var.feedRate} R{var.retries}
    M5000
    set global.nxtProbeHitXY[0] = { global.nxtAbsPos[0] }
    set global.nxtProbeHitXY[1] = { global.nxtLastProbeResult }

if { var.nPts == 1 }
    set global.nxtProbeHitXY[2] = { global.nxtProbeHitXY[0] }
    set global.nxtProbeHitXY[3] = { global.nxtProbeHitXY[1] }
    set global.nxtFaceLineN = 1
    echo "nxt-probe-face-line: 1-pt face complete"
    M99

; --- point 1 (mid) then point 2 (far) — stay at dive Z, step along face only ---
if { param.A == 0 }
    G6550 X{param.W} Y{param.K + var.alongSense * var.d1}
    G6512 X{param.T} I{var.probeId} F{var.feedRate} R{var.retries}
    G6550 X{param.W} Y{param.K + var.alongSense * var.d2}
    G6512 X{param.T} I{var.probeId} F{var.feedRate} R{var.retries}
    M5000
    set global.nxtProbeHitXY[2] = { global.nxtLastProbeResult }
    set global.nxtProbeHitXY[3] = { global.nxtAbsPos[1] }
else
    G6550 X{param.J + var.alongSense * var.d1} Y{param.W}
    G6512 Y{param.T} I{var.probeId} F{var.feedRate} R{var.retries}
    G6550 X{param.J + var.alongSense * var.d2} Y{param.W}
    G6512 Y{param.T} I{var.probeId} F{var.feedRate} R{var.retries}
    M5000
    set global.nxtProbeHitXY[2] = { global.nxtAbsPos[0] }
    set global.nxtProbeHitXY[3] = { global.nxtLastProbeResult }

set global.nxtFaceLineN = 3
echo "nxt-probe-face-line: 3-pt face complete"
