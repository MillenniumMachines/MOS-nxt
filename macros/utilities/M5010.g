; M5010.g: RESET WCS PROBE DETAILS

if { exists(param.W) && param.W != null && (param.W < 0 || param.W >= limits.workplaces) }
    abort { "Work Offset (W..) must be between 0 and " ^ limits.workplaces-1 ^ "!" }

M98 P"nxt-wp-ensure.g"

; Default workOffset to the current workplace number if not specified
; with the W parameter.
var workOffset = { move.motionSystems[0].workplaceNumber }
if { exists(param.W) && param.W != null }
    set var.workOffset = { param.W }


; WCS Numbers and Offsets are confusing. Work Offset indicates the offset
; from the first work co-ordinate system, so is 0-indexed. WCS number indicates
; the number of the work co-ordinate system, so is 1-indexed.
var wcsNumber = { var.workOffset + 1 }

; Center, Corner, Radius, Surface, Dimensions, Rotation
; 1 2 4 8 16 32

; By default, reset everything
var reset = { exists(param.R) ? param.R : 63 }

; If first bit is set, reset center position
; If second bit is set, reset corner position
; If third bit is set, reset radius
; If fourth bit is set, reset surface position
; If fifth bit is set, reset dimensions
; If sixth bit is set, reset rotation

if { mod(floor(var.reset/pow(2,0)),2) == 1 }
    ; Reset Center
    if { global.nxtTutorialMode }
        echo { "Resetting WCS " ^ var.wcsNumber ^ " probed center"}
    set global.nxtWPCtrPos[var.workOffset] = global.nxtDfltWPCtrPos

if { mod(floor(var.reset/pow(2,1)),2) == 1 }
    ; Reset Corner
    if { global.nxtTutorialMode }
        echo { "Resetting WCS " ^ var.wcsNumber ^ " probed corner"}
    set global.nxtWPCnrPos[var.workOffset] = global.nxtDfltWPCnrPos
    set global.nxtWPCnrDeg[var.workOffset] = global.nxtDfltWPCnrDeg
    set global.nxtWPCnrNum[var.workOffset] = global.nxtDfltWPCnrNum

if { mod(floor(var.reset/pow(2,2)),2) == 1}
    ; Reset Radius
    if { global.nxtTutorialMode }
        echo { "Resetting WCS " ^ var.wcsNumber ^ " probed radius"}
    set global.nxtWPRad[var.workOffset] = global.nxtDfltWPRad

if { mod(floor(var.reset/pow(2,3)),2) == 1 }
    ; Reset Surface
    if { global.nxtTutorialMode }
        echo { "Resetting WCS " ^ var.wcsNumber ^ " probed surface"}
    set global.nxtWPSfcAxis[var.workOffset] = global.nxtDfltWPSfcAxis
    set global.nxtWPSfcPos[var.workOffset] = global.nxtDfltWPSfcPos

if { mod(floor(var.reset/pow(2,4)),2) == 1 }
    ; Reset Dimensions
    if { global.nxtTutorialMode }
        echo { "Resetting WCS " ^ var.wcsNumber ^ " probed dimensions"}
    set global.nxtWPDims[var.workOffset] = global.nxtDfltWPDims
    set global.nxtWPDimsErr[var.workOffset] = global.nxtDfltWPDimsErr

if { mod(floor(var.reset/pow(2,5)),2) == 1 }
    ; Reset Rotation
    if { global.nxtTutorialMode }
        echo { "Resetting WCS " ^ var.wcsNumber ^ " probed rotation"}
    set global.nxtWPDeg[var.workOffset] = global.nxtDfltWPDeg