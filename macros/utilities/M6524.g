; M6524.g: SET RGB WORK LIGHT (M150)
;
; Requires global.nxtFeatureRgbLight and global.nxtRgbLedIndex (M150 P parameter).
; USAGE: M6524 R<0-255> G<0-255> B<0-255>

if { !inputs[state.thisInput].active }
    M99

if { !exists(global.nxtFeatureRgbLight) || !global.nxtFeatureRgbLight }
    abort { "M6524: RGB light feature not enabled" }

if { !exists(global.nxtRgbLedIndex) || global.nxtRgbLedIndex == null }
    abort { "M6524: nxtRgbLedIndex not configured" }

var nxtR = 0
var nxtG = 0
var nxtB = 0
if { exists(param.R) }
    set var.nxtR = param.R
if { exists(param.G) }
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

M150 R{var.nxtR} G{var.nxtG} B{var.nxtB} P{global.nxtRgbLedIndex}
