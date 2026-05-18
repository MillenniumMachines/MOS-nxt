; NeXT: Milo v1.5 board pack — Fly CDYv3 (RRF shortName cdy3_f4)
; Vendored from Millennium Machines RRF-Configs (milo-v1.5/ldo-kit-fly-cdyv3 + milo-v1.5/common).
; See nxt/config/ATTRIBUTION.txt

M117 "NeXT cfg v1.5 Fly CDYv3"
M98 P"nxt/config/v1.5/common/general.g"
if { fileexists("0:/sys/estop.g") }
    M98 P"estop.g"
M98 P"nxt/config/v1.5/common/movement.g"
M98 P"nxt/config/v1.5/boards/cdy3_f4/drives.g"
M98 P"nxt/config/v1.5/boards/cdy3_f4/speed.g"
M98 P"nxt/config/v1.5/boards/cdy3_f4/limits.g"
M98 P"nxt/config/v1.5/boards/cdy3_f4/fans.g"
M98 P"nxt/config/v1.5/boards/cdy3_f4/spindle.g"
if { fileexists("0:/sys/network.g") }
    M98 P"network.g"
else
    M98 P"nxt/config/v1.5/common/network-default.g"
if { fileexists("0:/sys/toolsetter.g") }
    M98 P"toolsetter.g"
else
    M98 P"nxt/config/v1.5/boards/cdy3_f4/toolsetter.g"
if { fileexists("0:/sys/touchprobe.g") }
    M98 P"touchprobe.g"
if { fileexists("0:/sys/user-config.g") }
    M98 P"user-config.g"
