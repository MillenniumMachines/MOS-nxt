; general.g - Configures general machine settings

; Enable CNC Mode
M453

; Set Machine Name (standalone only).
; SBC: M550 belongs in dsf-config.g / Pi hostname — skip here (see docs/RRF_3.7_MIGRATION.md).
if { exists(sbc) }
    echo {"nxt: SBC mode — skipping M550 in general.g"}
else
    M550 P"Miley"

; Disable heated bed
M140 H-1
