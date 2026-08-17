; daemon.g - Run daemon tasks

while { exists(global.nxtDaemonEnabled) && global.nxtDaemonEnabled }
    G4 P{global.nxtDaemonInterval} ; Minimum interval between daemon runs

    ; ArborCTL spindle polling runs via nxt-plugin-daemon-dispatch.g when the
    ; ArborCTL ZIP is installed (data.nxt entrypoint arborctl-daemon-hook.g).
    ; Do not call arborctl-daemon.g here — that would double-poll.

    if { fileexists("0:/sys/nxt/nxt-daemon.g") }
        M98 P"nxt/nxt-daemon.g" ; nxt specific daemon tasks (includes catalog plugins)

    if { fileexists("0:/sys/user-daemon.g") }
        M98 P"user-daemon.g"
