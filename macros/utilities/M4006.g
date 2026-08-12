; M4006.g: REQUIRE TOUCH-PROBE DEFLECTION CALIBRATED
;
; When nxtFeatureTouchProbe is on, abort unless nxtProbeDeflection is a
; non-zero {X,Y,Z} vector with X or Y calibrated (factory {0,0,0} / null = not
; calibrated). Z channel is unused (may be 0). Called from M4005 after version
; check so CAM jobs cannot start without XY D.

if { !inputs[state.thisInput].active }
    M99

if { !exists(global.nxtFeatureTouchProbe) || !global.nxtFeatureTouchProbe }
    M99

if { !exists(global.nxtProbeDeflection) || global.nxtProbeDeflection == null }
    abort { "M4006: Probe deflection not calibrated — run Calibration Phase 1" }

if { #global.nxtProbeDeflection < 3 }
    abort { "M4006: nxtProbeDeflection must be {X,Y,Z} — run Calibration Phase 1" }

var dx = { global.nxtProbeDeflection[0] }
var dy = { global.nxtProbeDeflection[1] }
var dz = { global.nxtProbeDeflection[2] }
if { var.dx == 0 && var.dy == 0 && var.dz == 0 }
    abort { "M4006: Probe deflection is factory zero — complete Phase 1 before jobs" }
