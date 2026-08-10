; nxt machine pack — Milo v2.0 motion (no homing; deploy home*.g via Configuration UI)

M117 "nxt machine v2.0"
M98 P"nxt-config/machine/v2.0/general.g"
M98 P"nxt-config/machine/v2.0/movement.g"
M98 P"nxt-config/machine/v2.0/limits.g"
M98 P"nxt-config/machine/v2.0/steps.g"
M98 P"nxt-config/machine/v2.0/drives-dir.g"
M98 P"nxt-config/machine/v2.0/endstops.g"
if { fileexists("0:/sys/network.g") }
    M98 P"network.g"
else
    M98 P"nxt-config/machine/v2.0/network-default.g"
M99
