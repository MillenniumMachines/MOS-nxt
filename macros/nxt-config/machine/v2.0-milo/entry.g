; nxt machine pack — V2.0 Milo motion (no homing; deploy home*.g via Configuration UI)

M117 "nxt machine v2.0-milo"
M98 P"nxt-config/machine/v2.0-milo/general.g"
M98 P"nxt-config/machine/v2.0-milo/movement.g"
M98 P"nxt-config/machine/v2.0-milo/limits.g"
M98 P"nxt-config/machine/v2.0-milo/steps.g"
M98 P"nxt-config/machine/v2.0-milo/drives-dir.g"
M98 P"nxt-config/machine/v2.0-milo/endstops.g"
if { fileexists("0:/sys/network.g") }
    M98 P"network.g"
else
    M98 P"nxt-config/machine/v2.0-milo/network-default.g"
M99
