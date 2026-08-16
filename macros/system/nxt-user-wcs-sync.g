; nxt-user-wcs-sync.g — Rewrite 0:/sys/nxt-user-wcs.g from live workplaceOffsets.
; Invoked from M6520 / nxt-wcs-apply / nxt-wcs-set / nxt-wcs-clear when
; auto-persistence is enabled (see global nxtAutoPersistWcs).
; File is G10 L2 + WCS select only.

if { !inputs[state.thisInput].active }
    M99

if { exists(global.nxtAutoPersistWcs) && !global.nxtAutoPersistWcs }
    M99

if { #move.axes < 1 }
    M99

var WP = "0:/sys/nxt-user-wcs.g"

echo >{var.WP} {"; nxt user workplaces (persisted)"}
echo >>{var.WP} {"; Maintained by nxt-user-wcs-sync.g after apply / UI set / clear."}
echo >>{var.WP} {"; Boot: nxt.g M98-loads this file after the board pack (G10 L2 only)."}
echo >>{var.WP} {"; G68 / probe results are session-only and are not written here."}
echo >>{var.WP} {""}

var w = 0
while { var.w < limits.workplaces }
    var pNum = { var.w + 1 }
    var line = {"G10 L2 P" ^ var.pNum}
    var anyOff = false
    var axi = 0
    while { var.axi < #move.axes }
        var off = null
        var nOff = { #move.axes[var.axi].workplaceOffsets }
        if { var.w < var.nOff }
            set var.off = { move.axes[var.axi].workplaceOffsets[var.w] }
        if { var.off != null }
            set var.line = { var.line ^ " " ^ move.axes[var.axi].letter ^ var.off }
            set var.anyOff = true
        set var.axi = { var.axi + 1 }
    if { var.anyOff }
        echo >>{var.WP} {var.line}
    set var.w = { var.w + 1 }

echo >>{var.WP} {""}

; Re-select the workplace that was active when we dumped.
var nxtWpIdx = 0
var nxtHasSys = false
if { exists(move.motionSystems) }
    if { #move.motionSystems > 0 }
        set var.nxtHasSys = true
if { var.nxtHasSys }
    set var.nxtWpIdx = { move.motionSystems[0].workplaceNumber }

var nxtWpSel = { var.nxtWpIdx + 1 }
if { var.nxtWpSel < 1 }
    set var.nxtWpSel = 1
if { var.nxtWpSel > 9 }
    set var.nxtWpSel = 9

echo >>{var.WP} {"M98 P""nxt-select-wcs.g"" W" ^ var.nxtWpSel}
echo "nxt-user-wcs-sync: wrote workplaces to " ^ var.WP
