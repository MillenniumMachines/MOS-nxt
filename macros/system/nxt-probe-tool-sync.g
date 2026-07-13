; nxt-probe-tool-sync.g — (Re)define probe tool row via M4000 from nxt configuration.
; Idempotent: M4000 exits early when tool already matches.

if { !exists(global.nxtProbeToolID) || global.nxtProbeToolID == null }
    M99

var probeIdx = { global.nxtProbeToolID }

var featTouchOn = { global.nxtFeatureTouchProbe }
if { exists(global.mosFeatTouchProbe) && global.mosFeatTouchProbe }
    set var.featTouchOn = true

if { var.featTouchOn }
    if { global.nxtProbeTipRadius == null }
        M99
    var deflX = 0.0
    var deflY = 0.0
    if { exists(global.nxtProbeDeflection) && #global.nxtProbeDeflection >= 1 }
        set var.deflX = global.nxtProbeDeflection[0]
    if { exists(global.nxtProbeDeflection) && #global.nxtProbeDeflection >= 2 }
        set var.deflY = global.nxtProbeDeflection[1]
    M4000 P{var.probeIdx} R{global.nxtProbeTipRadius} S"Touch Probe" X{var.deflX} Y{var.deflY} K1
    M99

if { global.nxtDatumToolRadius == null }
    M99

M4000 P{var.probeIdx} R{global.nxtDatumToolRadius} S"Datum Tool" K1
