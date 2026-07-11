; drives-overlay.g — Custom M569 / M584 / M906 after board pack
; Repo stub applies from globals when set. Configuration Save may overwrite
; this file on SD with literal commands (hybrid persistence).

; --- M569 drive directions from nxtCustomDriveDirs ("0:1,1:1,2:0") ---
; Parsing compact maps in RRF is awkward; prefer Save-generated literals.
; Stub: no-op for dirs unless file was regenerated on Save.

; --- M584 axis map ---
var nxtHaveMap = false
if { exists(global.nxtCustomXDrives) && global.nxtCustomXDrives != null }
    if { exists(global.nxtCustomYDrives) && global.nxtCustomYDrives != null }
        if { exists(global.nxtCustomZDrives) && global.nxtCustomZDrives != null }
            set var.nxtHaveMap = true

if { var.nxtHaveMap }
    M584 X{global.nxtCustomXDrives} Y{global.nxtCustomYDrives} Z{global.nxtCustomZDrives}

; --- M906 currents ---
var nxtHaveCur = false
if { exists(global.nxtCustomXCurrent) && global.nxtCustomXCurrent != null }
    if { exists(global.nxtCustomYCurrent) && global.nxtCustomYCurrent != null }
        if { exists(global.nxtCustomZCurrent) && global.nxtCustomZCurrent != null }
            set var.nxtHaveCur = true

if { var.nxtHaveCur }
    M906 X{global.nxtCustomXCurrent} Y{global.nxtCustomYCurrent} Z{global.nxtCustomZCurrent}

; --- M425 backlash (from Calibration / Custom Save) ---
var nxtHaveBl = false
if { exists(global.nxtCustomXBacklash) && global.nxtCustomXBacklash != null }
    if { exists(global.nxtCustomYBacklash) && global.nxtCustomYBacklash != null }
        if { exists(global.nxtCustomZBacklash) && global.nxtCustomZBacklash != null }
            set var.nxtHaveBl = true

if { var.nxtHaveBl }
    if { exists(global.nxtCustomABacklash) && global.nxtCustomABacklash != null }
        M425 X{global.nxtCustomXBacklash} Y{global.nxtCustomYBacklash} Z{global.nxtCustomZBacklash} A{global.nxtCustomABacklash}
    else
        M425 X{global.nxtCustomXBacklash} Y{global.nxtCustomYBacklash} Z{global.nxtCustomZBacklash}
