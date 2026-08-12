; nxt-job-g68-restore.g: re-apply job-scoped G68 after a temporary G69
;
; Used by tpost after toolsetter / reference probing, and by resume.g if needed.
; No-op when nxtJobG68Deg is null.

if { !exists(global.nxtJobG68Deg) || global.nxtJobG68Deg == null }
    M99

var thetaDeg = { global.nxtJobG68Deg }
var wcsNumber = { exists(global.nxtJobG68Wcs) && global.nxtJobG68Wcs != null ? global.nxtJobG68Wcs : move.motionSystems[0].workplaceNumber + 1 }

G17
G69
M98 P"nxt-select-wcs.g" W{var.wcsNumber}
G68 X0 Y0 R{var.thetaDeg}
echo "nxt-job-g68-restore: G68 R" ^ var.thetaDeg ^ " on G" ^ (53 + var.wcsNumber)
