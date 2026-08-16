; nxt-probe-virtual-sync.g — Rewrite 0:/sys/nxt-probe-virtual.g from live virtual.
; M5016 writes platen Z_act. nxt.g M98-loads this file after user-vars.
; Null virtual writes `set … = null` so a stale user-vars line cannot win on boot.

if { !inputs[state.thisInput].active }
    M99

var PV = "0:/sys/nxt-probe-virtual.g"

echo >{var.PV} {"; nxt probe virtual = datum platen Z (M5016)"}
echo >>{var.PV} {"; Maintained by nxt-probe-virtual-sync.g after M5016 / geometry Save."}
echo >>{var.PV} {"; Boot: nxt.g M98-loads this file after nxt-user-vars.g."}
echo >>{var.PV} {""}

var nxtHaveV = false
if { exists(global.nxtProbeVirtualTsZ) }
    if { global.nxtProbeVirtualTsZ != null }
        set var.nxtHaveV = true
if { var.nxtHaveV }
    echo >>{var.PV} {"set global.nxtProbeVirtualTsZ = " ^ global.nxtProbeVirtualTsZ}
    echo "nxt-probe-virtual-sync: wrote Z=" ^ global.nxtProbeVirtualTsZ
else
    echo >>{var.PV} {"set global.nxtProbeVirtualTsZ = null"}
    echo "nxt-probe-virtual-sync: wrote set virtual = null"
