; nxt-job-g68-clear.g: cancel workplace G68 and clear job-scoped rotation
;
; Call from cancel.g and from stop.g when the job is truly ending (not pause).

G69
if { exists(global.nxtJobG68Deg) }
    set global.nxtJobG68Deg = null
if { exists(global.nxtJobG68Wcs) }
    set global.nxtJobG68Wcs = null
echo "nxt-job-g68-clear: G68 cancelled"
