; M6525.g — Prepare for / finish plugin update (daemon pause)
;
; USAGE:
;   M6525       Pause daemon (nxtDaemonEnabled=false), wait 2 intervals, leave paused
;   M6525 S1    Apply pending daemon.install if any, then re-enable daemon
;
; Use M6525 before DWC plugin ZIP upgrade when the installed build still lists
; sd/sys/daemon.g (DSF uninstall must delete the open forever-loop file).
; After this release, routine upgrades only touch daemon.install and usually
; do not need a pause; S1 (or reboot / M98 nxt.g) applies a pending install.

if { !inputs[state.thisInput].active }
    M99

var nxtResume = false
if { exists(param.S) && param.S == 1 }
    set var.nxtResume = true

if { var.nxtResume }
    if { fileexists("0:/sys/daemon.install") }
        M98 P"nxt-daemon-install.g"
    if { exists(global.nxtDaemonEnabled) }
        set global.nxtDaemonEnabled = true
    else
        global nxtDaemonEnabled = true
    echo "nxt: M6525 daemon resumed (S1)"
    M99

; Pause path — close forever-loop so DSF can delete/replace listed daemon.g
if { !exists(global.nxtDaemonEnabled) }
    global nxtDaemonEnabled = false
else
    set global.nxtDaemonEnabled = false

var nxtDaeWaitMs = 500
if { exists(global.nxtDaemonInterval) && global.nxtDaemonInterval > 0 }
    set var.nxtDaeWaitMs = { global.nxtDaemonInterval * 2 }
G4 P{var.nxtDaeWaitMs}

echo "nxt: M6525 daemon paused — safe to install/update the nxt plugin ZIP"
echo "nxt: after update, reboot or run M6525 S1 to resume / apply daemon.install"
