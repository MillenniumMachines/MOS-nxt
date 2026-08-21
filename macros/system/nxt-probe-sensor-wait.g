; nxt-probe-sensor-wait.g — Poll nxtTouchProbeID until the tip is triggered.
;
; USAGE: M98 P"nxt-probe-sensor-wait.g" [Q1] [D<ms>] [W<s>]
;   Q1: show install OK/Cancel prompt (M98 cannot pass P)
;   D:  poll delay ms (default 100)
;   W:  max wait seconds per phase (default 30)
;
; Sequence: optional prompt → wait inactive if held → wait tip active → wait release.
; Soft-fail only (never abort) — safe when called from tpre tool-change.
; On cancel/fail: set nxtToolChangeCancelled and M99 so tpre can soft-skip.
; Prompts use S4 so Cancel does not abort the T-stack.

; Soft-fail helper: flag + return (caller tpre checks the flag)
var nxtPswFail = false

if { !inputs[state.thisInput].active }
    echo "nxt-probe-sensor-wait: inactive input — soft skip tip check"
    set var.nxtPswFail = true

if { !var.nxtPswFail }
    if { !global.nxtFeatureTouchProbe }
        echo "nxt-probe-sensor-wait: touch probe feature disabled — soft fail"
        set var.nxtPswFail = true

if { !var.nxtPswFail }
    if { global.nxtTouchProbeID == null }
        echo "nxt-probe-sensor-wait: nxtTouchProbeID unset — soft fail"
        set var.nxtPswFail = true

var probeId = 0
if { !var.nxtPswFail }
    set var.probeId = { global.nxtTouchProbeID }
    if { var.probeId < 0 || var.probeId >= #sensors.probes }
        echo "nxt-probe-sensor-wait: nxtTouchProbeID out of range — soft fail"
        set var.nxtPswFail = true

if { !var.nxtPswFail }
    if { sensors.probes[var.probeId] == null }
        echo "nxt-probe-sensor-wait: probe slot null — soft fail"
        set var.nxtPswFail = true

if { !var.nxtPswFail }
    var probeType = { sensors.probes[var.probeId].type }
    if { var.probeType < 5 || var.probeType > 8 }
        echo "nxt-probe-sensor-wait: probe ID not a touch input type — soft fail"
        set var.nxtPswFail = true

if { var.nxtPswFail }
    set global.nxtToolChangeCancelled = true
    M99

var delay = { exists(param.D) ? param.D : 100 }
var maxWait = { exists(param.W) ? param.W : 30 }
if { var.delay < 1 }
    set var.delay = 100
if { var.maxWait < 1 }
    set var.maxWait = 30
var maxIterations = { var.maxWait / (var.delay / 1000) }

var showPrompt = { exists(param.Q) && param.Q == 1 }
if { var.showPrompt }
    var msgInstall = "Install touch probe and ensure it is connected."
    set var.msgInstall = { var.msgInstall ^ " Press OK, then manually trigger the tip until detected." }
    M291 P{var.msgInstall} R"Touch Probe" S4 K{"OK","Cancel"} F0
    if { input != 0 }
        echo "nxt-probe-sensor-wait: cancelled at install prompt"
        set global.nxtToolChangeCancelled = true
        M99

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
            var msgRel = "Touch probe tip is still triggered. Release it, then press OK."
            M291 P{var.msgRel} R"Release Tip" S4 K{"OK","Cancel"} F0
            if { input != 0 }
                echo "nxt-probe-sensor-wait: cancelled at release prompt"
                set global.nxtToolChangeCancelled = true
                M99
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
        set var.msgRetry = { var.msgRetry ^ " Check connection, then OK to retry or Cancel." }
        M291 P{var.msgRetry} R"Touch Probe" S4 K{"OK","Cancel"} F0
        if { input != 0 }
            echo "nxt-probe-sensor-wait: tip not detected — soft cancel"
            set global.nxtToolChangeCancelled = true
            M99
