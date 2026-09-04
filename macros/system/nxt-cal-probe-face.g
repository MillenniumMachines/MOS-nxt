; nxt-cal-probe-face.g: M5017 3-pt face probe (stay at dive Z along face)
;
; N: probe axis 0=X 1=Y — T: probe target — U: outside air on probe axis
; A/B/C: three positions on the other axis (near, mid, far)
; Z: diveZ — S: safeZ — F: feed — I: probe id — Q: face tag 0..3 (echo)
; Writes sum of three hits to global.nxtCalFaceSum (declare-on-use).
;
; USAGE: M98 P"nxt-cal-probe-face.g" N… T… U… A… B… C… Z… S… F… I… Q…

if { !inputs[state.thisInput].active }
    M99

if { !exists(param.N) || !exists(param.T) || !exists(param.U) }
    abort { "nxt-cal-probe-face: N T U required" }
if { !exists(param.A) || !exists(param.B) || !exists(param.C) }
    abort { "nxt-cal-probe-face: A B C along-face positions required" }
if { !exists(param.Z) || !exists(param.S) || !exists(param.I) }
    abort { "nxt-cal-probe-face: Z S I required" }

var feed = { 600 }
if { exists(param.F) && param.F != null }
    set var.feed = { param.F }

var faceTag = { 0 }
if { exists(param.Q) && param.Q != null }
    set var.faceTag = { param.Q }
var faceNames = { "-Y", "+X", "+Y", "-X" }
var faceName = { "face" }
if { var.faceTag >= 0 && var.faceTag < #var.faceNames }
    set var.faceName = { var.faceNames[var.faceTag] }

echo { "M5017: Face " ^ var.faceName ^ " (3 pts)" }

var sum = { 0 }
var pts = { param.A, param.B, param.C }
var pi = { 0 }
while { var.pi < 3 }
    var along = { var.pts[var.pi] }
    if { var.pi == 0 }
        G53 G0 Z{param.S}
        if { param.N == 0 }
            G53 G0 X{param.U} Y{var.along}
        else
            G53 G0 X{var.along} Y{param.U}
        G53 G1 Z{param.Z} F{var.feed}
        M400
    else
        if { param.N == 0 }
            G53 G0 X{param.U} Y{var.along}
        else
            G53 G0 X{var.along} Y{param.U}

    if { param.N == 0 }
        G6512 X{param.T} I{param.I}
    else
        G6512 Y{param.T} I{param.I}
    set var.sum = { var.sum + global.nxtLastProbeResult }
    set var.pi = { var.pi + 1 }

if { !exists(global.nxtCalFaceSum) }
    global nxtCalFaceSum = { var.sum }
else
    set global.nxtCalFaceSum = { var.sum }
