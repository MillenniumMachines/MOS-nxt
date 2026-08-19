; M7601.g: PRINT WORKPLACE DETAILS
;
; Outputs non-null details about the specified WCS.
; If the WCS has been probed, then various values
; will be set in the global variables. We print these
; in a human-readable format if expert mode is off, and
; we print the variables and their actual values if
; expert mode is on.
; WP* besides Deg are allocated lazily (nxt-wp-ensure.g).

if { exists(param.W) && (param.W < 0 || param.W >= limits.workplaces) }
    abort { "Work Offset must be between 0 and " ^ limits.workplaces-1 ^ "!" }

var workOffset = { move.motionSystems[0].workplaceNumber }
if { exists(param.W) && param.W != null }
    set var.workOffset = { param.W }

var wcsNumber = { var.workOffset + 1 }
var nxtHasWP = { exists(global.nxtWPCtrPos) }
var nxtHasCnr = { exists(global.nxtWPCnrNum) }
var nxtHasSfc = { exists(global.nxtWPSfcPos) }
var nxtCnr = { "Front Left", "Front Right", "Back Right", "Back Left" }

if { !global.nxtExpertMode }
    if { var.nxtHasWP }
        if { global.nxtWPCtrPos[var.workOffset][0] != null || global.nxtWPCtrPos[var.workOffset][1] != null }
            echo {"WCS " ^ var.wcsNumber ^ " - Probed Center Position X=" ^ global.nxtWPCtrPos[var.workOffset][0] ^ " Y=" ^ global.nxtWPCtrPos[var.workOffset][1] }
        if { global.nxtWPRad[var.workOffset] != null }
            echo {"WCS " ^ var.wcsNumber ^ " - Probed Radius=" ^ global.nxtWPRad[var.workOffset] }
    if { var.nxtHasCnr }
        if { global.nxtWPCnrNum[var.workOffset] != null }
            echo {"WCS " ^ var.wcsNumber ^ " - Probed Corner Number=" ^ global.nxtWPCnrNum[var.workOffset] }
            var nxtCn = { global.nxtWPCnrNum[var.workOffset] }
            if { var.nxtCn >= 0 && var.nxtCn < 4 }
                echo {"WCS " ^ var.wcsNumber ^ " - Probed Corner Name=" ^ var.nxtCnr[var.nxtCn] }
        if { global.nxtWPCnrPos[var.workOffset][0] != null && global.nxtWPCnrPos[var.workOffset][1] != null }
            echo {"WCS " ^ var.wcsNumber ^ " - Probed Corner Position X=" ^ global.nxtWPCnrPos[var.workOffset][0] ^ " Y=" ^ global.nxtWPCnrPos[var.workOffset][1] }
        if { global.nxtWPCnrDeg[var.workOffset] != null }
            echo {"WCS " ^ var.wcsNumber ^ " - Probed Corner Degrees=" ^ global.nxtWPCnrDeg[var.workOffset] }
    if { var.nxtHasWP }
        if { global.nxtWPDims[var.workOffset][0] != null || global.nxtWPDims[var.workOffset][1] != null }
            echo {"WCS " ^ var.wcsNumber ^ " - Probed Width=" ^ global.nxtWPDims[var.workOffset][0] ^ " Length=" ^ global.nxtWPDims[var.workOffset][1] }
        if { global.nxtWPDimsErr[var.workOffset][0] != null || global.nxtWPDimsErr[var.workOffset][1] != null }
            echo {"WCS " ^ var.wcsNumber ^ " - Probed Width Error=" ^ global.nxtWPDimsErr[var.workOffset][0] ^ " Length Error=" ^ global.nxtWPDimsErr[var.workOffset][1] }
    if { exists(global.nxtWPDeg) }
        if { global.nxtWPDeg[var.workOffset] != null }
            echo {"WCS " ^ var.wcsNumber ^ " - Probed Rotation Degrees=" ^ global.nxtWPDeg[var.workOffset] }
    if { var.nxtHasSfc }
        if { global.nxtWPSfcAxis[var.workOffset] != null }
            echo {"WCS " ^ var.wcsNumber ^ " - Probed Surface Axis=" ^ global.nxtWPSfcAxis[var.workOffset] }
        if { global.nxtWPSfcPos[var.workOffset] != null }
            echo {"WCS " ^ var.wcsNumber ^ " - Probed Surface Position=" ^ global.nxtWPSfcPos[var.workOffset] }
else
    if { var.nxtHasWP }
        if { global.nxtWPCtrPos[var.workOffset][0] != null || global.nxtWPCtrPos[var.workOffset][1] != null }
            echo { "global.nxtWPCtrPos[" ^ var.workOffset ^ "]=" ^ global.nxtWPCtrPos[var.workOffset] }
        if { global.nxtWPRad[var.workOffset] != null }
            echo { "global.nxtWPRad[" ^ var.workOffset ^ "]=" ^ global.nxtWPRad[var.workOffset]}
    if { var.nxtHasCnr }
        if { global.nxtWPCnrNum[var.workOffset] != null }
            echo { "global.nxtWPCnrNum[" ^ var.workOffset ^ "]=" ^ global.nxtWPCnrNum[var.workOffset] }
        if { global.nxtWPCnrPos[var.workOffset][0] != null && global.nxtWPCnrPos[var.workOffset][1] != null }
            echo { "global.nxtWPCnrPos[" ^ var.workOffset ^ "]=" ^ global.nxtWPCnrPos[var.workOffset] }
        if { global.nxtWPCnrDeg[var.workOffset] != null }
            echo { "global.nxtWPCnrDeg[" ^ var.workOffset ^ "]=" ^ global.nxtWPCnrDeg[var.workOffset] }
    if { var.nxtHasWP }
        if { global.nxtWPDims[var.workOffset][0] != null || global.nxtWPDims[var.workOffset][1] != null }
            echo { "global.nxtWPDims[" ^ var.workOffset ^ "]=" ^ global.nxtWPDims[var.workOffset] }
        if { global.nxtWPDimsErr[var.workOffset][0] != null || global.nxtWPDimsErr[var.workOffset][1] != null }
            echo { "global.nxtWPDimsErr[" ^ var.workOffset ^ "]=" ^ global.nxtWPDimsErr[var.workOffset] }
    if { exists(global.nxtWPDeg) }
        if { global.nxtWPDeg[var.workOffset] != null }
            echo { "global.nxtWPDeg[" ^ var.workOffset ^ "]=" ^ global.nxtWPDeg[var.workOffset] }
    if { var.nxtHasSfc }
        if { global.nxtWPSfcAxis[var.workOffset] != null }
            echo { "global.nxtWPSfcAxis[" ^ var.workOffset ^ "]=" ^ global.nxtWPSfcAxis[var.workOffset] }
        if { global.nxtWPSfcPos[var.workOffset] != null }
            echo { "global.nxtWPSfcPos[" ^ var.workOffset ^ "]=" ^ global.nxtWPSfcPos[var.workOffset] }
