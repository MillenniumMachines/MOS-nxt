; M4005.g: CHECK nxt POST-PROCESSOR VERSION
;
; Soft compare: major.minor line only (0.7 matches 0.7.0, 0.7.1, 0.7.0-beta.1).
; Cross-line (0.6 vs 0.7) still aborts. Then runs M4006.

if { !inputs[state.thisInput].active }
    M99

if { !exists(param.V) }
    abort { "M4005: post-processor version (V...) is required" }

if { !exists(global.nxtVersion) }
    abort { "M4005: nxt not loaded (global.nxtVersion missing)" }

; --- post V → major.minor line ---
var nxtPost = { param.V }
if { #var.nxtPost < 1 }
    abort { "M4005: post-processor version (V...) is empty" }

if { take(var.nxtPost, 1) == "v" }
    set var.nxtPost = { drop(var.nxtPost, 1) }

var nxtPostDash = { find(var.nxtPost, "-") }
if { var.nxtPostDash >= 0 }
    set var.nxtPost = { take(var.nxtPost, var.nxtPostDash) }

var nxtPostD1 = { find(var.nxtPost, ".") }
if { var.nxtPostD1 < 1 }
    abort { "M4005: invalid post version (need major.minor): " ^ param.V }

var nxtPostRest = { drop(var.nxtPost, var.nxtPostD1 + 1) }
var nxtPostD2 = { find(var.nxtPostRest, ".") }
var nxtPostLine = { var.nxtPost }
if { var.nxtPostD2 >= 1 }
    set var.nxtPostLine = { take(var.nxtPost, var.nxtPostD1 + 1 + var.nxtPostD2) }

; --- firmware nxtVersion → major.minor line ---
var nxtFw = { global.nxtVersion }
if { #var.nxtFw < 1 }
    abort { "M4005: global.nxtVersion is empty" }

if { take(var.nxtFw, 1) == "v" }
    set var.nxtFw = { drop(var.nxtFw, 1) }

var nxtFwDash = { find(var.nxtFw, "-") }
if { var.nxtFwDash >= 0 }
    set var.nxtFw = { take(var.nxtFw, var.nxtFwDash) }

var nxtFwD1 = { find(var.nxtFw, ".") }
if { var.nxtFwD1 < 1 }
    abort { "M4005: invalid nxtVersion (need major.minor): " ^ global.nxtVersion }

var nxtFwRest = { drop(var.nxtFw, var.nxtFwD1 + 1) }
var nxtFwD2 = { find(var.nxtFwRest, ".") }
var nxtFwLine = { var.nxtFw }
if { var.nxtFwD2 >= 1 }
    set var.nxtFwLine = { take(var.nxtFw, var.nxtFwD1 + 1 + var.nxtFwD2) }

if { var.nxtPostLine != var.nxtFwLine }
    abort { "M4005: version line mismatch: need " ^ var.nxtFwLine ^ ", got " ^ param.V }

; Touch-probe machines must have deflection calibrated before CAM jobs
M4006
