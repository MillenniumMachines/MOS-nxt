; nxt-mos-globals-align.g
; One-shot: copy legacy MOS global *data* into nxt-named globals when nxt is unset.
; Called from nxt-mos-import.g after mos-vars / mos-user-vars are loaded, and from
; nxt.g after nxt-probe-wcs.g so WCS vectors exist before mosWP* → nxtWP* copies.
; Safe to re-run.
;
; Tool table: nxt-tooltable.g owns mosTT/mosET → nxtTT/nxtET (do not duplicate here).
; Keys always declared in nxt-vars.g (expert/tutorial/RGB/…) are set by nxt-mos-import.g
; or user-vars — not via !exists copies here (those are no-ops after vars).

if { !inputs[state.thisInput].active }
    M99

; --- Probing distances / labels (probe-wcs allocates; overwrite from MOS when both exist) ---
if { exists(global.mosOT) && exists(global.nxtOvertravel) }
    set global.nxtOvertravel = { global.mosOT }
if { exists(global.mosCL) && exists(global.nxtClearance) }
    set global.nxtClearance = { global.mosCL }
if { exists(global.mosMPS) && exists(global.nxtManualProbeFeeds) }
    set global.nxtManualProbeFeeds = { global.mosMPS }
if { exists(global.mosMPDN) && exists(global.nxtManualProbeDistNames) }
    set global.nxtManualProbeDistNames = { global.mosMPDN }
if { exists(global.mosMPD) && exists(global.nxtManualProbeDistances) }
    set global.nxtManualProbeDistances = { global.mosMPD }
if { exists(global.mosMPSI) && exists(global.nxtManualProbeSlowIdx) }
    set global.nxtManualProbeSlowIdx = { global.mosMPSI }
if { exists(global.mosAngleTol) && exists(global.nxtProbeAngleTol) }
    set global.nxtProbeAngleTol = { global.mosAngleTol }
if { exists(global.mosCornerNames) && exists(global.nxtCornerNames) }
    set global.nxtCornerNames = { global.mosCornerNames }
if { exists(global.mosSurfaceNames) && exists(global.nxtSurfaceNames) }
    set global.nxtSurfaceNames = { global.mosSurfaceNames }

; --- WCS probed metadata (overwrite nxt defaults when MOS had data) ---
if { exists(global.mosWPCtrPos) && exists(global.nxtWPCtrPos) }
    set global.nxtWPCtrPos = { global.mosWPCtrPos }
if { exists(global.mosWPRad) && exists(global.nxtWPRad) }
    set global.nxtWPRad = { global.mosWPRad }
if { exists(global.mosWPDims) && exists(global.nxtWPDims) }
    set global.nxtWPDims = { global.mosWPDims }
if { exists(global.mosWPDimsErr) && exists(global.nxtWPDimsErr) }
    set global.nxtWPDimsErr = { global.mosWPDimsErr }
if { exists(global.mosWPDeg) && exists(global.nxtWPDeg) }
    set global.nxtWPDeg = { global.mosWPDeg }
if { exists(global.mosWPCnrNum) && exists(global.nxtWPCnrNum) }
    set global.nxtWPCnrNum = { global.mosWPCnrNum }
if { exists(global.mosWPCnrPos) && exists(global.nxtWPCnrPos) }
    set global.nxtWPCnrPos = { global.mosWPCnrPos }
if { exists(global.mosWPCnrDeg) && exists(global.nxtWPCnrDeg) }
    set global.nxtWPCnrDeg = { global.mosWPCnrDeg }
if { exists(global.mosWPSfcPos) && exists(global.nxtWPSfcPos) }
    set global.nxtWPSfcPos = { global.mosWPSfcPos }
if { exists(global.mosWPSfcAxis) && exists(global.nxtWPSfcAxis) }
    set global.nxtWPSfcAxis = { global.mosWPSfcAxis }

; --- Probe progress counters (session; allocated in nxt-probe-wcs.g) ---
if { exists(global.mosPRRS) && !exists(global.nxtProbeRetryStep) }
    set global.nxtProbeRetryStep = { global.mosPRRS }
if { exists(global.mosPRRT) && !exists(global.nxtProbeRetryTotal) }
    set global.nxtProbeRetryTotal = { global.mosPRRT }
if { exists(global.mosPRPS) && !exists(global.nxtProbePointStep) }
    set global.nxtProbePointStep = { global.mosPRPS }
if { exists(global.mosPRSS) && !exists(global.nxtProbeSurfaceStep) }
    set global.nxtProbeSurfaceStep = { global.mosPRSS }
if { exists(global.mosPRPT) && !exists(global.nxtProbePointTotal) }
    set global.nxtProbePointTotal = { global.mosPRPT }
if { exists(global.mosPRST) && !exists(global.nxtProbeSurfaceTotal) }
    set global.nxtProbeSurfaceTotal = { global.mosPRST }

; --- Tutorial dialog flags (allocated in nxt-probe-wcs.g) ---
if { exists(global.mosDD) && !exists(global.nxtDialogDisplayed) }
    global nxtDialogDisplayed = { global.mosDD }
