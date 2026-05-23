; nxt-vars.g
; Defines default global variables for the NeXT system.
;
; Vector globals use the same RHS form as MillenniumOS (sys/mos-vars.g): { vector(...) }.
; RRF 3.5.0+. See macros/system/RRF_META.txt. Caps: tool cache 50, gpOut snapshot 32 (MOS uses full limits.gpOutPorts).

; --- Features ---
global nxtFeatureTouchProbe = false
global nxtFeatureToolSetter = false
global nxtFeatureCoolantControl = false ; Coolant Control feature flag

; --- Core Settings ---
global nxtProbeToolID = { limits.tools - 1 } ; Probe Tool ID, always the last tool
global nxtTouchProbeID = 0             ; The ID of the touch probe sensor
global nxtToolSetterID = 1             ; The ID of the tool setter sensor
global nxtError = null               ; Stores the last error message
global nxtLoaded = false              ; Tracks if NeXT has loaded successfully
global nxtUserVarsPresent = false     ; true after nxt-user-vars.g is loaded from SD (set in nxt.g)
global nxtConfigPending = false       ; true when nxt-user-vars.g missing — use DWC Configuration + Save

; --- Tooling & Probing ---
global nxtDeltaMachine = null      ; The static Z distance between the toolsetter and reference surface
global nxtProbeResults = { vector(10, null) } ; Last 10 probe results (rows sized at runtime to #move.axes+1)
global nxtToolCache = { vector(min(limits.tools, 50), null) } ; Per-tool cache (max 50 slots)
global nxtLastProbeResult = null   ; Stores the result of the last probing operation
global nxtProbeTipRadius = 0.0    ; Radius of the probe tip for compensation (mm)
global nxtProbeDeflection = 0.0   ; Probe deflection compensation value (mm)
global nxtProbeHitXY = { vector(8, 0.0) } ; Last contacts as X,Y pairs (G6512 H0..H3), machine mm — bore/boss use H0..H2
global nxtProbeMaxSkewDeg = 5.0   ; Abort rectangle/bore skew solve if |theta| exceeds this (deg)

; --- Probe repeatability (G6512; all canned cycles use G6512) ---
; Defaults below. Plugin installs 0:/sys/nxt-user-overrides.g.example on SD; copy to nxt-user-overrides.g
; to enable (nxt.g loads only nxt-user-overrides.g, last in the boot sequence). Not in Configuration UI.
;   nxtProbeInnerSampleCount — inner sample count when tolerance disabled (limit = 0); ignored when limit > 0 (G6512 uses 3 touches).
;   nxtProbeMaxSampleSpreadMm — max consecutive-pair deviation (mm) between the 3 touches; both pairs must pass. Set 0 to disable.
;   nxtProbeSampleOuterRetries — how many *additional* full 3-touch blocks after a failed tolerance check
;                                (total cycles = 1 + this). 1 = one retry after the first attempt.
global nxtProbeInnerSampleCount = 3
global nxtProbeMaxSampleSpreadMm = 0.0075
global nxtProbeSampleOuterRetries = 1

global nxtToolSetterPos = null     ; Toolsetter position vector [X, Y, Z]
global nxtToolChangeState = null   ; Tracks the current tool change state (1=tfree, 2=tfree done, 3=tpre done, 4=tpost, null=complete)
global nxtUserToolsFilePresent = false     ; set at boot by nxt.g: nxt-user-tools.g exists on SD
global nxtUserToolsDaemonReload = false      ; if true, daemon reloads library when 0:/sys/nxt-user-tools.reload.requested exists (see TOOLCHANGING.md)

; --- Coolant Control ---
global nxtCoolantAirID = null ; Coolant Air Output Pin ID
global nxtCoolantMistID = null ; Coolant Mist Output Pin ID
global nxtCoolantFloodID = null ; Coolant Flood Output Pin ID
global nxtPinStates = { vector(min(limits.gpOutPorts, 32), 0.0) } ; gpOut PWM snapshot; pause.g uses min(#gpOut, #nxtPinStates)

; --- Spindle Control ---
global nxtSpindleID = null  ; Default Spindle ID
global nxtSpindleAccelSec = null  ; Spindle Acceleration Time (seconds)
global nxtSpindleDecelSec = null  ; Spindle Deceleration Time (seconds)

; --- Canned drilling cycles (G81, G73, G83, …) ---
; When non-null, nxtCannedCycle is a vector:
; [0]=kind (81,73,83,82,85,89), [1]=Z, [2]=R, [3]=Q or null, [4]=F, [5]=seriesInitZ (G98), [6]=retractMode (98|99), [7]=P dwell s or null
global nxtCannedCycle = null
global nxtCannedRetractMode = 98   ; G98 initial plane / G99 R plane — set by G98.g / G99.g
global nxtCannedZi = 0              ; scratch: Z axis index (set by nxt-canned-zindex.g)

; --- Board / platform selection (UI + pack loader) ---
global nxtPlatformProfile = null   ; platform id = nxt-config/<id>/ directory name
global nxtBoardKitKey = null       ; legacy UI key; optional — prefer shortName + nxtBoardMotorVoltage
global nxtBoardShortNameOverride = null ; RRF boards[0].shortName override for pack resolution, or null
global nxtBoardMotorVoltage = null ; 24 | 48 | null (motor-24v / motor-48v board packs)
global nxtScyllaMotorVoltage = null ; deprecated — use nxtBoardMotorVoltage
global nxtBoardPackEntry = null    ; last resolved entry path at boot (telemetry)
global nxtBoardPackShortName = null ; board shortName during pack load (machine endstop-y.g)
global nxtBoardPackExpectedEntry = null ; saved expected entry path (Configuration Save)
global nxtBoardSysDeployPlatform = null ; platform whose home*.g were last deployed to 0:/sys/
global nxtBoardBootstrapMode = "off" ; "off" | "auto" (Save syncs nxt-board-bootstrap.requested)

; --- Optional magazine / ATC extension (not allocated here) ---
; Bay maps, job sequence vectors, and related globals are defined only when a tool changer
; macro pack is installed on the machine. Base NeXT does not create atc*. globals mosET and
; mosTT are allocated by nxt-tooltable.g (invoked from nxt.g) when not already present from
; mos-vars.g, and maintained by M4000/M4001 for post-driven tool definitions.
; See docs/TOOLCHANGING.md and ui/src/utils/nxtToolChangerOm.ts (OM key map).
