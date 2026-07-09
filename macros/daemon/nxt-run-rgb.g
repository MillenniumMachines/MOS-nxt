; nxt-run-rgb.g
;
; nxt RGB status renderer. Called from the daemon a few times a
; second. Turns the current machine state into a colour and drives the LED
; strip. Only touches the strip when the state actually changes, so it never
; floods the command queue.

; Create the LED strip once, the first time we run with a pin configured.
if { !global.nxtRGBReady && global.nxtRGBPin != null }
    M950 E{global.nxtRGBStrip} C{global.nxtRGBPin} T{global.nxtRGBType} U{global.nxtRGBCount}
    set global.nxtRGBReady = true

; Work out the effective state, highest priority first:
; error > paused > tool change > probing > homing > running > idle.
var st = "idle"

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

; Idle dimming: when idle mode is engaged, dim everything EXCEPT the error state, which must
; always stay fully visible and at full brightness.
var bri = global.nxtRGBBri
if { exists(global.nxtIdleActive) && global.nxtIdleActive && var.st != "error" }
    set var.bri = global.nxtIdleDimBri

; Nothing to do if neither the state NOR the effective brightness has changed since last time.
var lastBri = { (exists(global.nxtRGBLastBri)) ? global.nxtRGBLastBri : -1 }
if { var.st == global.nxtRGBLast && var.bri == var.lastBri }
    M99

; Pick the colour for this state (defaults to idle).
var col = global.nxtRGBIdle
if { var.st == "error" }
    set var.col = global.nxtRGBErr
elif { var.st == "paused" }
    set var.col = global.nxtRGBPause
elif { var.st == "tool" }
    set var.col = global.nxtRGBTool
elif { var.st == "probe" }
    set var.col = global.nxtRGBProbe
elif { var.st == "home" }
    set var.col = global.nxtRGBHome
elif { var.st == "run" }
    set var.col = global.nxtRGBRun

; Drive the strip. W is ignored automatically on RGB strips.
if { global.nxtRGBReady }
    M150 E{global.nxtRGBStrip} R{var.col[0]} U{var.col[1]} B{var.col[2]} W{var.col[3]} P{var.bri} S{global.nxtRGBCount} F0

set global.nxtRGBLast = var.st
if { exists(global.nxtRGBLastBri) }
    set global.nxtRGBLastBri = var.bri
