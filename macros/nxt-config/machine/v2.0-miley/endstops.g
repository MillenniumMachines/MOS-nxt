; endstops.g — v2.0-miley XYZ endstop locations (after board endstops.g).
; Scylla pins: X PD_11, Y PD_14, Z PD_12. RRF 3.7: Scylla only.
; Miley X homes to MAX (stationary X); Y min / Z max match V2.0 Milo.

M574 X2 S1 P"PD_11"
M574 Y1 S1 P"PD_14"
M574 Z2 S1 P"PD_12"
