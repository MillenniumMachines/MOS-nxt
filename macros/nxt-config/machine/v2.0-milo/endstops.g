; endstops.g — v2.0-milo XYZ endstop locations (after board endstops.g).
; Scylla pins: X PD_11, Y PD_14, Z PD_12. RRF 3.7: Scylla only.
; Inverted (!) for the BOM LJ8A3-2-Z/AY inductive sensors (NC); without it they
; read triggered at rest. A D2F microswitch on Y may need the ! removed.

M574 X1 S1 P"!PD_11"
M574 Y1 S1 P"!PD_14"
M574 Z2 S1 P"!PD_12"
