; NeXT: Milo v1.5 LDO kit — Scylla v1.0 (48 V motor supply)
; Same as 24 V kit except speed.g from upstream ldo-kit-scylla-v1.0-48v.
; See nxt/config/ATTRIBUTION.txt

M98 P"nxt/config/v1.5/ldo-kit-scylla-48v/general.g"
if { fileexists("0:/sys/estop.g") }
    M98 P"estop.g"
M98 P"nxt/config/v1.5/ldo-kit-scylla-48v/movement.g"
M98 P"nxt/config/v1.5/ldo-kit-scylla-48v/drives.g"
M98 P"nxt/config/v1.5/ldo-kit-scylla-48v/speed.g"
M98 P"nxt/config/v1.5/ldo-kit-scylla-48v/limits.g"
M98 P"nxt/config/v1.5/ldo-kit-scylla-48v/fans.g"
M98 P"nxt/config/v1.5/ldo-kit-scylla-48v/spindle.g"
if { fileexists("0:/sys/network.g") }
    M98 P"network.g"
else
    M98 P"nxt/config/v1.5/milo-common/network-default.g"
if { fileexists("0:/sys/toolsetter.g") }
    M98 P"toolsetter.g"
else
    M98 P"nxt/config/v1.5/ldo-kit-scylla-48v/toolsetter.g"
if { fileexists("0:/sys/touchprobe.g") }
    M98 P"touchprobe.g"
if { fileexists("0:/sys/user-config.g") }
    M98 P"user-config.g"
