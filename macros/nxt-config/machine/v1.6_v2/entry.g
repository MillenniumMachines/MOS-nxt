; nxt machine pack — Milo v1.6 / v2.0 motion (no homing; deploy home*.g via Configuration UI)

M117 "nxt machine v1.6_v2"
M98 P"nxt-config/machine/v1.6_v2/general.g"
M98 P"nxt-config/machine/v1.6_v2/movement.g"
M98 P"nxt-config/machine/v1.6_v2/limits.g"
M98 P"nxt-config/machine/v1.6_v2/steps.g"
M98 P"nxt-config/machine/v1.6_v2/endstop-y.g"
if { fileexists("0:/sys/network.g") }
    M98 P"network.g"
else
    M98 P"nxt-config/machine/v1.6_v2/network-default.g"
M99
