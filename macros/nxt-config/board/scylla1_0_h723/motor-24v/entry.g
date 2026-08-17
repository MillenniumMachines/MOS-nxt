; nxt board pack — Scylla v1.0 (scylla1_0_h723), 24 V motor supply

M117 "nxt board Scylla 24V"
M98 P"nxt-config/board/scylla1_0_h723/motor-24v/endstops.g"
if { fileexists("0:/sys/estop.g") }
    M98 P"estop.g"
M98 P"nxt-config/board/scylla1_0_h723/motor-24v/drives.g"
M98 P"nxt-config/board/scylla1_0_h723/motor-24v/speed.g"
M98 P"nxt-config/board/scylla1_0_h723/motor-24v/fans.g"
M98 P"nxt-config/board/scylla1_0_h723/motor-24v/spindle.g"
if { fileexists("0:/sys/toolsetter.g") }
    M98 P"toolsetter.g"
else
    M98 P"nxt-config/board/scylla1_0_h723/motor-24v/toolsetter.g"
if { fileexists("0:/sys/touchprobe.g") }
    M98 P"touchprobe.g"
if { fileexists("0:/sys/user-config.g") }
    M98 P"user-config.g"
M99
