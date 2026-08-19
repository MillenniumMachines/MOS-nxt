; nxt-save-maintenance.g
;
; Persists maintenance counters to 0:/sys/nxt-maintenance.g, loaded at boot by nxt.g.
; Called periodically from nxt-run-maintenance.g. Only non-zero tool-life rows are written.

if { !inputs[state.thisInput].active }
    M99

if { !exists(global.nxtAxisTravel) }
    M99

var f = { "0:/sys/nxt-maintenance.g" }

echo >{var.f} { "; nxt-maintenance.g - accumulated maintenance counters (auto-written, do not edit)" }
echo >>{var.f} { "if { exists(global.nxtAxisTravel) }" }

var a = 0
var nxtSaveTravelN = { min(#move.axes, #global.nxtAxisTravel) }
while { var.a < var.nxtSaveTravelN }
    echo >>{var.f} { "    set global.nxtAxisTravel[" ^ var.a ^ "] = " ^ global.nxtAxisTravel[var.a] }
    set var.a = { var.a + 1 }

; Only persist (and restore-allocate) tool-life rows that are actually used.
if { exists(global.nxtToolLife) && global.nxtToolLife != null }
    var nxtLifeWrote = false
    var t = 0
    while { var.t < #global.nxtToolLife }
        if { global.nxtToolLife[var.t] != null && global.nxtToolLife[var.t] > 0 }
            if { !var.nxtLifeWrote }
                echo >>{var.f} { "    M98 P""nxt-tool-life-ensure.g""" }
                set var.nxtLifeWrote = true
            echo >>{var.f} { "    set global.nxtToolLife[" ^ var.t ^ "] = " ^ global.nxtToolLife[var.t] }
        set var.t = { var.t + 1 }

var sa = 0
var nxtSaveSvcN = 0
if { exists(global.nxtAxisServiceAt) }
    set var.nxtSaveSvcN = { min(#move.axes, #global.nxtAxisServiceAt) }
while { var.sa < var.nxtSaveSvcN }
    if { global.nxtAxisServiceAt[var.sa] > 0 }
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
