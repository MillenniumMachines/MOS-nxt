; nxt machine pack — Milo v1.5 motion (no homing; deploy home*.g via Configuration UI)

M117 "nxt machine v1.5"
M98 P"nxt-config/machine/v1.5/general.g"
M98 P"nxt-config/machine/v1.5/movement.g"
M98 P"nxt-config/machine/v1.5/limits.g"
M98 P"nxt-config/machine/v1.5/steps.g"
M98 P"nxt-config/machine/v1.5/drives-dir.g"
M98 P"nxt-config/machine/v1.5/endstops.g"
if { fileexists("0:/sys/network.g") }
    M98 P"network.g"
else
    M98 P"nxt-config/machine/v1.5/network-default.g"
M99
