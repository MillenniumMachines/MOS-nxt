; nxt-run-rgb.g
;
; nxt RGB status renderer. Called from the daemon a few times a
; second. Turns the current machine state into a colour and drives the LED
; strip. Only touches the strip when the state actually changes, so it never
; floods the command queue.

; Create the LED strip once, the first time we run with a pin configured.
if { !global.nxtRGBReady && global.nxtRGBPin != null }
    M950 E{global.nxtRGBStrip} C{global.nxtRGBPin} T{global.nxtRGBType} K{global.nxtRGBOrder} U{global.nxtRGBCount}
    set global.nxtRGBReady = true

; Work out the effective state, highest priority first:
; error > paused > tool change > probing > homing > running > idle.
; Colour index into global.nxtRGBCol: 0 idle, 1 home, 2 probe, 3 tool,
; 4 run, 5 paused, 6 error.
var st = "idle"
var colIdx = 0

; Test override forces a colour (Status tab test button / testing without
; hardware). When it's set we skip the live state and the idle-clear entirely.
if { global.nxtRGBTest != "" }
    set var.st = global.nxtRGBTest
else
    if { state.status == "halted" || state.status == "off" }
        set var.st = "error"
    elif { state.status == "pausing" || state.status == "paused" || state.status == "resuming" }
        set var.st = "paused"
    elif { state.status == "changingTool" }
        set var.st = "tool"
    elif { global.nxtWS == "probing" }
        set var.st = "probe"
    elif { global.nxtWS == "homing" }
        set var.st = "home"
    elif { state.status == "processing" || state.status == "busy" || state.status == "simulating" }
        set var.st = "run"

    ; Once idle, drop the work-state hint so the next operation starts clean.
    if { state.status == "idle" }
        set global.nxtWS = ""

if { var.st == "error" }
    set var.colIdx = 6
elif { var.st == "paused" }
    set var.colIdx = 5
elif { var.st == "tool" }
    set var.colIdx = 3
elif { var.st == "probe" }
    set var.colIdx = 2
elif { var.st == "home" }
    set var.colIdx = 1
elif { var.st == "run" }
    set var.colIdx = 4
else
    set var.colIdx = 0

; Idle dimming: when idle mode is engaged, dim everything EXCEPT the error state, which must
; always stay fully visible and at full brightness.
var bri = global.nxtRGBBri
if { exists(global.nxtIdleActive) && global.nxtIdleActive && var.st != "error" }
    set var.bri = global.nxtIdleDimBri

; Nothing to do if neither the state NOR the effective brightness has changed since last time.
var lastBri = { (exists(global.nxtRGBLastBri)) ? global.nxtRGBLastBri : -1 }
if { var.st == global.nxtRGBLast && var.bri == var.lastBri }
    M99

; Pick the colour for this state (defaults to idle / index 0).
var col = global.nxtRGBCol[0]
if { var.colIdx >= 0 && var.colIdx < #global.nxtRGBCol }
    set var.col = global.nxtRGBCol[var.colIdx]

; Drive the strip. W is ignored automatically on RGB strips.
if { global.nxtRGBReady }
    M150 E{global.nxtRGBStrip} R{var.col[0]} U{var.col[1]} B{var.col[2]} W{var.col[3]} P{var.bri} S{global.nxtRGBCount} F0

set global.nxtRGBLast = var.st
if { exists(global.nxtRGBLastBri) }
    set global.nxtRGBLastBri = var.bri
