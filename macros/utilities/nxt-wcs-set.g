; nxt-wcs-set.g: SET WCS ORIGIN FROM UI (NO TRAVEL)
;
; G10 L2 only (never L20). No G0, G69, nxtWPDeg, or WCS select.
; Axis letters are millimetre values (omit unchanged axes).
;
; USAGE: M98 P"nxt-wcs-set.g" W<wcsNumber> [X<mm>] [Y<mm>] [Z<mm>] [A<mm>]
;
; Parameters:
;   W: WCS number (1-9 for G54-G59.3) — REQUIRED
;   X/Y/Z/A: Origin values to set (omit to leave that axis unchanged)

if { !inputs[state.thisInput].active }
    M99

if { !exists(param.W) || param.W == null || param.W < 1 || param.W > 9 }
    abort { "nxt-wcs-set: W must be 1-9 (G54-G59.3)" }

if { !exists(param.X) && !exists(param.Y) && !exists(param.Z) && !exists(param.A) }
    abort { "nxt-wcs-set: At least one axis value (X, Y, Z, or A) required" }

var wcsNumber = { param.W }

M400

if { exists(param.X) && param.X != null }
    G10 L2 P{var.wcsNumber} X{param.X}
if { exists(param.Y) && param.Y != null }
    G10 L2 P{var.wcsNumber} Y{param.Y}
if { exists(param.Z) && param.Z != null }
    G10 L2 P{var.wcsNumber} Z{param.Z}
if { exists(param.A) && param.A != null }
    G10 L2 P{var.wcsNumber} A{param.A}

echo "nxt-wcs-set: Set WCS" ^ var.wcsNumber ^ " origin (G10 L2, no travel)"
if { exists(param.X) && param.X != null }
    echo "nxt-wcs-set:   X origin = " ^ param.X
if { exists(param.Y) && param.Y != null }
    echo "nxt-wcs-set:   Y origin = " ^ param.Y
if { exists(param.Z) && param.Z != null }
    echo "nxt-wcs-set:   Z origin = " ^ param.Z
if { exists(param.A) && param.A != null }
    echo "nxt-wcs-set:   A origin = " ^ param.A

; Persist G10 L2 origins to SD (opt-out: set global.nxtAutoPersistWcs = false)
M98 P"nxt-user-wcs-sync.g"
