; nxt-probe-wcs.g — WCS probing metadata, manual jog distances, probe progress counters.
; Loaded from nxt.g when WP pack is missing (gate on nxtWPCtrPos — not overtravel).
; Align may set overtravel/clearance from MOS before this runs — use !exists on scalars.

if { exists(global.nxtWPCtrPos) }
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

; Corner / surface name labels for operator dialogs and M7601 reporting.
if { !exists(global.nxtCornerNames) }
    global nxtCornerNames = {"Front Left", "Front Right", "Back Right", "Back Left"}
if { !exists(global.nxtSurfaceNames) }
    global nxtSurfaceNames = {"Left", "Right", "Front", "Back", "Top"}

; WCS probed metadata (per workplace index).
if { !exists(global.nxtDfltWPCtrPos) }
    global nxtDfltWPCtrPos = { null, null }
global nxtWPCtrPos = { vector(limits.workplaces, global.nxtDfltWPCtrPos) }
if { !exists(global.nxtDfltWPRad) }
    global nxtDfltWPRad = null
global nxtWPRad = { vector(limits.workplaces, global.nxtDfltWPRad) }
if { !exists(global.nxtDfltWPDims) }
    global nxtDfltWPDims = { null, null }
global nxtWPDims = { vector(limits.workplaces, global.nxtDfltWPDims) }
if { !exists(global.nxtDfltWPDimsErr) }
    global nxtDfltWPDimsErr = { null, null }
global nxtWPDimsErr = { vector(limits.workplaces, global.nxtDfltWPDimsErr) }
if { !exists(global.nxtDfltWPDeg) }
    global nxtDfltWPDeg = null
global nxtWPDeg = { vector(limits.workplaces, global.nxtDfltWPDeg) }
if { !exists(global.nxtDfltWPCnrNum) }
    global nxtDfltWPCnrNum = null
global nxtWPCnrNum = { vector(limits.workplaces, global.nxtDfltWPCnrNum) }
if { !exists(global.nxtDfltWPCnrPos) }
    global nxtDfltWPCnrPos = { null, null }
global nxtWPCnrPos = { vector(limits.workplaces, global.nxtDfltWPCnrPos) }
if { !exists(global.nxtDfltWPCnrDeg) }
    global nxtDfltWPCnrDeg = null
global nxtWPCnrDeg = { vector(limits.workplaces, global.nxtDfltWPCnrDeg) }
if { !exists(global.nxtDfltWPSfcPos) }
    global nxtDfltWPSfcPos = null
global nxtWPSfcPos = { vector(limits.workplaces, global.nxtDfltWPSfcPos) }
if { !exists(global.nxtDfltWPSfcAxis) }
    global nxtDfltWPSfcAxis = null
global nxtWPSfcAxis = { vector(limits.workplaces, global.nxtDfltWPSfcAxis) }

; Manual probing jog distances (G6512.2).
if { !exists(global.nxtManualProbeDistNames) }
    global nxtManualProbeDistNames = {"50mm", "10mm", "5mm", "1mm", "0.1mm", "0.01mm", "Finish", "Back-Off 1mm"}
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
