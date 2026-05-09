; NeXT: Milo v1.5 LDO kit — Fly CDYv3
; Vendored from Millennium Machines RRF-Configs (milo-v1.5/ldo-kit-fly-cdyv3 + milo-v1.5/common).
; See nxt/config/ATTRIBUTION.txt

M117 "NeXT cfg v1.5 Fly CDYv3"
M98 P"nxt/config/v1.5/milo-common/general.g"
if { fileexists("0:/sys/estop.g") }
    M98 P"estop.g"
M98 P"nxt/config/v1.5/milo-common/movement.g"
M98 P"nxt/config/v1.5/ldo-kit-fly-cdyv3/drives.g"
M98 P"nxt/config/v1.5/ldo-kit-fly-cdyv3/speed.g"
M98 P"nxt/config/v1.5/ldo-kit-fly-cdyv3/limits.g"
M98 P"nxt/config/v1.5/ldo-kit-fly-cdyv3/fans.g"
M98 P"nxt/config/v1.5/ldo-kit-fly-cdyv3/spindle.g"
if { fileexists("0:/sys/network.g") }
    M98 P"network.g"
else
    M98 P"nxt/config/v1.5/milo-common/network-default.g"
if { fileexists("0:/sys/toolsetter.g") }
    M98 P"toolsetter.g"
else
    M98 P"nxt/config/v1.5/ldo-kit-fly-cdyv3/toolsetter.g"
if { fileexists("0:/sys/touchprobe.g") }
    M98 P"touchprobe.g"
if { fileexists("0:/sys/user-config.g") }
    M98 P"user-config.g"
