; nxt-wcs-clear.g: ZERO WCS ORIGIN AND PROBE METADATA
;
; G10 L2 zeros X/Y/Z (and A when present). Then M5010 (0-indexed W).
; Does not clear nxtProbeResults. No travel, G69, or WCS select.
;
; USAGE: M98 P"nxt-wcs-clear.g" W<wcsNumber>
;
; Parameters:
;   W: WCS number (1-9 for G54-G59.3) — REQUIRED
;      M5010 W is 0-indexed (this file passes W-1)

if { !inputs[state.thisInput].active }
    M99

if { !exists(param.W) || param.W == null || param.W < 1 || param.W > 9 }
    abort { "nxt-wcs-clear: W must be 1-9 (G54-G59.3)" }

var wcsNumber = { param.W }
var workOffset = { var.wcsNumber - 1 }

var nxtHasA = false
var axi = 0
while { var.axi < #move.axes }
    if { move.axes[var.axi].letter == "A" }
        set var.nxtHasA = true
    set var.axi = { var.axi + 1 }

M400

if { var.nxtHasA }
    G10 L2 P{var.wcsNumber} X0 Y0 Z0 A0
else
    G10 L2 P{var.wcsNumber} X0 Y0 Z0

M5010 W{var.workOffset}

echo "nxt-wcs-clear: Cleared WCS" ^ var.wcsNumber ^ " origins and probe details"

; Persist G10 L2 origins to SD (opt-out: set global.nxtAutoPersistWcs = false)
M98 P"nxt-user-wcs-sync.g"
