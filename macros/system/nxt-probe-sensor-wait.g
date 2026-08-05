; nxt-probe-sensor-wait.g — Poll nxtTouchProbeID until the tip is triggered.
;
; USAGE: M98 P"nxt-probe-sensor-wait.g" [P1] [D<ms>] [W<s>]
;   P1: show install Continue/Cancel prompt (standalone callers)
;   D:  poll delay ms (default 100)
;   W:  max wait seconds per phase (default 30)
;
; Sequence: optional prompt → wait inactive if held → wait tip active → wait release.
; Abort on Cancel; Retry restarts after a timed-out phase.

if { !inputs[state.thisInput].active }
    M99

if { !global.nxtFeatureTouchProbe }
    abort { "nxt-probe-sensor-wait: Touch probe feature not enabled" }

if { global.nxtTouchProbeID == null }
    abort { "nxt-probe-sensor-wait: nxtTouchProbeID not configured" }

var probeId = { global.nxtTouchProbeID }
if { var.probeId < 0 || var.probeId >= #sensors.probes }
    abort { "nxt-probe-sensor-wait: nxtTouchProbeID out of range" }
if { sensors.probes[var.probeId] == null }
    abort { "nxt-probe-sensor-wait: probe slot is null" }

var probeType = { sensors.probes[var.probeId].type }
if { var.probeType < 5 || var.probeType > 8 }
    abort { "nxt-probe-sensor-wait: probe ID is not a touch/probe input type" }

var delay = { exists(param.D) ? param.D : 100 }
var maxWait = { exists(param.W) ? param.W : 30 }
if { var.delay < 1 }
    set var.delay = 100
if { var.maxWait < 1 }
    set var.maxWait = 30
var maxIterations = { var.maxWait / (var.delay / 1000) }

var showPrompt = { exists(param.P) && param.P == 1 }
if { var.showPrompt }
    var msgInstall = "Install touch probe and ensure it is connected."
    set var.msgInstall = { var.msgInstall ^ " Press Continue, then manually trigger the tip until detected." }
    M291 P{var.msgInstall} R"Touch Probe" S4 K{"Continue", "Cancel"}
    if { input != 0 }
        abort { "nxt-probe-sensor-wait: Touch probe check cancelled" }

var confirmed = false
while { !var.confirmed }
    var thr = { sensors.probes[var.probeId].threshold }
    var phaseOk = true

    ; If tip already active, require release first so a stuck line cannot auto-pass.
    var val0 = { sensors.probes[var.probeId].value[0] }
    if { var.val0 >= var.thr }
        echo "nxt-probe-sensor-wait: Tip held — release, then trigger again"
        var released = false
        while { iterations < var.maxIterations && !var.released }
            G4 P{var.delay}
            set var.val0 = { sensors.probes[var.probeId].value[0] }
            if { var.val0 < var.thr }
                set var.released = true
        if { !var.released }
            set var.phaseOk = false

    if { var.phaseOk }
        echo "nxt-probe-sensor-wait: Waiting for tip trigger (ID " ^ var.probeId ^ ")..."
        var triggered = false
        while { iterations < var.maxIterations && !var.triggered }
            G4 P{var.delay}
            set var.val0 = { sensors.probes[var.probeId].value[0] }
            if { var.val0 >= var.thr }
                set var.triggered = true
        if { !var.triggered }
            set var.phaseOk = false

    ; After a successful trigger, wait for release so G6511 does not start held.
    if { var.phaseOk }
        echo "nxt-probe-sensor-wait: Tip detected — release to continue"
        var released2 = false
        while { iterations < var.maxIterations && !var.released2 }
            G4 P{var.delay}
            set var.val0 = { sensors.probes[var.probeId].value[0] }
            if { var.val0 < var.thr }
                set var.released2 = true
        if { !var.released2 }
            var msgRel = "Touch probe tip is still triggered. Release it, then press Continue."
            M291 P{var.msgRel} R"Release Tip" S4 K{"Continue", "Cancel"}
            if { input != 0 }
                abort { "nxt-probe-sensor-wait: Touch probe check cancelled" }
            set var.val0 = { sensors.probes[var.probeId].value[0] }
            if { var.val0 >= var.thr }
                set var.phaseOk = false
            else
                set var.released2 = true

    if { var.phaseOk }
        set var.confirmed = true
        echo "nxt-probe-sensor-wait: Touch probe tip confirmed"
    else
        var msgRetry = "Did not detect touch probe tip trigger on ID " ^ var.probeId ^ "."
        set var.msgRetry = { var.msgRetry ^ " Check connection, then Retry or Cancel." }
        M291 P{var.msgRetry} R"Touch Probe" S4 K{"Retry", "Cancel"}
        if { input != 0 }
            abort { "nxt-probe-sensor-wait: Touch probe not detected" }
