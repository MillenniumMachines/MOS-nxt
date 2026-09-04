; M6524.g: SET RGB WORK LIGHT (M150)
;
; Manual / UI override for the addressable strip (Status RGB panel).
; USAGE: M6524 R<0-255> U<0-255> B<0-255>
;
; Green must be U (not G): RRF parses "Gnnn" on the command line as a G-code.

if { !inputs[state.thisInput].active }
    M99

if { !exists(global.nxtFeatureRgbLight) || !global.nxtFeatureRgbLight }
    abort { "M6524: RGB light feature not enabled" }

; Ensure the strip exists (board rgb.g / daemon may already have created it).
if { exists(global.nxtRGBPin) && global.nxtRGBPin != null }
    if { !exists(global.nxtRGBReady) || !global.nxtRGBReady }
        M950 E{global.nxtRGBStrip} C{global.nxtRGBPin} T{global.nxtRGBType} K{global.nxtRGBOrder} U{global.nxtRGBCount}
        if { exists(global.nxtRGBReady) }
            set global.nxtRGBReady = true
elif { !exists(global.nxtRGBReady) || !global.nxtRGBReady }
    abort { "M6524: LED strip not configured (nxtRGBPin unset — load board pack)" }

var nxtR = 0
var nxtG = 0
var nxtB = 0
if { exists(param.R) }
    set var.nxtR = param.R
; Prefer U (safe on the wire); accept G only if somehow present without a G-code split.
if { exists(param.U) }
    set var.nxtG = param.U
elif { exists(param.G) }
    set var.nxtG = param.G
if { exists(param.B) }
    set var.nxtB = param.B

if { var.nxtR < 0 }
    set var.nxtR = 0
if { var.nxtR > 255 }
    set var.nxtR = 255
if { var.nxtG < 0 }
    set var.nxtG = 0
if { var.nxtG > 255 }
    set var.nxtG = 255
if { var.nxtB < 0 }
    set var.nxtB = 0
if { var.nxtB > 255 }
    set var.nxtB = 255

; UI already scales by brightness — drive full P; U = green (not G).
var nxtStrip = 0
if { exists(global.nxtRGBStrip) }
    set var.nxtStrip = global.nxtRGBStrip
var nxtCount = 1
if { exists(global.nxtRGBCount) && global.nxtRGBCount != null }
    set var.nxtCount = global.nxtRGBCount

M150 E{var.nxtStrip} R{var.nxtR} U{var.nxtG} B{var.nxtB} W0 P255 S{var.nxtCount} F0
