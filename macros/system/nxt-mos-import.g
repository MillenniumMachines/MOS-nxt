; nxt-mos-import.g
; Millennium OS -> NeXT: map mos* globals into nxt* and write nxt-user-vars.g.
; Intended load order (see nxt.g): mos-vars.g -> mos-user-vars.g -> this file -> nxt-user-vars.g
; Manual: M98 P"nxt-mos-import.g" (loads MOS files here if not already in memory)
; Sentinel: 0:/sys/nxt-mos-import.requested (removed after successful import when present)
; CNC meta: use { } for conditions — see macros/system/RRF_META.txt.

var nxtMosSentinel = { fileexists("0:/sys/nxt-mos-import.requested") }
var mosUserLoaded = false

if { !fileexists("0:/sys/mos-vars.g") }
    M99

if { !exists(global.mosVarsLoaded) }
    M98 P"mos-vars.g"

if { exists(global.mosVarsLoaded) && fileexists("0:/sys/mos-user-vars.g") }
    M98 P"mos-user-vars.g"
    set var.mosUserLoaded = true

; Merge existing NeXT user file (e.g. nxtDeltaMachine) before applying MOS map
if { fileexists("0:/sys/nxt-user-vars.g") }
    M98 P"nxt-user-vars.g"

set global.nxtFeatureTouchProbe = { global.mosFeatTouchProbe }
set global.nxtFeatureToolSetter = { global.mosFeatToolSetter }
set global.nxtFeatureCoolantControl = { global.mosFeatCoolantControl }
set global.nxtProbeToolID = { global.mosPTID }
set global.nxtTouchProbeID = { global.mosTPID }
set global.nxtToolSetterID = { global.mosTSID }
set global.nxtProbeTipRadius = { global.mosTPR }
set global.nxtProbeDeflection = { global.mosTPD }
set global.nxtToolSetterPos = { global.mosTSP }
set global.nxtSpindleID = { global.mosSID }
set global.nxtSpindleAccelSec = { global.mosSAS }
set global.nxtSpindleDecelSec = { global.mosSDS }
set global.nxtCoolantAirID = { global.mosCAID }
set global.nxtCoolantMistID = { global.mosCMID }
set global.nxtCoolantFloodID = { global.mosCFID }

var pinN = { min(#global.mosPS, #global.nxtPinStates) }
while { iterations < var.pinN }
    set global.nxtPinStates[iterations] = { global.mosPS[iterations] }

if { global.mosTCS == null }
    set global.nxtToolChangeState = null
elif { global.mosTCS >= 0 && global.mosTCS <= 4 }
    set global.nxtToolChangeState = { global.mosTCS + 1 }
else
    set global.nxtToolChangeState = null

var UV = "0:/sys/nxt-user-vars.g"

echo >{var.UV} {"; NeXT User Configuration"}
echo >>{var.UV} {"; Written by nxt-mos-import.g (Millennium OS migration) - MOS sys files are redundant once NeXT owns this file."}
echo >>{var.UV} {"; Re-run: M98 P""nxt-mos-import.g"""}
echo >>{var.UV} {""}
echo >>{var.UV} {"; Feature Flags"}
echo >>{var.UV} {"set global.nxtFeatureTouchProbe = " ^ (global.nxtFeatureTouchProbe ? "true" : "false")}
echo >>{var.UV} {"set global.nxtFeatureToolSetter = " ^ (global.nxtFeatureToolSetter ? "true" : "false")}
echo >>{var.UV} {"set global.nxtFeatureCoolantControl = " ^ (global.nxtFeatureCoolantControl ? "true" : "false")}
echo >>{var.UV} {""}
echo >>{var.UV} {"; Probe tool index (datum / touch probe tool table slot)"}
echo >>{var.UV} {"set global.nxtProbeToolID = " ^ (global.nxtProbeToolID == null ? "null" : global.nxtProbeToolID)}
echo >>{var.UV} {"set global.nxtDeltaMachine = " ^ (global.nxtDeltaMachine == null ? "null" : global.nxtDeltaMachine)}
echo >>{var.UV} {""}
echo >>{var.UV} {"; Spindle Configuration"}
echo >>{var.UV} {"set global.nxtSpindleID = " ^ (global.nxtSpindleID == null ? "null" : global.nxtSpindleID)}
echo >>{var.UV} {"set global.nxtSpindleAccelSec = " ^ (global.nxtSpindleAccelSec == null ? "null" : global.nxtSpindleAccelSec)}
echo >>{var.UV} {"set global.nxtSpindleDecelSec = " ^ (global.nxtSpindleDecelSec == null ? "null" : global.nxtSpindleDecelSec)}
echo >>{var.UV} {""}
echo >>{var.UV} {"; Touch Probe Configuration"}
echo >>{var.UV} {"set global.nxtTouchProbeID = " ^ (global.nxtTouchProbeID == null ? "null" : global.nxtTouchProbeID)}
echo >>{var.UV} {"set global.nxtProbeTipRadius = " ^ (global.nxtProbeTipRadius == null ? "null" : global.nxtProbeTipRadius)}
echo >>{var.UV} {"set global.nxtProbeDeflection = " ^ (global.nxtProbeDeflection == null ? "null" : global.nxtProbeDeflection)}
echo >>{var.UV} {""}
echo >>{var.UV} {"; Tool Setter Configuration"}
echo >>{var.UV} {"set global.nxtToolSetterID = " ^ (global.nxtToolSetterID == null ? "null" : global.nxtToolSetterID)}
if { global.nxtToolSetterPos == null }
    echo >>{var.UV} {"set global.nxtToolSetterPos = null"}
elif { #global.nxtToolSetterPos >= 3 }
    echo >>{var.UV} {"set global.nxtToolSetterPos = {" ^ global.nxtToolSetterPos[0] ^ ", " ^ global.nxtToolSetterPos[1] ^ ", " ^ global.nxtToolSetterPos[2] ^ "}"}
elif { #global.nxtToolSetterPos == 2 }
    echo >>{var.UV} {"set global.nxtToolSetterPos = {" ^ global.nxtToolSetterPos[0] ^ ", " ^ global.nxtToolSetterPos[1] ^ "}"}
else
    echo >>{var.UV} {"set global.nxtToolSetterPos = {" ^ global.nxtToolSetterPos[0] ^ "}"}

echo >>{var.UV} {""}
echo >>{var.UV} {"; Coolant Configuration"}
echo >>{var.UV} {"set global.nxtCoolantAirID = " ^ (global.nxtCoolantAirID == null ? "null" : global.nxtCoolantAirID)}
echo >>{var.UV} {"set global.nxtCoolantMistID = " ^ (global.nxtCoolantMistID == null ? "null" : global.nxtCoolantMistID)}
echo >>{var.UV} {"set global.nxtCoolantFloodID = " ^ (global.nxtCoolantFloodID == null ? "null" : global.nxtCoolantFloodID)}
echo >>{var.UV} {""}
echo >>{var.UV} {"; gpOut snapshot (caps min(limits.gpOutPorts,32) in nxt-vars.g)"}
var pline = {"global nxtPinStates = {"}
while { iterations < #global.nxtPinStates }
    set var.pline = { var.pline ^ (iterations > 0 ? ", " : "") ^ global.nxtPinStates[iterations] }
set var.pline = { var.pline ^ "}" }
echo >>{var.UV} {var.pline}

echo "NeXT: MOS import - used mos-vars.g" ^ (var.mosUserLoaded ? " and mos-user-vars.g" : "") ^ "; merged into NeXT globals and saved " ^ var.UV ^ ". MOS var files are redundant going forward."

if { var.nxtMosSentinel }
    M472 P{"0:/sys/nxt-mos-import.requested"}
