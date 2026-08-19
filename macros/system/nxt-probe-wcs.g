; nxt-probe-wcs.g — Probe scalars + nxtWPDeg (M5011). Other WP* via split ensure.
; Loaded from nxt.g when Deg pack is missing (gate on nxtWPDeg — not overtravel).
; Align may set overtravel/clearance from MOS before this runs — use !exists on scalars.
; String catalogs (corners / surfaces / jog names) are local-var, not global (OM ~8KB).

if { exists(global.nxtWPDeg) }
    M99

; Overtravel distance (mm) added to operator estimates during probing cycles.
if { !exists(global.nxtOvertravel) }
    global nxtOvertravel = 2.0

; Clearance height (mm) for operator prompts and work-zero moves.
if { !exists(global.nxtClearance) }
    global nxtClearance = 10.0

; Manual probing travel speeds (mm/min): [0]=rapid, [1]=coarse jog, [2]=fine jog (G6512.2, workzero).
if { !exists(global.nxtManualProbeFeeds) }
    global nxtManualProbeFeeds = { 1200, 300, 60 }

; Maximum angle (deg) for parallel / perpendicular surface checks.
if { !exists(global.nxtProbeAngleTol) }
    global nxtProbeAngleTol = 0.2

; Job-start G68 angle per workplace (M5011). Other WP metadata is nxt-wp-ensure.g.
if { !exists(global.nxtDfltWPDeg) }
    global nxtDfltWPDeg = null
global nxtWPDeg = { vector(limits.workplaces, global.nxtDfltWPDeg) }

; Manual probing jog distances (G6512.2). Names are local in G6512.2 (OM budget).
if { !exists(global.nxtManualProbeDistances) }
    global nxtManualProbeDistances = { 50, 10, 5, 1, 0.1, 0.01, 0, -1 }
if { !exists(global.nxtManualProbeSlowIdx) }
    global nxtManualProbeSlowIdx = 3

; Tutorial / cycle dialog shown flags (G6500-jog … G6520-jog, G37.1).
if { !exists(global.nxtDialogDisplayed) }
    global nxtDialogDisplayed = { vector(14, false) }

; Probe progress counters (UI + M5012 reset).
if { !exists(global.nxtProbeRetryStep) }
    global nxtProbeRetryStep = 0
if { !exists(global.nxtProbeRetryTotal) }
    global nxtProbeRetryTotal = 0
if { !exists(global.nxtProbePointStep) }
    global nxtProbePointStep = 0
if { !exists(global.nxtProbeSurfaceStep) }
    global nxtProbeSurfaceStep = 0
if { !exists(global.nxtProbePointTotal) }
    global nxtProbePointTotal = 0
if { !exists(global.nxtProbeSurfaceTotal) }
    global nxtProbeSurfaceTotal = 0

; Debug logging for probing orchestrators (G6513).
if { !exists(global.nxtDebug) }
    global nxtDebug = false
