; nxt-probe-wcs.g — WCS probing metadata, manual jog distances, probe progress counters.
; Loaded from nxt.g when not already present (e.g. from mos-vars.g on migrated SD cards).

if { exists(global.nxtOvertravel) }
    M99

; Overtravel distance (mm) added to operator estimates during probing cycles.
global nxtOvertravel = 2.0

; Clearance height (mm) for operator prompts and work-zero moves.
global nxtClearance = 10.0

; Manual probing travel speeds (mm/min): [0]=rapid, [1]=coarse jog, [2]=fine jog (G6512.2, workzero).
global nxtManualProbeFeeds = { 1200, 300, 60 }

; Maximum angle (deg) for parallel / perpendicular surface checks.
global nxtProbeAngleTol = 0.2

; Corner / surface name labels for operator dialogs and M7601 reporting.
global nxtCornerNames = {"Front Left", "Front Right", "Back Right", "Back Left"}
global nxtSurfaceNames = {"Left", "Right", "Front", "Back", "Top"}

; WCS probed metadata (per workplace index).
global nxtDfltWPCtrPos = { null, null }
global nxtWPCtrPos = { vector(limits.workplaces, global.nxtDfltWPCtrPos) }
global nxtDfltWPRad = null
global nxtWPRad = { vector(limits.workplaces, global.nxtDfltWPRad) }
global nxtDfltWPDims = { null, null }
global nxtWPDims = { vector(limits.workplaces, global.nxtDfltWPDims) }
global nxtDfltWPDimsErr = { null, null }
global nxtWPDimsErr = { vector(limits.workplaces, global.nxtDfltWPDimsErr) }
global nxtDfltWPDeg = null
global nxtWPDeg = { vector(limits.workplaces, global.nxtDfltWPDeg) }
global nxtDfltWPCnrNum = null
global nxtWPCnrNum = { vector(limits.workplaces, global.nxtDfltWPCnrNum) }
global nxtDfltWPCnrPos = { null, null }
global nxtWPCnrPos = { vector(limits.workplaces, global.nxtDfltWPCnrPos) }
global nxtDfltWPCnrDeg = null
global nxtWPCnrDeg = { vector(limits.workplaces, global.nxtDfltWPCnrDeg) }
global nxtDfltWPSfcPos = null
global nxtWPSfcPos = { vector(limits.workplaces, global.nxtDfltWPSfcPos) }
global nxtDfltWPSfcAxis = null
global nxtWPSfcAxis = { vector(limits.workplaces, global.nxtDfltWPSfcAxis) }

; Manual probing jog distances (G6512.2).
global nxtManualProbeDistNames = {"50mm", "10mm", "5mm", "1mm", "0.1mm", "0.01mm", "Finish", "Back-Off 1mm"}
global nxtManualProbeDistances = { 50, 10, 5, 1, 0.1, 0.01, 0, -1 }
global nxtManualProbeSlowIdx = 3

; Tutorial / cycle dialog shown flags (G6500-jog … G6520-jog, G37.1).
global nxtDialogDisplayed = { vector(14, false) }

; Probe progress counters (UI + M5012 reset).
global nxtProbeRetryStep = 0
global nxtProbeRetryTotal = 0
global nxtProbePointStep = 0
global nxtProbeSurfaceStep = 0
global nxtProbePointTotal = 0
global nxtProbeSurfaceTotal = 0

; Debug logging for probing orchestrators (G6513).
global nxtDebug = false
