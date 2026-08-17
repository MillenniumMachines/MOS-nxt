; general.g - Configures general machine settings

; Enable CNC Mode
M453

; Set Machine Name (standalone only).
; SBC: M550 belongs in dsf-config.g / Pi hostname — skip here (see docs/BRANCH_PORTING.md).
if { exists(sbc) }
    echo {"nxt: SBC mode — skipping M550 in general.g"}
else
    M550 P"Milo"

; Disable heated bed
M140 H-1
