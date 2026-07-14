; gpio.g — Scylla named outputs (mist, coolant, aux0, aux1, aux2, relay)
;
; Preferred gpOut indices when pin is NOT a fan:
;   mist=J0 coolant=J1 aux0=J2 aux1=J3 aux2=J4 relay=J5
; Pins listed in global.nxtBoardFanPins are created as M950 F (not J).
; Default when null/missing: 24V → "aux0", 48V → "aux1".
; Explicit none: "" or "none". Persist form: CSV string ("aux0" / "mist,aux1").
; Legacy single-pin vectors { "aux0" } still recognized. No array indexing.
; Local vars mist/coolant/aux*/relay mean "create this alias as M950 F".

; --- Normalize missing/null → voltage default (CSV string) ---
if { !exists(global.nxtBoardFanPins) }
    if { exists(global.nxtBoardMotorVoltage) && global.nxtBoardMotorVoltage == 48 }
        global nxtBoardFanPins = "aux1"
    else
        global nxtBoardFanPins = "aux0"
elif { global.nxtBoardFanPins == null }
    if { exists(global.nxtBoardMotorVoltage) && global.nxtBoardMotorVoltage == 48 }
        set global.nxtBoardFanPins = "aux1"
    else
        set global.nxtBoardFanPins = "aux0"

; --- Fan membership (CSV / scalar / legacy single-element vectors only) ---
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
        ; Scalar / CSV string (Configuration Save)
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
            ; Multi-pin CSV or odd OM types — force string (RRF: "" ^ x)
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

; Sequential fan indices as fans are created
var nextFan = 0

; mist — PA_7 / mist
if { var.mist }
    M950 F{var.nextFan} C"PA_7" Q500
    M106 P{var.nextFan} S1 H-1
    set var.nextFan = { var.nextFan + 1 }
else
    M950 J0 C"mist"

; coolant — PC_4 / coolant
if { var.coolant }
    M950 F{var.nextFan} C"PC_4" Q500
    M106 P{var.nextFan} S1 H-1
    set var.nextFan = { var.nextFan + 1 }
else
    M950 J1 C"coolant"

; aux0 — PA_4 / aux0
if { var.aux0 }
    M950 F{var.nextFan} C"PA_4" Q500
    M106 P{var.nextFan} S1 H-1
    set var.nextFan = { var.nextFan + 1 }
else
    M950 J2 C"aux0"

; aux1 — PA_5 / aux1
if { var.aux1 }
    M950 F{var.nextFan} C"PA_5" Q500
    M106 P{var.nextFan} S1 H-1
    set var.nextFan = { var.nextFan + 1 }
else
    M950 J3 C"aux1"

; aux2 — PA_6 / aux2
if { var.aux2 }
    M950 F{var.nextFan} C"PA_6" Q500
    M106 P{var.nextFan} S1 H-1
    set var.nextFan = { var.nextFan + 1 }
else
    M950 J4 C"aux2"

; relay — PD_5 / relay
if { var.relay }
    M950 F{var.nextFan} C"PD_5" Q500
    M106 P{var.nextFan} S1 H-1
    set var.nextFan = { var.nextFan + 1 }
else
    M950 J5 C"relay"
