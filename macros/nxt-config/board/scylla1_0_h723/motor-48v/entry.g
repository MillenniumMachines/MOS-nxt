; nxt board pack — Scylla v1.0 (scylla1_0_h723), 48 V motor supply

M117 "nxt board Scylla 48V"
M98 P"nxt-config/board/scylla1_0_h723/motor-48v/endstops.g"
if { fileexists("0:/sys/estop.g") }
    M98 P"estop.g"
M98 P"nxt-config/board/scylla1_0_h723/motor-48v/drives.g"
M98 P"nxt-config/board/scylla1_0_h723/motor-48v/speed.g"
; Named outputs + optional fans (aux0/aux1/aux2/coolant/mist); relay gpOut P5
M98 P"nxt-config/board/scylla1_0_h723/gpio.g"
M98 P"nxt-config/board/scylla1_0_h723/gpio-role-defaults.g"
; UART header PD8/PD9 when nxtUartDevice != 0
if { fileexists("0:/sys/nxt-config/board/scylla1_0_h723/uart.g") }
    M98 P"nxt-config/board/scylla1_0_h723/uart.g"
; RGB / NeoPixel header (PD_6) — always define pin + M950 strip
if { fileexists("0:/sys/nxt-config/board/scylla1_0_h723/rgb.g") }
    M117 "nxt board RGB"
    M98 P"nxt-config/board/scylla1_0_h723/rgb.g"
else
    echo "[nxt] board Scylla: rgb.g missing on SD — reinstall nxt-config"
M98 P"nxt-config/board/scylla1_0_h723/motor-48v/spindle.g"
; Optional A / rotary (drive 3) when global.nxtFeatureFourthAxis (boolean)
; (Configuration Save / MOS import — MosFourthAxis for steps/homea)
var nxtLoadAxisA = false
if { exists(global.nxtFeatureFourthAxis) && global.nxtFeatureFourthAxis }
    set var.nxtLoadAxisA = true
if { var.nxtLoadAxisA }
    if { fileexists("0:/sys/nxt-config/board/scylla1_0_h723/axis-a.g") }
        M117 "nxt board A axis"
        M98 P"nxt-config/board/scylla1_0_h723/axis-a.g"
    else
        echo "[nxt] board Scylla: axis-a.g missing — reinstall nxt-config"
if { fileexists("0:/sys/toolsetter.g") }
    M98 P"toolsetter.g"
else
    M98 P"nxt-config/board/scylla1_0_h723/motor-48v/toolsetter.g"
if { fileexists("0:/sys/touchprobe.g") }
    M98 P"touchprobe.g"
else
    M98 P"nxt-config/board/scylla1_0_h723/motor-48v/touchprobe.g"
if { fileexists("0:/sys/user-config.g") }
    M98 P"user-config.g"
M99
