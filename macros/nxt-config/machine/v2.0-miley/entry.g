; nxt machine pack — V2.0 Miley motion (no homing; deploy home*.g via Configuration UI)

M117 "nxt machine v2.0-miley"
M98 P"nxt-config/machine/v2.0-miley/general.g"
M98 P"nxt-config/machine/v2.0-miley/movement.g"
M98 P"nxt-config/machine/v2.0-miley/limits.g"
M98 P"nxt-config/machine/v2.0-miley/steps.g"
M98 P"nxt-config/machine/v2.0-miley/drives-dir.g"
M98 P"nxt-config/machine/v2.0-miley/endstops.g"
if { fileexists("0:/sys/network.g") }
    M98 P"network.g"
else
    M98 P"nxt-config/machine/v2.0-miley/network-default.g"
M99
