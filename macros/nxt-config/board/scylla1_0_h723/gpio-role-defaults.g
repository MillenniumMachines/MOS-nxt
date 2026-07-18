; gpio-role-defaults.g — assign nxt*ID role globals for Scylla preferred J indices
; Only fills missing/null roles. Skips pins that were created as fans (nxtBoardFanPins).
; Preferred: aux0=0 aux1=1 aux2=2 coolant=3 mist=4 relay=5
; UI maps: Aux0→nxtAux1ID, Aux1→nxtAux2ID, Aux2→nxtAux3ID
; Aux0–2 and relay are 24V rails; default tool fan is aux0 (any motor voltage).
;
; Fan membership must match gpio.g (CSV / scalar / legacy single-pin vectors; no []).
; Local vars mist/coolant/aux*/relay mean "created as M950 F" for that alias.

var mist = false
var coolant = false
var aux0 = false
var aux1 = false
var aux2 = false
var relay = false
var none = false
var hay = ""
var fp = ""

if { exists(global.nxtBoardFanPins) && global.nxtBoardFanPins != null }
    if { global.nxtBoardFanPins == "" || global.nxtBoardFanPins == "none" }
        set var.none = true
    elif { global.nxtBoardFanPins == { "none" } }
        set var.none = true

if { !var.none }
    if { exists(global.nxtBoardFanPins) && global.nxtBoardFanPins != null }
        set var.fp = ""
        if { global.nxtBoardFanPins == "mist" }
            set var.fp = "mist"
        elif { global.nxtBoardFanPins == "coolant" }
            set var.fp = "coolant"
        elif { global.nxtBoardFanPins == "aux0" }
            set var.fp = "aux0"
        elif { global.nxtBoardFanPins == "aux1" }
            set var.fp = "aux1"
        elif { global.nxtBoardFanPins == "aux2" }
            set var.fp = "aux2"
        elif { global.nxtBoardFanPins == "relay" }
            set var.fp = "relay"
        elif { global.nxtBoardFanPins == { "mist" } }
            set var.fp = "mist"
        elif { global.nxtBoardFanPins == { "coolant" } }
            set var.fp = "coolant"
        elif { global.nxtBoardFanPins == { "aux0" } }
            set var.fp = "aux0"
        elif { global.nxtBoardFanPins == { "aux1" } }
            set var.fp = "aux1"
        elif { global.nxtBoardFanPins == { "aux2" } }
            set var.fp = "aux2"
        elif { global.nxtBoardFanPins == { "relay" } }
            set var.fp = "relay"
        else
            set var.fp = { "" ^ global.nxtBoardFanPins }

        if { var.fp == "" || var.fp == "none" }
            set var.none = true
        else
            set var.hay = "," ^ var.fp ^ ","

if { !var.none && var.hay != "" }
    if { find(var.hay, ",mist,") >= 0 }
        set var.mist = true
    if { find(var.hay, ",coolant,") >= 0 }
        set var.coolant = true
    if { find(var.hay, ",aux0,") >= 0 }
        set var.aux0 = true
    if { find(var.hay, ",aux1,") >= 0 }
        set var.aux1 = true
    if { find(var.hay, ",aux2,") >= 0 }
        set var.aux2 = true
    if { find(var.hay, ",relay,") >= 0 }
        set var.relay = true

if { !var.aux0 }
    if { !exists(global.nxtAux1ID) }
        global nxtAux1ID = 0
    elif { global.nxtAux1ID == null }
        set global.nxtAux1ID = 0

if { !var.aux1 }
    if { !exists(global.nxtAux2ID) }
        global nxtAux2ID = 1
    elif { global.nxtAux2ID == null }
        set global.nxtAux2ID = 1

if { !var.aux2 }
    if { !exists(global.nxtAux3ID) }
        global nxtAux3ID = 2
    elif { global.nxtAux3ID == null }
        set global.nxtAux3ID = 2

if { !var.coolant }
    if { !exists(global.nxtCoolantFloodID) }
        global nxtCoolantFloodID = 3
    elif { global.nxtCoolantFloodID == null }
        set global.nxtCoolantFloodID = 3

if { !var.mist }
    if { !exists(global.nxtCoolantMistID) }
        global nxtCoolantMistID = 4
    elif { global.nxtCoolantMistID == null }
        set global.nxtCoolantMistID = 4

if { !var.relay }
    if { !exists(global.nxtRelayID) }
        global nxtRelayID = 5
    elif { global.nxtRelayID == null }
        set global.nxtRelayID = 5
