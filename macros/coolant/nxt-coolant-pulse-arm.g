; nxt-coolant-pulse-arm.g
; Caller sets nxtCoolantMistRequested and/or nxtCoolantFloodRequested before M98.

if { !global.nxtFeatureCoolantControl }
    M99

if { !exists(global.nxtCoolantPulseOnSec) || global.nxtCoolantPulseOnSec < 1 }
    set global.nxtCoolantPulseOnSec = 5
if { !exists(global.nxtCoolantPulseOffSec) || global.nxtCoolantPulseOffSec < 1 }
    set global.nxtCoolantPulseOffSec = 25
if { !exists(global.nxtCoolantMistPulseEnabled) }
    set global.nxtCoolantMistPulseEnabled = false
if { !exists(global.nxtCoolantFloodPulseEnabled) }
    set global.nxtCoolantFloodPulseEnabled = false

var nxtMistPulse = { global.nxtCoolantMistRequested && global.nxtCoolantMistPulseEnabled }
var nxtFloodPulse = { global.nxtCoolantFloodRequested && global.nxtCoolantFloodPulseEnabled }
var nxtNeedPulse = { var.nxtMistPulse || var.nxtFloodPulse }

if { var.nxtNeedPulse }
    if { !global.nxtCoolantPulseActive }
        set global.nxtCoolantPulsePhaseOn = true
        set global.nxtCoolantPulseLastMs = { state.upTime * 1000 + state.msUpTime }
    set global.nxtCoolantPulseActive = true
else
    set global.nxtCoolantPulseActive = false

M98 P"nxt-coolant-pulse-apply.g"
