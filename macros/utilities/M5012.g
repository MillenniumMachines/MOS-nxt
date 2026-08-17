; M5012.g: RESET PROBE COUNTS
;

; Called when completing a probing sequence, resets
; the probe count totals and current values to 0.
set global.nxtProbeRetryTotal=0
set global.nxtProbeRetryStep=0
set global.nxtProbePointTotal=0
set global.nxtProbePointStep=0
set global.nxtProbeSurfaceTotal=0
set global.nxtProbeSurfaceStep=0