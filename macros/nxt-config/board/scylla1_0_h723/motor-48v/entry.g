; NeXT board pack — Scylla v1.0 (scylla1_0_h723), 48 V motor supply

M117 "NeXT board Scylla 48V"
M98 P"nxt-config/board/scylla1_0_h723/motor-48v/endstops.g"
if { fileexists("0:/sys/estop.g") }
    M98 P"estop.g"
M98 P"nxt-config/board/scylla1_0_h723/motor-48v/drives.g"
M98 P"nxt-config/board/scylla1_0_h723/motor-48v/speed.g"
M98 P"nxt-config/board/scylla1_0_h723/motor-48v/fans.g"
M98 P"nxt-config/board/scylla1_0_h723/motor-48v/spindle.g"
if { fileexists("0:/sys/toolsetter.g") }
    M98 P"toolsetter.g"
else
    M98 P"nxt-config/board/scylla1_0_h723/motor-48v/toolsetter.g"
if { fileexists("0:/sys/touchprobe.g") }
    M98 P"touchprobe.g"
if { fileexists("0:/sys/user-config.g") }
    M98 P"user-config.g"
M99
