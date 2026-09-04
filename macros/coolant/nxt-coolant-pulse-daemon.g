; nxt-coolant-pulse-daemon.g
; Periodic pulse phase advance (called from nxt-daemon.g).

if { !global.nxtCoolantPulseActive || !global.nxtFeatureCoolantControl }
    M99

var nxtNowMs = { state.upTime * 1000 + state.msUpTime }
var nxtLastMs = { global.nxtCoolantPulseLastMs }
if { var.nxtNowMs < var.nxtLastMs }
    set global.nxtCoolantPulseLastMs = { var.nxtNowMs }
    M99

var nxtElapsedMs = { var.nxtNowMs - var.nxtLastMs }
var nxtOnSec = { global.nxtCoolantPulseOnSec }
var nxtOffSec = { global.nxtCoolantPulseOffSec }
if { var.nxtOnSec < 1 }
    set var.nxtOnSec = 1
if { var.nxtOffSec < 1 }
    set var.nxtOffSec = 1

var nxtLimitMs = { global.nxtCoolantPulsePhaseOn ? (var.nxtOnSec * 1000) : (var.nxtOffSec * 1000) }
if { var.nxtElapsedMs < var.nxtLimitMs }
    M99

set global.nxtCoolantPulsePhaseOn = { !global.nxtCoolantPulsePhaseOn }
set global.nxtCoolantPulseLastMs = { var.nxtNowMs }
M98 P"nxt-coolant-pulse-apply.g"
