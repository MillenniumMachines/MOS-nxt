; nxt-mos-import.g
; One-shot migration: read legacy MillenniumOS configuration from SD, copy into NeXT globals,
; write 0:/sys/nxt-user-vars.g. Does not depend on mosVarsLoaded or whether MOS is still "active".
;
; Typical SD sources (run in order when present):
;   mos-vars.g       — MOS defaults
;   mos-user-vars.g  — operator / wizard values
;   nxt-user-vars.g  — merged before mapping if it already exists (e.g. nxtDeltaMachine)
;
; Manual: M98 P"nxt-mos-import.g"
; Boot: nxt.g runs this when mos*.g and/or mos* globals are present (see nxt.g); optional
;       0:/sys/nxt-mos-import.requested forces a re-import (removed after success).
; CNC meta: use { } for conditions — see macros/system/RRF_META.txt.
;
; Each mos* -> nxt* copy uses exists(global.mos*) so a partial MOS install does not abort.

var nxtMosSentinel = { fileexists("0:/sys/nxt-mos-import.requested") }
var hasMosSource = { var.nxtMosSentinel || fileexists("0:/sys/mos-vars.g") || fileexists("0:/sys/mos-user-vars.g") || fileexists("0:/sys/mos.g") || exists(global.mosSID) || exists(global.mosFeatTouchProbe) || exists(global.mosPTID) || exists(global.mosLdd) }

if { !var.hasMosSource }
    echo "NeXT MOS import: no MillenniumOS files or mos* globals found — nothing to migrate"
    M99

if { fileexists("0:/sys/mos-vars.g") }
    M98 P"mos-vars.g"

if { fileexists("0:/sys/mos-user-vars.g") }
    M98 P"mos-user-vars.g"

if { fileexists("0:/sys/nxt-user-vars.g") }
    M98 P"nxt-user-vars.g"

if { exists(global.mosFeatTouchProbe) }
    set global.nxtFeatureTouchProbe = { global.mosFeatTouchProbe }
if { exists(global.mosFeatToolSetter) }
    set global.nxtFeatureToolSetter = { global.mosFeatToolSetter }
if { exists(global.mosFeatCoolantControl) }
    set global.nxtFeatureCoolantControl = { global.mosFeatCoolantControl }
if { exists(global.mosPTID) }
    set global.nxtProbeToolID = { global.mosPTID }
if { exists(global.mosTPID) }
    set global.nxtTouchProbeID = { global.mosTPID }
if { exists(global.mosTSID) }
    set global.nxtToolSetterID = { global.mosTSID }
if { exists(global.mosTPR) }
    set global.nxtProbeTipRadius = { global.mosTPR }
if { exists(global.mosTPD) }
    set global.nxtProbeDeflection = { global.mosTPD }
if { exists(global.mosTSP) }
    set global.nxtToolSetterPos = { global.mosTSP }
if { exists(global.mosSID) }
    set global.nxtSpindleID = { global.mosSID }
if { exists(global.mosSAS) }
    set global.nxtSpindleAccelSec = { global.mosSAS }
if { exists(global.mosSDS) }
    set global.nxtSpindleDecelSec = { global.mosSDS }
if { exists(global.mosCAID) }
    set global.nxtCoolantAirID = { global.mosCAID }
if { exists(global.mosCMID) }
    set global.nxtCoolantMistID = { global.mosCMID }
if { exists(global.mosCFID) }
    set global.nxtCoolantFloodID = { global.mosCFID }

if { exists(global.mosPS) && exists(global.nxtPinStates) }
    var pinN = { min(#global.mosPS, #global.nxtPinStates) }
    while { iterations < var.pinN }
        set global.nxtPinStates[iterations] = { global.mosPS[iterations] }

if { exists(global.mosTCS) }
    if { global.mosTCS == null }
        set global.nxtToolChangeState = null
    elif { global.mosTCS >= 0 && global.mosTCS <= 4 }
        set global.nxtToolChangeState = { global.mosTCS + 1 }
    else
        set global.nxtToolChangeState = null

var UV = "0:/sys/nxt-user-vars.g"

echo >{var.UV} {"; NeXT User Configuration"}
echo >>{var.UV} {"; Written by nxt-mos-import.g (Millennium OS migration)"}
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
var pline = {"set global.nxtPinStates = {"}
while { iterations < #global.nxtPinStates }
    set var.pline = { var.pline ^ (iterations > 0 ? ", " : "") ^ global.nxtPinStates[iterations] }
set var.pline = { var.pline ^ "}" }
echo >>{var.UV} {var.pline}

echo "NeXT: MOS migration complete — saved " ^ var.UV

if { var.nxtMosSentinel }
    M472 P{"0:/sys/nxt-mos-import.requested"}
