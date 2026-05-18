; NeXT: Milo v1.5 board pack — Scylla v1.0 (RRF shortName scylla1_0_h723, 24 V motor supply)
; Vendored from Millennium Machines RRF-Configs (milo-v1.5/ldo-kit-scylla-v1.0-24v + milo-v1.5/common network-default.g).
; See nxt/config/ATTRIBUTION.txt

M117 "NeXT cfg v1.5 Scylla 24V"
M98 P"nxt/config/v1.5/boards/scylla1_0_h723/motor-24v/general.g"
if { fileexists("0:/sys/estop.g") }
    M98 P"estop.g"
M98 P"nxt/config/v1.5/boards/scylla1_0_h723/motor-24v/movement.g"
M98 P"nxt/config/v1.5/boards/scylla1_0_h723/motor-24v/drives.g"
M98 P"nxt/config/v1.5/boards/scylla1_0_h723/motor-24v/speed.g"
M98 P"nxt/config/v1.5/boards/scylla1_0_h723/motor-24v/limits.g"
M98 P"nxt/config/v1.5/boards/scylla1_0_h723/motor-24v/fans.g"
M98 P"nxt/config/v1.5/boards/scylla1_0_h723/motor-24v/spindle.g"
if { fileexists("0:/sys/network.g") }
    M98 P"network.g"
else
    M98 P"nxt/config/v1.5/common/network-default.g"
if { fileexists("0:/sys/toolsetter.g") }
    M98 P"toolsetter.g"
else
    M98 P"nxt/config/v1.5/boards/scylla1_0_h723/motor-24v/toolsetter.g"
if { fileexists("0:/sys/touchprobe.g") }
    M98 P"touchprobe.g"
if { fileexists("0:/sys/user-config.g") }
    M98 P"user-config.g"
