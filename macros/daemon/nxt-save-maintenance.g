; nxt-save-maintenance.g
;
; Persists maintenance counters to 0:/sys/nxt-maintenance.g, loaded at boot by nxt.g.
; Called periodically from nxt-run-maintenance.g. Only non-zero tool-life rows are written.

if { !inputs[state.thisInput].active }
    M99

if { !exists(global.nxtAxisTravel) || !exists(global.nxtToolLife) }
    M99

var f = { "0:/sys/nxt-maintenance.g" }

echo >{var.f} { "; nxt-maintenance.g - accumulated maintenance counters (auto-written, do not edit)" }
echo >>{var.f} { "if { exists(global.nxtAxisTravel) }" }

var a = 0
while { var.a < #move.axes }
    echo >>{var.f} { "    set global.nxtAxisTravel[" ^ var.a ^ "] = " ^ global.nxtAxisTravel[var.a] }
    set var.a = { var.a + 1 }

var t = 0
while { var.t < #global.nxtToolLife }
    if { global.nxtToolLife[var.t] > 0 }
        echo >>{var.f} { "    set global.nxtToolLife[" ^ var.t ^ "] = " ^ global.nxtToolLife[var.t] }
    set var.t = { var.t + 1 }

var sa = 0
while { var.sa < #move.axes }
    if { exists(global.nxtAxisServiceAt) && global.nxtAxisServiceAt[var.sa] > 0 }
        echo >>{var.f} { "    set global.nxtAxisServiceAt[" ^ var.sa ^ "] = " ^ global.nxtAxisServiceAt[var.sa] }
    set var.sa = { var.sa + 1 }

if { exists(global.nxtFeatIdleActions) }
    echo >>{var.f} { "    set global.nxtFeatIdleActions = " ^ global.nxtFeatIdleActions }
if { exists(global.nxtIdleAfter) }
    echo >>{var.f} { "    set global.nxtIdleAfter = " ^ global.nxtIdleAfter }
if { exists(global.nxtIdleFanLow) }
    echo >>{var.f} { "    set global.nxtIdleFanLow = " ^ global.nxtIdleFanLow }
if { exists(global.nxtIdleDimBri) }
    echo >>{var.f} { "    set global.nxtIdleDimBri = " ^ global.nxtIdleDimBri }

if { exists(global.nxtCoolantRuntime) && global.nxtCoolantRuntime > 0 }
    echo >>{var.f} { "    set global.nxtCoolantRuntime = " ^ global.nxtCoolantRuntime }
if { exists(global.nxtCoolantServiceAt) && global.nxtCoolantServiceAt > 0 }
    echo >>{var.f} { "    set global.nxtCoolantServiceAt = " ^ global.nxtCoolantServiceAt }
