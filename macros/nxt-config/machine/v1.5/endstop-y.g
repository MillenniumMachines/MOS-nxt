; v1.5 Milo: Y homes toward max (Y2). Re-issues Y endstop after board endstops.g (same pin, board-specific).
; CDYv3: PD_11 — Scylla: PD_14

if { exists(global.nxtBoardPackShortName) && global.nxtBoardPackShortName == "scylla1_0_h723" }
    M574 Y2 S1 P"PD_14"
else
    M574 Y2 S1 P"PD_11"
