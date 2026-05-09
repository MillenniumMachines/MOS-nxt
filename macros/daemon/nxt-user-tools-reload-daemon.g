; nxt-user-tools-reload-daemon.g — Lives under 0:/sys/nxt/ with other NeXT daemon hooks.
; Periodic entry from nxt-daemon.g (see global.nxtUserToolsDaemonReload).
; If 0:/sys/nxt-user-tools.reload.requested exists, deletes it and M98-reloads the persisted library
; so tools[] / mosTT match the file (e.g. after uploading nxt-user-tools.g from DWC).
;
; RepRapFirmware does not expose file mtimes in meta G-code, so "file changed" is signaled by the sentinel.
; Create the sentinel with an empty file on the SD card, or touch it from automation after a save.

if { !inputs[state.thisInput].active }
    M99

if { !exists(global.nxtUserToolsDaemonReload) || !global.nxtUserToolsDaemonReload }
    M99

if { !fileexists("0:/sys/nxt-user-tools.g") }
    M99

if { !fileexists("0:/sys/nxt-user-tools.reload.requested") }
    M99

; Do not reload during an active job / non-idle machine state
if { state.status != "idle" }
    M99

; Do not stack with an in-flight library load (wrapper inside nxt-user-tools.g)
if { exists(global.nxtUserToolsLoadDepth) && global.nxtUserToolsLoadDepth > 0 }
    M99

echo "NeXT: daemon reloading tool library (nxt-user-tools.reload.requested)"
M472 P{"0:/sys/nxt-user-tools.reload.requested"}
M98 P"nxt-user-tools.g"
