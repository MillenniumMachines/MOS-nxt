; nxt-job-g68-restore.g: re-apply job-scoped G68 after a temporary G69
;
; Used by tpost after toolsetter / reference probing, and by resume.g if needed.
; No-op when nxtJobG68Deg is null (no running job owns rotation).

if { !exists(global.nxtJobG68Deg) || global.nxtJobG68Deg == null }
    M99

var thetaDeg = { global.nxtJobG68Deg }
var wcsNumber = { 1 }
if { exists(global.nxtJobG68Wcs) && global.nxtJobG68Wcs != null }
    set var.wcsNumber = { global.nxtJobG68Wcs }
elif { exists(move.motionSystems) }
    if { #move.motionSystems > 0 }
        set var.wcsNumber = { move.motionSystems[0].workplaceNumber + 1 }

M98 P"nxt-job-g68-apply.g" R{var.thetaDeg} W{var.wcsNumber}
echo "nxt-job-g68-restore: G68 R" ^ var.thetaDeg ^ " on G" ^ (53 + var.wcsNumber)
