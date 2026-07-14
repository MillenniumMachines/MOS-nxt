; nxt-custom-globals.g — Declare Custom-platform globals (if !exists → null).
; Loaded from nxt.g after nxt-vars.g and before nxt-user-vars.g.
; User-vars / Configuration UI only `set` these keys; this file owns declares.
; Idempotent. See docs/OM_GLOBAL_SIZE.md.
;
; A-axis Custom keys are optional (OM ~8KB): only when 0:/sys/nxt-custom-a.requested
; exists (Configuration Save creates it when any nxtCustomA* value is set).

if { !exists(global.nxtCustomXMin) }
    global nxtCustomXMin = null
if { !exists(global.nxtCustomXMax) }
    global nxtCustomXMax = null
if { !exists(global.nxtCustomYMin) }
    global nxtCustomYMin = null
if { !exists(global.nxtCustomYMax) }
    global nxtCustomYMax = null
if { !exists(global.nxtCustomZMin) }
    global nxtCustomZMin = null
if { !exists(global.nxtCustomZMax) }
    global nxtCustomZMax = null
if { !exists(global.nxtCustomXSteps) }
    global nxtCustomXSteps = null
if { !exists(global.nxtCustomYSteps) }
    global nxtCustomYSteps = null
if { !exists(global.nxtCustomZSteps) }
    global nxtCustomZSteps = null
if { !exists(global.nxtCustomXHomeAt) }
    global nxtCustomXHomeAt = null
if { !exists(global.nxtCustomYHomeAt) }
    global nxtCustomYHomeAt = null
if { !exists(global.nxtCustomZHomeAt) }
    global nxtCustomZHomeAt = null
if { !exists(global.nxtCustomXEndstopPin) }
    global nxtCustomXEndstopPin = null
if { !exists(global.nxtCustomYEndstopPin) }
    global nxtCustomYEndstopPin = null
if { !exists(global.nxtCustomZEndstopPin) }
    global nxtCustomZEndstopPin = null
if { !exists(global.nxtCustomXDrives) }
    global nxtCustomXDrives = null
if { !exists(global.nxtCustomYDrives) }
    global nxtCustomYDrives = null
if { !exists(global.nxtCustomZDrives) }
    global nxtCustomZDrives = null
if { !exists(global.nxtCustomXCurrent) }
    global nxtCustomXCurrent = null
if { !exists(global.nxtCustomYCurrent) }
    global nxtCustomYCurrent = null
if { !exists(global.nxtCustomZCurrent) }
    global nxtCustomZCurrent = null
if { !exists(global.nxtCustomDriveDirs) }
    global nxtCustomDriveDirs = null
if { !exists(global.nxtCustomXBacklash) }
    global nxtCustomXBacklash = null
if { !exists(global.nxtCustomYBacklash) }
    global nxtCustomYBacklash = null
if { !exists(global.nxtCustomZBacklash) }
    global nxtCustomZBacklash = null

; --- Optional A / rotary Custom keys (gated) ---
if { !fileexists("0:/sys/nxt-custom-a.requested") }
    M99

if { !exists(global.nxtCustomAMin) }
    global nxtCustomAMin = null
if { !exists(global.nxtCustomAMax) }
    global nxtCustomAMax = null
if { !exists(global.nxtCustomASteps) }
    global nxtCustomASteps = null
if { !exists(global.nxtCustomAHomeAt) }
    global nxtCustomAHomeAt = null
if { !exists(global.nxtCustomAEndstopPin) }
    global nxtCustomAEndstopPin = null
if { !exists(global.nxtCustomADrives) }
    global nxtCustomADrives = null
if { !exists(global.nxtCustomACurrent) }
    global nxtCustomACurrent = null
if { !exists(global.nxtCustomABacklash) }
    global nxtCustomABacklash = null
