; network-default.g - Configure default network settings (standalone only)
;
; RRF 3.7+: HTTP is disabled by default. M586 P0 S1 is required for DWC and nxt
; Configuration panel saves (rr_upload). See docs/RRF_3.7_MIGRATION.md.
;
; This file is only loaded if network.g does not exist,
; and configures the WiFi adapter into AP mode.
;
; SBC mode: DSF owns networking. M552/M586 here error ("reserved for SBC mode"
; / "cannot process network-related commands") — skip them.

if { exists(sbc) }
    echo {"nxt: SBC mode — skipping M552/M586 in network-default"}
    M99

; Enable WiFi adapter in AP mode
M552 S2

; Enable HTTP, disable FTP and Telnet
M586 P0 S1
M586 P1 S0
