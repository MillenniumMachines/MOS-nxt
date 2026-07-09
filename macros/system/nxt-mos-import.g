; nxt-mos-import.g
; One-shot migration: read legacy MillenniumOS configuration from SD, copy into nxt globals,
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
var hasMosSource = var.nxtMosSentinel
if { fileexists("0:/sys/mos-vars.g") || fileexists("0:/sys/mos-user-vars.g") || fileexists("0:/sys/mos.g") }
    set var.hasMosSource = true
if { fileexists("0:/sys/mos-maintenance.g") }
    set var.hasMosSource = true
if { exists(global.mosSID) }
    set var.hasMosSource = true
if { exists(global.mosFeatTouchProbe) }
    set var.hasMosSource = true
if { exists(global.mosPTID) }
    set var.hasMosSource = true
if { exists(global.mosProbeToolID) }
    set var.hasMosSource = true
if { exists(global.mosLdd) }
    set var.hasMosSource = true

if { !var.hasMosSource }
    echo "nxt MOS import: no MillenniumOS files or mos* globals found — nothing to migrate"
    M99

if { fileexists("0:/sys/mos-vars.g") }
    M98 P"mos-vars.g"

if { fileexists("0:/sys/mos-user-vars.g") }
    M98 P"mos-user-vars.g"

if { fileexists("0:/sys/mos-maintenance.g") }
    M98 P"mos-maintenance.g"

if { fileexists("0:/sys/nxt-user-vars.g") }
    M98 P"nxt-user-vars.g"

; Copy MOS data globals (mosTT, mosWPCtrPos, …) into nxt* when not already set.
M98 P"nxt-mos-globals-align.g"

if { exists(global.mosFeatTouchProbe) }
    set global.nxtFeatureTouchProbe = { global.mosFeatTouchProbe }
if { exists(global.mosFeatToolSetter) }
    set global.nxtFeatureToolSetter = { global.mosFeatToolSetter }
if { exists(global.mosFeatCoolantControl) }
    set global.nxtFeatureCoolantControl = { global.mosFeatCoolantControl }
if { exists(global.mosPTID) }
    set global.nxtProbeToolID = { global.mosPTID }
if { exists(global.mosProbeToolID) }
    set global.nxtProbeToolID = { global.mosProbeToolID }

; Normalize Jake dual-slot (probe @ 48, datum @ 49) and legacy indices → single slot at limits.tools - 1.
set global.nxtProbeToolID = { limits.tools - 1 }
set global.nxtReservedFrom = { limits.tools - 1 }
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
if { exists(global.mosDTR) }
    set global.nxtDatumToolRadius = { global.mosDTR }
if { exists(global.mosPMBO) }
    set global.nxtProtectedMoveBackOff = { global.mosPMBO }
if { exists(global.mosTPRP) }
    set global.nxtTouchProbeRefPos = { global.mosTPRP }
if { exists(global.mosTSR) }
    set global.nxtToolSetterRadius = { global.mosTSR }
if { exists(global.mosFAE) }
    set global.nxtFeatureFourthAxis = { global.mosFAE != 0 }

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

if { exists(global.mosRelayID) }
    set global.nxtRelayID = { global.mosRelayID }
if { exists(global.mosFeatMaint) }
    set global.nxtFeatMaint = { global.mosFeatMaint }
if { exists(global.mosAxisTravel) && exists(global.nxtAxisTravel) }
    var nxtAxN = { min(#global.mosAxisTravel, #global.nxtAxisTravel) }
    while { iterations < var.nxtAxN }
        set global.nxtAxisTravel[iterations] = { global.mosAxisTravel[iterations] }
if { exists(global.mosAxisServiceAt) && exists(global.nxtAxisServiceAt) }
    var nxtSvcN = { min(#global.mosAxisServiceAt, #global.nxtAxisServiceAt) }
    while { iterations < var.nxtSvcN }
        set global.nxtAxisServiceAt[iterations] = { global.mosAxisServiceAt[iterations] }
if { exists(global.mosToolLife) && exists(global.nxtToolLife) }
    var nxtLifeN = { min(#global.mosToolLife, #global.nxtToolLife) }
    while { iterations < var.nxtLifeN }
        set global.nxtToolLife[iterations] = { global.mosToolLife[iterations] }
if { exists(global.mosCoolantRuntime) }
    set global.nxtCoolantRuntime = { global.mosCoolantRuntime }
if { exists(global.mosCoolantServiceAt) }
    set global.nxtCoolantServiceAt = { global.mosCoolantServiceAt }
if { exists(global.mosFeatIdleActions) }
    set global.nxtFeatIdleActions = { global.mosFeatIdleActions }
if { exists(global.mosIdleAfter) }
    set global.nxtIdleAfter = { global.mosIdleAfter }
if { exists(global.mosIdleFanLow) }
    set global.nxtIdleFanLow = { global.mosIdleFanLow }
if { exists(global.mosIdleDimBri) }
    set global.nxtIdleDimBri = { global.mosIdleDimBri }

if { exists(global.mosEM) }
    set global.nxtExpertMode = { global.mosEM }
if { exists(global.mosTM) }
    set global.nxtTutorialMode = { global.mosTM }
if { exists(global.mosWS) }
    set global.nxtWS = { global.mosWS }
if { exists(global.mosAutoPersistTools) }
    set global.nxtAutoPersistTools = { global.mosAutoPersistTools }
if { exists(global.mosTTLocked) }
    set global.nxtTTLocked = { global.mosTTLocked }
if { exists(global.mosReservedFrom) }
    set global.nxtReservedFrom = { limits.tools - 1 }
if { exists(global.mosFeatRGB) }
    set global.nxtFeatureRgbLight = { global.mosFeatRGB }

if { exists(global.nxtFeatMaint) && global.nxtFeatMaint }
    M98 P"nxt/nxt-save-maintenance.g"

var UV = "0:/sys/nxt-user-vars.g"

echo >{var.UV} {"; nxt User Configuration"}
echo >>{var.UV} {"; Written by nxt-mos-import.g (Millennium OS migration)"}
echo >>{var.UV} {"; Re-run: M98 P""nxt-mos-import.g"""}
echo >>{var.UV} {""}
echo >>{var.UV} {"; Feature Flags"}
echo >>{var.UV} {"set global.nxtFeatureTouchProbe = " ^ (global.nxtFeatureTouchProbe ? "true" : "false")}
echo >>{var.UV} {"set global.nxtFeatureToolSetter = " ^ (global.nxtFeatureToolSetter ? "true" : "false")}
echo >>{var.UV} {"set global.nxtFeatureCoolantControl = " ^ (global.nxtFeatureCoolantControl ? "true" : "false")}
echo >>{var.UV} {"set global.nxtFeatureFourthAxis = " ^ (global.nxtFeatureFourthAxis ? "true" : "false")}
echo >>{var.UV} {""}
echo >>{var.UV} {"; Probe tool index (datum / touch probe tool table slot)"}
echo >>{var.UV} {"set global.nxtProbeToolID = " ^ (global.nxtProbeToolID == null ? "null" : global.nxtProbeToolID)}
echo >>{var.UV} {"set global.nxtReservedFrom = " ^ (global.nxtReservedFrom == null ? "null" : global.nxtReservedFrom)}
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
if { global.nxtProbeDeflection == null }
    echo >>{var.UV} {"set global.nxtProbeDeflection = null"}
elif { #global.nxtProbeDeflection >= 2 }
    echo >>{var.UV} {"set global.nxtProbeDeflection = {" ^ global.nxtProbeDeflection[0] ^ ", " ^ global.nxtProbeDeflection[1] ^ "}"}
elif { #global.nxtProbeDeflection == 1 }
    echo >>{var.UV} {"set global.nxtProbeDeflection = {" ^ global.nxtProbeDeflection[0] ^ ", 0}"}
else
    echo >>{var.UV} {"set global.nxtProbeDeflection = {" ^ global.nxtProbeDeflection[0] ^ "}"}
echo >>{var.UV} {"set global.nxtDatumToolRadius = " ^ (global.nxtDatumToolRadius == null ? "null" : global.nxtDatumToolRadius)}
echo >>{var.UV} {"set global.nxtProtectedMoveBackOff = " ^ (global.nxtProtectedMoveBackOff == null ? "null" : global.nxtProtectedMoveBackOff)}
if { global.nxtTouchProbeRefPos == null }
    echo >>{var.UV} {"set global.nxtTouchProbeRefPos = null"}
elif { #global.nxtTouchProbeRefPos >= 3 }
    echo >>{var.UV} {"set global.nxtTouchProbeRefPos = {" ^ global.nxtTouchProbeRefPos[0] ^ ", " ^ global.nxtTouchProbeRefPos[1] ^ ", " ^ global.nxtTouchProbeRefPos[2] ^ "}"}
elif { #global.nxtTouchProbeRefPos == 2 }
    echo >>{var.UV} {"set global.nxtTouchProbeRefPos = {" ^ global.nxtTouchProbeRefPos[0] ^ ", " ^ global.nxtTouchProbeRefPos[1] ^ "}"}
else
    echo >>{var.UV} {"set global.nxtTouchProbeRefPos = {" ^ global.nxtTouchProbeRefPos[0] ^ "}"}
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
echo >>{var.UV} {"set global.nxtToolSetterRadius = " ^ (global.nxtToolSetterRadius == null ? "null" : global.nxtToolSetterRadius)}

echo >>{var.UV} {""}
echo >>{var.UV} {"; Coolant Configuration"}
echo >>{var.UV} {"set global.nxtCoolantAirID = " ^ (global.nxtCoolantAirID == null ? "null" : global.nxtCoolantAirID)}
echo >>{var.UV} {"set global.nxtCoolantMistID = " ^ (global.nxtCoolantMistID == null ? "null" : global.nxtCoolantMistID)}
echo >>{var.UV} {"set global.nxtCoolantFloodID = " ^ (global.nxtCoolantFloodID == null ? "null" : global.nxtCoolantFloodID)}
echo >>{var.UV} {""}
echo >>{var.UV} {"; Board / platform (Configuration panel)"}
if { global.nxtPlatformProfile == null }
    echo >>{var.UV} {"set global.nxtPlatformProfile = null"}
else
    echo >>{var.UV} {"set global.nxtPlatformProfile = "" ^ global.nxtPlatformProfile ^ """}
if { global.nxtBoardShortNameOverride == null }
    echo >>{var.UV} {"set global.nxtBoardShortNameOverride = null"}
else
    echo >>{var.UV} {"set global.nxtBoardShortNameOverride = "" ^ global.nxtBoardShortNameOverride ^ """}
if { global.nxtBoardKitKey == null }
    echo >>{var.UV} {"set global.nxtBoardKitKey = null"}
else
    echo >>{var.UV} {"set global.nxtBoardKitKey = "" ^ global.nxtBoardKitKey ^ """}
if { global.nxtBoardMotorVoltage == null }
    if { global.nxtScyllaMotorVoltage == null }
        echo >>{var.UV} {"set global.nxtBoardMotorVoltage = null"}
    else
        echo >>{var.UV} {"set global.nxtBoardMotorVoltage = " ^ global.nxtScyllaMotorVoltage}
else
    echo >>{var.UV} {"set global.nxtBoardMotorVoltage = " ^ global.nxtBoardMotorVoltage}
if { global.nxtBoardBootstrapMode == "auto" }
    echo >>{var.UV} {"set global.nxtBoardBootstrapMode = ""auto"""}
else
    echo >>{var.UV} {"set global.nxtBoardBootstrapMode = ""off"""}
if { global.nxtBoardPackExpectedEntry == null }
    echo >>{var.UV} {"set global.nxtBoardPackExpectedEntry = null"}
else
    echo >>{var.UV} {"set global.nxtBoardPackExpectedEntry = "" ^ global.nxtBoardPackExpectedEntry ^ """}
if { global.nxtBoardSysDeployPlatform == null }
    echo >>{var.UV} {"set global.nxtBoardSysDeployPlatform = null"}
else
    echo >>{var.UV} {"set global.nxtBoardSysDeployPlatform = "" ^ global.nxtBoardSysDeployPlatform ^ """}
echo >>{var.UV} {""}
echo >>{var.UV} {"; gpOut snapshot (caps min(limits.gpOutPorts,32) in nxt-vars.g)"}
var pline = {"set global.nxtPinStates = {"}
while { iterations < #global.nxtPinStates }
    set var.pline = { var.pline ^ (iterations > 0 ? ", " : "") ^ global.nxtPinStates[iterations] }
set var.pline = { var.pline ^ "}" }
echo >>{var.UV} {var.pline}

echo "nxt: MOS migration complete — saved " ^ var.UV

if { var.nxtMosSentinel }
    M472 P{"0:/sys/nxt-mos-import.requested"}
