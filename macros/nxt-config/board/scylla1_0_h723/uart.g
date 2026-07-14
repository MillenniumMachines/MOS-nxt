; uart.g — Scylla UART header PD_8/PD_9 (tx3/rx3, firmware serial.aux2)
;
; Single primary device via global.nxtUartDevice:
;   0 = off (no M575)
;   1 = PanelDue-style (S1)
;   2 = BTT TFT (S2)
;   3 = Pendant (S0 generic serial)
; Baud: global.nxtUartBaud (default 57600)
;
; RRF 3.7+: USB CDC occupies P0/P1; first UART is P2; aux2 (PD8/PD9) is P3.
; Verify on hardware if a given build maps aux2 differently.
; Daisy-chain: additional serial devices can share TX/RX later; UI configures one primary.

if { !exists(global.nxtUartDevice) }
    M99
if { global.nxtUartDevice == null }
    M99
if { global.nxtUartDevice == 0 }
    M99

var baud = 57600
if { exists(global.nxtUartBaud) }
    if { global.nxtUartBaud != null }
        set var.baud = { global.nxtUartBaud }

; PanelDue
if { global.nxtUartDevice == 1 }
    M575 P3 B{var.baud} S1
    echo {"nxt: UART PanelDue on aux2 (PD8/PD9) P3 B" ^ var.baud ^ " S1"}
    M99

; BTT TFT
if { global.nxtUartDevice == 2 }
    M575 P3 B{var.baud} S2
    echo {"nxt: UART BTT TFT on aux2 (PD8/PD9) P3 B" ^ var.baud ^ " S2"}
    M99

; Pendant / generic serial
if { global.nxtUartDevice == 3 }
    M575 P3 B{var.baud} S0
    echo {"nxt: UART pendant on aux2 (PD8/PD9) P3 B" ^ var.baud ^ " S0"}
    M99

echo {"nxt: UART unknown nxtUartDevice=" ^ global.nxtUartDevice}
