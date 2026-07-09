; nxt-probe-wcs.g — WCS probing metadata, manual jog distances, probe progress counters.
; Loaded from nxt.g when not already present (e.g. from mos-vars.g on migrated SD cards).

if { exists(global.mosOT) }
    M99

; Overtravel distance (mm) added to operator estimates during probing cycles.
global mosOT = 2.0

; Clearance height (mm) for operator prompts and work-zero moves.
global mosCL = 10.0

; Manual probing travel speeds (mm/min): [0]=rapid, [1]=coarse jog, [2]=fine jog (G6512.2, workzero).
global mosMPS = { 1200, 300, 60 }

; Corner name labels for M7601 reporting.
global mosCornerNames = {"Front Left", "Front Right", "Back Right", "Back Left"}

; WCS probed metadata (per workplace index).
global mosDfltWPCtrPos = { null, null }
global mosWPCtrPos = { vector(limits.workplaces, global.mosDfltWPCtrPos) }
global mosDfltWPRad = null
global mosWPRad = { vector(limits.workplaces, global.mosDfltWPRad) }
global mosDfltWPDims = { null, null }
global mosWPDims = { vector(limits.workplaces, global.mosDfltWPDims) }
global mosDfltWPDimsErr = { null, null }
global mosWPDimsErr = { vector(limits.workplaces, global.mosDfltWPDimsErr) }
global mosDfltWPDeg = null
global mosWPDeg = { vector(limits.workplaces, global.mosDfltWPDeg) }
global mosDfltWPCnrNum = null
global mosWPCnrNum = { vector(limits.workplaces, global.mosDfltWPCnrNum) }
global mosDfltWPCnrPos = { null, null }
global mosWPCnrPos = { vector(limits.workplaces, global.mosDfltWPCnrPos) }
global mosDfltWPCnrDeg = null
global mosWPCnrDeg = { vector(limits.workplaces, global.mosDfltWPCnrDeg) }
global mosDfltWPSfcPos = null
global mosWPSfcPos = { vector(limits.workplaces, global.mosDfltWPSfcPos) }
global mosDfltWPSfcAxis = null
global mosWPSfcAxis = { vector(limits.workplaces, global.mosDfltWPSfcAxis) }

; Manual probing jog distances (G6512.2).
global mosMPDN = {"50mm", "10mm", "5mm", "1mm", "0.1mm", "0.01mm", "Finish", "Back-Off 1mm"}
global mosMPD = { 50, 10, 5, 1, 0.1, 0.01, 0, -1 }
global mosMPSI = 3

; Probe progress counters (UI + M5012 reset).
global mosPRRS = 0
global mosPRRT = 0
global mosPRPS = 0
global mosPRSS = 0
global mosPRPT = 0
global mosPRST = 0
