; v1.6 Milo: Y homes toward min (Y1). Re-issues Y endstop after board endstops.g.
; Scylla Y pin is PD_14 (X uses PD_11). Never assign PD_11 to Y on Scylla.

var nxtScylla = false
if { exists(global.nxtBoardPackShortName) && global.nxtBoardPackShortName == "scylla1_0_h723" }
    set var.nxtScylla = true
elif { #boards >= 1 && boards[0].shortName == "scylla1_0_h723" }
    set var.nxtScylla = true

if { var.nxtScylla }
    M574 Y1 S1 P"PD_14"
else
    M574 Y1 S1 P"PD_11"
