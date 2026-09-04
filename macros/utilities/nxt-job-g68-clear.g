; nxt-job-g68-clear.g: cancel workplace G68 and clear job-scoped rotation
;
; Hard clear (no restore): cancel.g, stop.g (not pause), Console M5011,
; M6520 / nxt-wcs-apply after probe. Job tpost/resume restore only while
; nxtJobG68Deg is set.

G69
if { exists(global.nxtJobG68Deg) }
    set global.nxtJobG68Deg = null
if { exists(global.nxtJobG68Wcs) }
    set global.nxtJobG68Wcs = null
echo "nxt-job-g68-clear: G68 cancelled"
