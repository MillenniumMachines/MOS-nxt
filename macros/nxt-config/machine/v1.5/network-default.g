; network-default.g - Configure default network settings (standalone only)
;
; M586 P0 S1 is harmless on RRF 3.6.x; required on 3.7+ for DWC. See docs/BRANCH_PORTING.md.
;
; This file is only loaded if network.g does not exist,
; and configures the WiFi adapter into AP mode.
;
; SBC mode: DSF owns networking — skip M552/M586 here.

if { exists(sbc) }
    echo {"nxt: SBC mode — skipping M552/M586 in network-default"}
    M99

; Enable WiFi adapter in AP mode
M552 S2

; Enable HTTP, disable FTP and Telnet
M586 P0 S1
M586 P1 S0
