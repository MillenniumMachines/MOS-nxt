; nxt-run-vssc.g: Variable Spindle Speed Control tick
; Called from nxt-daemon.g while nxtVSEnabled.

if { !inputs[state.thisInput].active }
    M99

if { !exists(global.nxtLoaded) || !global.nxtLoaded }
    M99

if { !exists(global.nxtVSEnabled) || !global.nxtVSEnabled }
    M99

if { state.status == "pausing" || state.status == "paused" }
    M99

if { state.status == "resuming" }
    M99

var sid = 0
if { exists(global.nxtSpindleID) && global.nxtSpindleID != null }
    set var.sid = { global.nxtSpindleID }

if { var.sid < 0 || var.sid > #spindles-1 }
    M99

if { spindles[var.sid] == null }
    M99

if { spindles[var.sid].state == "unconfigured" }
    M99

var spState = { spindles[var.sid].state }
if { var.spState != "forward" && var.spState != "reverse" }
    M99

var curRpm = { abs(spindles[var.sid].active) }
if { var.curRpm == 0 }
    M99

if { global.nxtVSP <= 0 || global.nxtVSV <= 0 }
    M99

var nowMs = { millis() }
if { var.nowMs < global.nxtVSPT }
    set global.nxtVSPT = { var.nowMs }
    M99

var halfV = { global.nxtVSV / 2 }
var lo = { global.nxtVSPS - var.halfV }
var hi = { global.nxtVSPS + var.halfV }
if { var.lo < spindles[var.sid].min }
    set var.lo = { spindles[var.sid].min }
if { var.hi > spindles[var.sid].max }
    set var.hi = { spindles[var.sid].max }

; New M3.9 / programmed speed outside the current band — recapture base.
if { var.curRpm < var.lo || var.curRpm > var.hi }
    set global.nxtVSPS = { var.curRpm }
    set global.nxtVSPT = { var.nowMs }
    M99

if { global.nxtVSPS <= 0 }
    set global.nxtVSPS = { var.curRpm }
    set global.nxtVSPT = { var.nowMs }
    M99

var elapsed = { var.nowMs - global.nxtVSPT }
var tau = { 2 * pi * var.elapsed / global.nxtVSP }
var adj = { var.lo + var.halfV * (1 + sin(var.tau)) }
if { var.adj < spindles[var.sid].min }
    set var.adj = { spindles[var.sid].min }
if { var.adj > spindles[var.sid].max }
    set var.adj = { spindles[var.sid].max }

var adjRpm = { round(var.adj) }
if { abs(var.adjRpm - var.curRpm) < 1 }
    M99

var hasTool = false
if { state.currentTool >= 0 }
    if { state.currentTool < limits.tools }
        set var.hasTool = true

if { var.hasTool }
    M568 F{var.adjRpm}
elif { var.spState == "reverse" }
    M4 S{var.adjRpm} P{var.sid}
else
    M3 S{var.adjRpm} P{var.sid}
