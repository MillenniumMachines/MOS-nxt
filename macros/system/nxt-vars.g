; nxt-vars.g
; Defines default global variables for the nxt system.
;
; Vector globals use the same RHS form as MillenniumOS (sys/mos-vars.g): { vector(...) }.
; RRF 3.5.0+. See macros/system/RRF_META.txt. Caps: tool cache 50, gpOut snapshot 32 (MOS uses full limits.gpOutPorts).

; --- Features ---
global nxtFeatureTouchProbe = false
global nxtFeatureToolSetter = false
global nxtFeatureCoolantControl = false ; Coolant Control feature flag
global nxtFeatureRgbLight = false       ; RGB work light (M150 addressable strip)
global nxtFeatureFourthAxis = false     ; Fourth axis (requires MosFourthAxis DWC plugin on SD)

; --- Operator / tutorial modes ---
global nxtExpertMode = false            ; Skip confirmation dialogs when true
global nxtTutorialMode = true           ; Echo tutorial messages during probing
global nxtWS = ""                       ; Work-state hint for RGB daemon ("probing", "homing", …)

; --- Core Settings ---
global nxtProbeToolID = { limits.tools - 1 } ; Touch probe and datum share this slot (T49 on 50-tool table)
global nxtReservedFrom = { limits.tools - 1 } ; First system-reserved index; user tools 0 .. nxtReservedFrom-1
global nxtTouchProbeID = 0             ; The ID of the touch probe sensor
global nxtToolSetterID = 1             ; The ID of the tool setter sensor
; Active-low invert for M558 C"…" (`!` prefix). Touch probe NC typical = true.
; Scylla board toolsetter.g uses C"PE_7" (not inverted) — default false for setter.
global nxtTouchProbeInvert = true
global nxtToolSetterInvert = false
global nxtError = null               ; Stores the last error message
global nxtLoaded = false              ; Tracks if nxt has loaded successfully
global nxtBootOk = false              ; Boot checks passed; nxt.g sets nxtLoaded after overrides
global nxtUserVarsPresent = false     ; true after nxt-user-vars.g is loaded from SD (set in nxt.g)
global nxtConfigPending = false       ; true when nxt-user-vars.g missing — use DWC Configuration + Save

; --- Tooling & Probing ---
global nxtDeltaMachine = null      ; The static Z distance between the toolsetter and reference surface
global nxtProbeResults = { vector(5, null) } ; Last 5 probe results (rows sized at runtime to #move.axes+1)
global nxtToolCache = { vector(min(limits.tools, 50), null) } ; Per-tool cache (max 50 slots)
global nxtLastProbeResult = null   ; Stores the result of the last probing operation
global nxtProbeTipRadius = 0.0    ; Radius of the probe tip for compensation (mm)
global nxtProbeDeflection = {0.0, 0.0} ; {X,Y} touch-probe deflection (mm) — MOS mosTPD layout
global nxtDatumToolRadius = null  ; Datum tool radius when touch probe feature is off (mm)
global nxtProtectedMoveBackOff = null ; Protected move back-off distance (mm)
global nxtTouchProbeRefPos = null ; Touch probe reference surface [X, Y, Z] machine coords
global nxtRefSurfaceProbed = false ; Session flag: G6511 reference surface probed (reset each boot)
; G9000 calibration travel test (session only — not persisted to user-vars)
global nxtCalTravelCmd = { vector(3, 0.0) } ; Commanded distances [8, 16, 24]
global nxtCalTravelMeas = { vector(3, 0.0) } ; Measured travel per leg
global nxtCalTravelAxis = null ; Axis letter last tested ("X"|"Y"|"Z")
global nxtProbeHitXY = { vector(8, 0.0) } ; Last contacts as X,Y pairs (G6512 H0..H3), machine mm — bore/boss use H0..H2
global nxtProbeMaxSkewDeg = 5.0   ; Abort rectangle/bore skew solve if |theta| exceeds this (deg)

; --- Probe repeatability (G6512; all canned cycles use G6512) ---
; Defaults below. Plugin installs 0:/sys/nxt-user-overrides.g.example on SD; copy to nxt-user-overrides.g
; to enable (nxt.g loads only nxt-user-overrides.g last, then sets nxtLoaded). Not in Configuration UI.
;   nxtProbeInnerSampleCount — inner sample count when tolerance disabled (limit = 0); ignored when limit > 0 (G6512 uses 3 touches).
;   nxtProbeMaxSampleSpreadMm — max consecutive-pair deviation (mm) between the 3 touches; both pairs must pass. Set 0 to disable.
;   nxtProbeSampleOuterRetries — how many *additional* full 3-touch blocks after a failed tolerance check
;                                (total cycles = 1 + this). 1 = one retry after the first attempt.
global nxtProbeInnerSampleCount = 3
global nxtProbeMaxSampleSpreadMm = 0.0075
global nxtProbeSampleOuterRetries = 1
global nxtTouchProbeInnerSampleCount = 3 ; Touch probe specific G6512 inner sample count
global nxtTouchProbeMaxSampleSpreadMm = 0.0075 ; Touch probe consecutive-pair spread limit (mm), 0 disables
global nxtTouchProbeSampleOuterRetries = 1 ; Touch probe extra 3-touch retry cycles
global nxtToolSetterInnerSampleCount = 3 ; Toolsetter specific G6512 inner sample count (tpost enforces min 2)
global nxtToolSetterMaxSampleSpreadMm = 0.0075 ; Toolsetter consecutive-pair spread limit (mm), 0 disables
global nxtToolSetterSampleOuterRetries = 1 ; Toolsetter extra 3-touch retry cycles

global nxtToolSetterPos = null     ; Toolsetter position vector [X, Y, Z]
global nxtToolSetterProbeTravelMm = 80.0 ; Downward travel from toolsetter Z used for tool-length probing
global nxtToolSetterRadius = null ; Toolsetter platen radius for large-tool multi-point G37 (mm)
global nxtToolChangeState = null   ; Tracks the current tool change state (1=tfree, 2=tfree done, 3=tpre done, 4=tpost, null=complete)
global nxtUserToolsFilePresent = false     ; set at boot by nxt.g: nxt-user-tools.g exists on SD
global nxtUserToolsDaemonReload = false      ; if true, daemon reloads library when 0:/sys/nxt-user-tools.reload.requested exists (see TOOLCHANGING.md)
global nxtTTLocked = false                   ; Tool Library edit-lock (persisted via nxt-user-tools-sync.g)

; --- RGB status LED (optional feature) -------------------------------------
; A single status light that mirrors what the machine is doing. The daemon
; turns the machine state into a colour a few times a second - see nxt-run-rgb.g.
global nxtRgbLedIndex = 0 ; M6524 / Configuration UI LED index (M150 P parameter)

; Work-state hint. nxt macros set this (e.g. "probing", "homing"); the daemon
; clears it back to "" when the machine returns to idle, so a finished or
; aborted operation can never leave the light showing the wrong thing.
; (global nxtWS is declared above with operator / tutorial modes.)

; LED strip hardware. Configured in DWC and saved to nxt-user-vars.g. The strip
; is created on first run from these values.
global nxtRGBStrip = 0      ; LED strip number (the E in M950 E0 / M150 E0)
global nxtRGBPin   = null   ; data pin, e.g. "PA_10" - null until configured
global nxtRGBType  = 1      ; M950 T: 1=RGB NeoPixel, 3=RGBW NeoPixel
global nxtRGBCount = 1      ; number of LEDs in the strip
global nxtRGBBri   = 255    ; brightness 0-255

; Internal state for the renderer - do not edit.
global nxtRGBReady = false  ; set true once the strip has been created
global nxtRGBLast  = "none" ; last state rendered (so we only update on change)
global nxtRGBLastBri = -1 ; nxt-run-rgb change-detect for the idle-dim brightness

; Test override. Set this to a state name to FORCE that colour, ignoring what
; the machine is actually doing - used by the Status tab test button and for
; testing without probe hardware. Valid: "idle" "home" "probe" "tool" "run"
; "paused" "error". Set back to "" to resume normal behaviour.
global nxtRGBTest = ""

; Colour map — one {R,G,B,W} per state in a single vector (keeps global OM under SBC 8KB).
; Indices: 0=idle 1=home 2=probe 3=tool 4=run 5=paused 6=error
; (W is ignored automatically on an RGB strip.)
global nxtRGBCol = { {255, 255, 255, 255}, {0, 0, 255, 0}, {0, 255, 255, 0}, {255, 150, 0, 0}, {255, 255, 255, 255}, {255, 255, 255, 255}, {255, 0, 0, 0} }

; Idle RGB dimming (nxt-run-rgb.g; nxt-run-maintenance.g may engage idle mode)
global nxtIdleActive = false          ; runtime: true while idle mode is engaged
global nxtIdleDimBri = 40             ; RGB brightness while idle (0-255; error stays full)

; --- Maintenance counters (axis travel + per-tool spindle-on life) ---
; Accumulated by nxt-run-maintenance.g from the daemon. Persisted to 0:/sys/nxt-maintenance.g.
; Size with max(#move.axes, 4): nxt-vars.g often runs before M584, when #move.axes is 0.
global nxtFeatMaint = true                            ; master enable for maintenance tracking
global nxtAxisTravel = { vector(max(#move.axes, 4), 0.0) }    ; accumulated travel per axis (mm)
global nxtAxisServiceAt = { vector(max(#move.axes, 4), 0.0) } ; per-axis service threshold (mm); 0 = off
global nxtToolLife = { vector(limits.tools, 0.0) }    ; accumulated spindle-on time per tool (s)
global nxtMaintLastPos = { vector(max(#move.axes, 4), 0.0) }  ; last sampled machine position per axis
global nxtMaintLastTime = 0                           ; last sampled uptime (s) for life dt
global nxtMaintPrimed = false                         ; false until the first sample is taken
global nxtMaintTick = 0                               ; active-tick counter for periodic persist
global nxtMaintPersistEvery = 60                      ; periodic-save backstop: this many ACTIVE ticks
global nxtMaintWasActive = false                      ; tracks active->idle edge to save at burst end

; Coolant / mister runtime (maintenance reminder for reservoir refill / nozzle clean)
global nxtCoolantRuntime = 0          ; accumulated coolant-on seconds
global nxtCoolantServiceAt = 0        ; coolant service interval (seconds); 0 = off

; Idle auto-actions: dim RGB + drop E-bay fan after inactivity (nxt-run-maintenance.g)
global nxtFeatIdleActions = true      ; master enable for idle auto-actions
global nxtIdleAfter = 1800            ; seconds of inactivity before idle mode (default 30 min)
global nxtIdleFanLow = 0.3            ; E-bay fan (F0) PWM while idle (0-1)
global nxtIdleSince = 0               ; runtime: uptime(s) activity was last seen

; Motor / VFD contactor relay output — reserved from coolant Configuration UI
global nxtRelayID = null

; Aux gpOut roles (Configuration UI; reserved for future macros)
global nxtAux1ID = null
global nxtAux2ID = null
global nxtAux3ID = null

; --- Coolant Control ---
global nxtCoolantAirID = null ; Coolant Air Output Pin ID
global nxtCoolantMistID = null ; Coolant Mist Output Pin ID
global nxtCoolantFloodID = null ; Coolant Flood Output Pin ID
global nxtPinStates = { vector(min(limits.gpOutPorts, 8), 0.0) } ; gpOut PWM snapshot; pause.g uses min(#gpOut, #nxtPinStates)
global nxtCoolantMistPulseEnabled = false ; Pulse mist output when M7 is used
global nxtCoolantFloodPulseEnabled = false ; Pulse flood output when M8 is used
global nxtCoolantPulseOnSec = 5 ; Coolant pulse ON phase length (seconds)
global nxtCoolantPulseOffSec = 25 ; Coolant pulse OFF phase length (seconds)
global nxtCoolantMistRequested = false ; Runtime: M7 issued (cleared by M9)
global nxtCoolantFloodRequested = false ; Runtime: M8 issued (cleared by M9)
global nxtCoolantPulseActive = false ; Runtime: daemon should tick pulse phases
global nxtCoolantPulsePhaseOn = true ; Runtime: current pulse phase (true = ON)
global nxtCoolantPulseLastMs = 0 ; Runtime: millis() at last phase transition

; --- Daemon loop (coolant pulse, plugins, user hooks) ---
global nxtDaemonEnabled = true ; Enable macros/system/daemon.g background loop
global nxtDaemonInterval = 250 ; Minimum milliseconds between daemon iterations

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
; Custom-platform keys stay declared so legacy nxt-user-vars.g `set global.nxtCustom* = null`
; lines still boot. OM headroom comes mainly from null-filled nxtTT (see nxt-tooltable.g).
global nxtPlatformProfile = null   ; platform id = nxt-config/machine/<id>/ directory name
global nxtBoardKitKey = null       ; legacy UI key; optional — prefer shortName + nxtBoardMotorVoltage
global nxtBoardShortNameOverride = null ; RRF boards[0].shortName override for pack resolution, or null
global nxtBoardMotorVoltage = null ; 24 | 48 | null (motor-24v / motor-48v board packs)
global nxtScyllaMotorVoltage = null ; deprecated — use nxtBoardMotorVoltage
global nxtBoardPackEntry = null    ; last resolved entry path at boot (telemetry)
global nxtBoardPackExpectedEntry = null ; saved expected entry path (Configuration Save)
global nxtBoardSysDeployPlatform = null ; platform whose home*.g were last deployed to 0:/sys/
global nxtBoardBootstrapMode = "off" ; "off" | "auto" (Save syncs nxt-board-bootstrap.requested)

; Custom platform (when nxtPlatformProfile == "custom") — Configuration UI
global nxtCustomXMin = null
global nxtCustomXMax = null
global nxtCustomYMin = null
global nxtCustomYMax = null
global nxtCustomZMin = null
global nxtCustomZMax = null
global nxtCustomXSteps = null
global nxtCustomYSteps = null
global nxtCustomZSteps = null
global nxtCustomASteps = null
global nxtCustomXHomeAt = null
global nxtCustomYHomeAt = null
global nxtCustomZHomeAt = null
global nxtCustomXEndstopPin = null
global nxtCustomYEndstopPin = null
global nxtCustomZEndstopPin = null
global nxtCustomXDrives = null
global nxtCustomYDrives = null
global nxtCustomZDrives = null
global nxtCustomXCurrent = null
global nxtCustomYCurrent = null
global nxtCustomZCurrent = null
; Compact M569 map: "0:1,1:1,2:0" (drive:direction)
global nxtCustomDriveDirs = null
; Backlash compensation (M425) — Custom overlay
global nxtCustomXBacklash = null
global nxtCustomYBacklash = null
global nxtCustomZBacklash = null
global nxtCustomABacklash = null

; --- Optional magazine / ATC extension (not allocated here) ---
; Bay maps, job sequence vectors, and related globals are defined only when a tool changer
; macro pack is installed on the machine. Base nxt does not create atc*. globals nxtET and
; nxtTT are allocated by nxt-tooltable.g (invoked from nxt.g) when not already present from
; mos-vars.g, and maintained by M4000/M4001 for post-driven tool definitions.
; See docs/TOOLCHANGING.md and ui/src/utils/nxtToolChangerOm.ts (OM key map).
