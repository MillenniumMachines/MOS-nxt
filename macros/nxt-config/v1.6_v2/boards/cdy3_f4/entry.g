; NeXT: Milo v1.6 / v2.0 LDO kit — Fly CDYv3 (baseline copied from NeXT v1.5 tree)
; Upstream: Millennium Machines RRF-Configs (milo-v1.5/ldo-kit-fly-cdyv3 + common).
; See nxt/config/ATTRIBUTION.txt — customize paths only under nxt/config/v1.6_v2/

M117 "NeXT cfg v1.6 Fly CDYv3"
M98 P"nxt/config/v1.6_v2/milo-common/general.g"
if { fileexists("0:/sys/estop.g") }
    M98 P"estop.g"
M98 P"nxt/config/v1.6_v2/milo-common/movement.g"
M98 P"nxt/config/v1.6_v2/ldo-kit-fly-cdyv3/drives.g"
M98 P"nxt/config/v1.6_v2/ldo-kit-fly-cdyv3/speed.g"
M98 P"nxt/config/v1.6_v2/ldo-kit-fly-cdyv3/limits.g"
M98 P"nxt/config/v1.6_v2/ldo-kit-fly-cdyv3/fans.g"
M98 P"nxt/config/v1.6_v2/ldo-kit-fly-cdyv3/spindle.g"
if { fileexists("0:/sys/network.g") }
    M98 P"network.g"
else
    M98 P"nxt/config/v1.6_v2/milo-common/network-default.g"
if { fileexists("0:/sys/toolsetter.g") }
    M98 P"toolsetter.g"
else
    M98 P"nxt/config/v1.6_v2/ldo-kit-fly-cdyv3/toolsetter.g"
if { fileexists("0:/sys/touchprobe.g") }
    M98 P"touchprobe.g"
if { fileexists("0:/sys/user-config.g") }
    M98 P"user-config.g"
