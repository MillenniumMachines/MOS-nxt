; daemon.g - Run daemon tasks

while { exists(global.nxtDaemonEnabled) && global.nxtDaemonEnabled }
    G4 P{global.nxtDaemonInterval} ; Minimum interval between daemon runs

    if { fileexists("0:/sys/arborctl/arborctl-daemon.g") }
        M98 P"arborctl/arborctl-daemon.g" ; Control spindle using ArborCTL

    if { fileexists("0:/sys/nxt/nxt-daemon.g") }
        M98 P"nxt/nxt-daemon.g" ; NeXT specific daemon tasks

    if { fileexists("0:/sys/user-daemon.g") }
        M98 P"user-daemon.g"
