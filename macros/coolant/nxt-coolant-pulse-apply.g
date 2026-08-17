; nxt-coolant-pulse-apply.g
; Apply air / mist / flood gpOut states from request flags and pulse phase.

if { !global.nxtFeatureCoolantControl }
    M99

var nxtMistReq = { global.nxtCoolantMistRequested }
var nxtFloodReq = { global.nxtCoolantFloodRequested }
var nxtPulseOn = { global.nxtCoolantPulseActive && global.nxtCoolantPulsePhaseOn }
var nxtMistPulse = { global.nxtCoolantMistPulseEnabled && global.nxtCoolantPulseActive }
var nxtFloodPulse = { global.nxtCoolantFloodPulseEnabled && global.nxtCoolantPulseActive }

; Air blast: steady on while mist is requested (M7.1 semantics)
if { global.nxtCoolantAirID != null }
    var nxtAirRelay = { exists(global.nxtRelayID) && global.nxtRelayID != null && global.nxtCoolantAirID == global.nxtRelayID }
    if { !var.nxtAirRelay }
        var nxtAirPwm = { var.nxtMistReq ? 1 : 0 }
        M42 P{global.nxtCoolantAirID} S{var.nxtAirPwm}

; Mist output
if { global.nxtCoolantMistID != null }
    var nxtMistRelay = { exists(global.nxtRelayID) && global.nxtRelayID != null && global.nxtCoolantMistID == global.nxtRelayID }
    if { !var.nxtMistRelay }
        var nxtMistPwm = 0
        if { var.nxtMistReq }
            var nxtMistSteady = { !var.nxtMistPulse }
            var nxtMistPhaseOn = { var.nxtMistPulse && var.nxtPulseOn }
            var nxtMistOn = { var.nxtMistSteady || var.nxtMistPhaseOn }
            set var.nxtMistPwm = { var.nxtMistOn ? 1 : 0 }
        M42 P{global.nxtCoolantMistID} S{var.nxtMistPwm}

; Flood output
if { global.nxtCoolantFloodID != null }
    var nxtFloodRelay = { exists(global.nxtRelayID) && global.nxtRelayID != null && global.nxtCoolantFloodID == global.nxtRelayID }
    if { !var.nxtFloodRelay }
        var nxtFloodPwm = 0
        if { var.nxtFloodReq }
            var nxtFloodSteady = { !var.nxtFloodPulse }
            var nxtFloodPhaseOn = { var.nxtFloodPulse && var.nxtPulseOn }
            var nxtFloodOn = { var.nxtFloodSteady || var.nxtFloodPhaseOn }
            set var.nxtFloodPwm = { var.nxtFloodOn ? 1 : 0 }
        M42 P{global.nxtCoolantFloodID} S{var.nxtFloodPwm}
