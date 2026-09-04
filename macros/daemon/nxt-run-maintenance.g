; nxt-run-maintenance.g
;
; nxt maintenance accumulator. Called from the daemon a few times a second.
; Accumulates per-axis travel distance (for grease/oil reminders) and per-tool spindle-on
; time (tool life). Persists to SD only on ACTIVE ticks, so an idle machine never writes.
;
; Travel sampling is daemon-rate, so it UNDERCOUNTS fast moves between ticks - good enough for a
; service reminder, not metrology.

if { !inputs[state.thisInput].active }
    M99

if { !exists(global.nxtFeatMaint) || !global.nxtFeatMaint || !exists(global.nxtAxisTravel) }
    M99
if { !exists(global.nxtMaintLastPos) }
    M99

; Self-declare edge-tracking globals if a partial deploy left them missing.
if { !exists(global.nxtMaintWasActive) }
    global nxtMaintWasActive = false
if { !exists(global.nxtIdleActive) }
    global nxtIdleActive = false
if { !exists(global.nxtCoolantRuntime) }
    global nxtCoolantRuntime = 0
if { !exists(global.nxtIdleSince) }
    global nxtIdleSince = { state.upTime }

var active = false
var a = 0

; Prime on the first run without accumulating (avoids a huge jump from zeroed last-position at boot).
if { !global.nxtMaintPrimed }
    set var.a = 0
    var nxtPosN = { min(#move.axes, #global.nxtMaintLastPos) }
    while { var.a < var.nxtPosN }
        set global.nxtMaintLastPos[var.a] = { move.axes[var.a].machinePosition }
        set var.a = { var.a + 1 }
    set global.nxtMaintLastTime = { state.upTime }
    set global.nxtMaintPrimed = true
    M99

; --- Axis travel: sum abs(delta machinePosition) per homed axis ---
set var.a = 0
var nxtTravelN = { min(#move.axes, #global.nxtAxisTravel) }
set var.nxtTravelN = { min(var.nxtTravelN, #global.nxtMaintLastPos) }
while { var.a < var.nxtTravelN }
    if { move.axes[var.a].homed }
        var d = { move.axes[var.a].machinePosition - global.nxtMaintLastPos[var.a] }
        if { var.d < 0 }
            set var.d = { -var.d }
        if { var.d > 0 }
            set global.nxtAxisTravel[var.a] = { global.nxtAxisTravel[var.a] + var.d }
            set var.active = true
    set global.nxtMaintLastPos[var.a] = { move.axes[var.a].machinePosition }
    set var.a = { var.a + 1 }

; --- Spindle state: spinning spindle counts as activity even without a tool loaded ---
var spindleOn = false
var nxtHasSpindle = { exists(global.nxtSpindleID) && global.nxtSpindleID != null }
var nxtSpindleIdx = { var.nxtHasSpindle ? global.nxtSpindleID : -1 }
if { var.nxtSpindleIdx >= 0 && var.nxtSpindleIdx < #spindles }
    if { spindles[var.nxtSpindleIdx] != null && spindles[var.nxtSpindleIdx].current != 0 }
        set var.spindleOn = true

; --- Tool life: spindle-on seconds while a real (non-probe) tool is loaded ---
var dt = { state.upTime - global.nxtMaintLastTime }
set global.nxtMaintLastTime = { state.upTime }
var ct = { state.currentTool }
var nxtLifeOk = { var.ct >= 0 }
if { exists(global.nxtProbeToolID) && global.nxtProbeToolID != null }
    set var.nxtLifeOk = { var.nxtLifeOk && var.ct != global.nxtProbeToolID }
if { var.nxtLifeOk && var.spindleOn && var.dt > 0 && var.dt < 10 }
    M98 P"nxt-tool-life-ensure.g"
    if { var.ct < #global.nxtToolLife }
        if { global.nxtToolLife[var.ct] == null }
            set global.nxtToolLife[var.ct] = 0
        set global.nxtToolLife[var.ct] = { global.nxtToolLife[var.ct] + var.dt }
        set var.active = true

; --- Coolant / mister runtime: count seconds while any coolant output is firing ---
if { exists(global.nxtFeatureCoolantControl) && global.nxtFeatureCoolantControl }
    var coolOn = false
    if { exists(global.nxtCoolantMistID) && global.nxtCoolantMistID != null }
        if { global.nxtCoolantMistID < #state.gpOut && state.gpOut[global.nxtCoolantMistID].pwm > 0 }
            set var.coolOn = true
    if { exists(global.nxtCoolantFloodID) && global.nxtCoolantFloodID != null }
        if { global.nxtCoolantFloodID < #state.gpOut && state.gpOut[global.nxtCoolantFloodID].pwm > 0 }
            set var.coolOn = true
    if { exists(global.nxtCoolantAirID) && global.nxtCoolantAirID != null }
        if { global.nxtCoolantAirID < #state.gpOut && state.gpOut[global.nxtCoolantAirID].pwm > 0 }
            set var.coolOn = true
    if { var.coolOn && var.dt > 0 && var.dt < 10 }
        set global.nxtCoolantRuntime = { global.nxtCoolantRuntime + var.dt }
        set var.active = true

; --- Persist strategy ---
if { var.active }
    set global.nxtMaintTick = { global.nxtMaintTick + 1 }
    if { global.nxtMaintTick >= global.nxtMaintPersistEvery }
        set global.nxtMaintTick = 0
        M98 P"nxt/nxt-save-maintenance.g"
elif { global.nxtMaintWasActive }
    set global.nxtMaintTick = 0
    M98 P"nxt/nxt-save-maintenance.g"

set global.nxtMaintWasActive = { var.active }

; --- Idle auto-actions: dim RGB + E-bay fan low after nxtIdleAfter of inactivity ---
if { exists(global.nxtFeatIdleActions) && global.nxtFeatIdleActions }
    if { var.active || var.spindleOn || state.status != "idle" }
        set global.nxtIdleSince = { state.upTime }
        if { global.nxtIdleActive }
            set global.nxtIdleActive = false
            M106 P0 S1
    elif { !global.nxtIdleActive && (state.upTime - global.nxtIdleSince) >= global.nxtIdleAfter }
        set global.nxtIdleActive = true
        M106 P0 S{global.nxtIdleFanLow}
