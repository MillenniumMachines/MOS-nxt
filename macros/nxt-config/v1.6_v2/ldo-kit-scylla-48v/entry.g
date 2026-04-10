; NeXT: Milo v1.6 / v2.0 LDO kit — Scylla v1.0 48 V (baseline copied from NeXT v1.5 tree)
; Same as 24 V kit except speed.g from upstream ldo-kit-scylla-v1.0-48v.
; See nxt/config/ATTRIBUTION.txt — customize under nxt/config/v1.6_v2/

M98 P"nxt/config/v1.6_v2/ldo-kit-scylla-48v/general.g"
if { fileexists("0:/sys/estop.g") }
    M98 P"estop.g"
M98 P"nxt/config/v1.6_v2/ldo-kit-scylla-48v/movement.g"
M98 P"nxt/config/v1.6_v2/ldo-kit-scylla-48v/drives.g"
M98 P"nxt/config/v1.6_v2/ldo-kit-scylla-48v/speed.g"
M98 P"nxt/config/v1.6_v2/ldo-kit-scylla-48v/limits.g"
M98 P"nxt/config/v1.6_v2/ldo-kit-scylla-48v/fans.g"
M98 P"nxt/config/v1.6_v2/ldo-kit-scylla-48v/spindle.g"
if { fileexists("0:/sys/network.g") }
    M98 P"network.g"
else
    M98 P"nxt/config/v1.6_v2/milo-common/network-default.g"
if { fileexists("0:/sys/toolsetter.g") }
    M98 P"toolsetter.g"
else
    M98 P"nxt/config/v1.6_v2/ldo-kit-scylla-48v/toolsetter.g"
if { fileexists("0:/sys/touchprobe.g") }
    M98 P"touchprobe.g"
if { fileexists("0:/sys/user-config.g") }
    M98 P"user-config.g"
