; G6600.g: WORKPIECE PROBING GATEWAY (CAM post-processor)
;
; Pauses CAM setup for operator WCS probing. W is 0-indexed (W0=G54). Omit W = current workplace.
; Primary workflow: DWC nxt Probing Cycles panel. On-machine: vise corner quick path or skip.
;
; USAGE: G6600 [W<0..8>]

if { !inputs[state.thisInput].active }
    M99

if { !global.nxtFeatureTouchProbe }
    abort { "G6600: Touch probe feature not enabled" }

if { global.nxtTouchProbeID == null }
    abort { "G6600: nxtTouchProbeID not configured" }

G27 Z1

var wcsNum = { move.workplaceNumber + 1 }
if { exists(param.W) && param.W != null }
    if { param.W < 0 || param.W > 8 }
        abort { "G6600: W must be 0-8 (G54..G59.3)" }
    set var.wcsNum = { param.W + 1 }

var wcsG = { 53 + var.wcsNum }
echo "G6600: Workpiece probing for WCS G" ^ var.wcsG

M98 P"nxt-probe-tool-ready.g"

var menuMsg = { "Probe WCS G" ^ var.wcsG ^ ". Vise corner runs G6520 here; bore/rectangle use DWC Probing Cycles." }
M291 P{var.menuMsg} R"Workpiece probe" S4 K{"Vise corner","DWC panel done","Skip","Cancel"} F0
if { input == 3 }
    abort { "G6600: Workpiece probing cancelled" }
if { input == 2 }
    echo "G6600: Skipped — ensure WCS G" ^ var.wcsG ^ " is set before cutting"
    M99
if { input == 1 }
    echo "G6600: Continuing after DWC probing"
    M99

var depth = 10.0
var pSlot = { var.wcsNum - 1 }
echo "G6600: Running G6520 vise corner U" ^ var.wcsNum ^ " L" ^ var.depth
G6520 U{var.wcsNum} L{var.depth} P{var.pSlot}

echo "G6600: WCS G" ^ var.wcsG ^ " probing complete"
