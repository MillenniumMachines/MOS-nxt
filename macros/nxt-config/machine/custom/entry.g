; nxt machine pack — Custom motion (no homing; deploy home*.g via Configuration UI)

M117 "nxt machine custom"
M98 P"nxt-config/machine/custom/general.g"
M98 P"nxt-config/machine/custom/movement.g"
M98 P"nxt-config/machine/custom/drives-overlay.g"
M98 P"nxt-config/machine/custom/limits.g"
M98 P"nxt-config/machine/custom/steps.g"
M98 P"nxt-config/machine/custom/endstops.g"
if { fileexists("0:/sys/network.g") }
    M98 P"network.g"
else
    M98 P"nxt-config/machine/custom/network-default.g"
M99
