; nxt-wcs-z-from-hit.g: tip M5000 Z hit → G10 L2 Z (tool-normalized)
;
; Legacy MOS G37.1 / G6510.1 wrote raw mosMI[2] to G10 L2 (see docs/DETAILS.md).
; nxt: L2 = hitZ − tools[].offsets[2] (L1 vs nxtProbeVirtualTsZ / probe datum).
; Shorter tool → negative L1; longer → positive. Probe L1 = 0 → identity.
;
; Caller sets global.nxtWcsHitZ before M98. Writes global.nxtWcsNormZ.

if { !inputs[state.thisInput].active }
    M99

if { !exists(global.nxtWcsHitZ) || global.nxtWcsHitZ == null }
    abort { "nxt-wcs-z-from-hit: set global.nxtWcsHitZ before M98" }

if { !exists(global.nxtWcsNormZ) }
    global nxtWcsNormZ = null

var hitZ = { global.nxtWcsHitZ }
var toolZ = { 0 }
if { state.currentTool >= 0 }
    if { state.currentTool < #tools }
        if { tools[state.currentTool] != null }
            set var.toolZ = { tools[state.currentTool].offsets[2] }

set global.nxtWcsNormZ = { var.hitZ - var.toolZ }

echo "nxt-wcs-z-from-hit: tip hit Z=" ^ var.hitZ ^ " L1 Z=" ^ var.toolZ
echo "nxt-wcs-z-from-hit: G10 L2 Z=" ^ global.nxtWcsNormZ
