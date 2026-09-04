; nxt-daemon-install.g
; Apply pending 0:/sys/daemon.install → daemon.g (plugin ZIP ships install, not live loop).
; Pause the forever-loop first so RRF can rename an open daemon.g safely.

if { !fileexists("0:/sys/daemon.install") }
    M99

echo "nxt: applying daemon.install"

var nxtDaeWasOn = true
if { exists(global.nxtDaemonEnabled) }
    set var.nxtDaeWasOn = { global.nxtDaemonEnabled }
    set global.nxtDaemonEnabled = false

var nxtDaeWaitMs = 500
if { exists(global.nxtDaemonInterval) && global.nxtDaemonInterval > 0 }
    set var.nxtDaeWaitMs = { global.nxtDaemonInterval * 2 }
G4 P{var.nxtDaeWaitMs}

; Drop previous backup so M471 rename to .old cannot fail on an existing target.
if { fileexists("0:/sys/daemon.g.old") }
    M472 P{"0:/sys/daemon.g.old"}

if { fileexists("0:/sys/daemon.g") }
    M471 S{"0:/sys/daemon.g"} T{"0:/sys/daemon.g.old"}

M471 S{"0:/sys/daemon.install"} T{"0:/sys/daemon.g"}

if { exists(global.nxtDaemonEnabled) }
    set global.nxtDaemonEnabled = { var.nxtDaeWasOn }

echo "nxt: daemon.g updated from daemon.install"
