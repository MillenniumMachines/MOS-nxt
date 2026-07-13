; nxt machine pack — Milo v1.6 motion (no homing; deploy home*.g via Configuration UI)

M117 "nxt machine v1.6"
M98 P"nxt-config/machine/v1.6/general.g"
M98 P"nxt-config/machine/v1.6/movement.g"
M98 P"nxt-config/machine/v1.6/limits.g"
M98 P"nxt-config/machine/v1.6/steps.g"
M98 P"nxt-config/machine/v1.6/endstop-y.g"
if { fileexists("0:/sys/network.g") }
    M98 P"network.g"
else
    M98 P"nxt-config/machine/v1.6/network-default.g"
M99
