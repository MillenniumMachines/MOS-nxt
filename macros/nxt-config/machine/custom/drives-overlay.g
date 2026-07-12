; drives-overlay.g — Custom M569 / M584 / M906 after board pack
; Repo stub: apply numeric overrides from globals when set.
; Configuration Save overwrites this file on SD with literal commands
; (hybrid persistence) — prefer that for M584 drive maps.
;
; Do NOT expand nxtCustom*Drives strings into M584 here: empty/unset values
; become M584 X… with no driver ID ("M584: expected driver ID"). Save writes
; literal M584 X0 Y1 Z2 (etc.) when the Custom drive map is configured.

; --- M569 drive directions from nxtCustomDriveDirs ---
; Parsing compact maps in RRF is awkward; prefer Save-generated literals.
; Stub: no-op for dirs unless file was regenerated on Save.

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
