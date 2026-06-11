; nxt board pack — Fly CDYv3 (RRF shortName cdy3_f4)

M117 "nxt board cdy3_f4"
M98 P"nxt-config/board/cdy3_f4/endstops.g"
if { fileexists("0:/sys/estop.g") }
    M98 P"estop.g"
M98 P"nxt-config/board/cdy3_f4/drives.g"
M98 P"nxt-config/board/cdy3_f4/speed.g"
M98 P"nxt-config/board/cdy3_f4/fans.g"
M98 P"nxt-config/board/cdy3_f4/spindle.g"
if { fileexists("0:/sys/toolsetter.g") }
    M98 P"toolsetter.g"
else
    M98 P"nxt-config/board/cdy3_f4/toolsetter.g"
if { fileexists("0:/sys/touchprobe.g") }
    M98 P"touchprobe.g"
if { fileexists("0:/sys/user-config.g") }
    M98 P"user-config.g"
M99
