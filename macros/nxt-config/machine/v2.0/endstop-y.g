; v2.0 Milo: Y homes toward min (Y1). Re-issues Y endstop after board endstops.g.
; CDYv3: PD_11 — Scylla: PD_14 (X uses PD_11 on Scylla)

if { exists(global.nxtBoardPackShortName) && global.nxtBoardPackShortName == "scylla1_0_h723" }
    M574 Y1 S1 P"PD_14"
else
    M574 Y1 S1 P"PD_11"
