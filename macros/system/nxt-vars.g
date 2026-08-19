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
global nxtFeatureAtc = false            ; Magazine / ATC (requires MosAtc DWC plugin + SD init macros)

; --- Operator / tutorial modes ---
global nxtExpertMode = false            ; Skip confirmation dialogs when true
global nxtTutorialMode = true           ; Echo tutorial messages during probing
global nxtWS = ""                       ; Work-state hint for RGB daemon ("probing", "homing", …)

; --- Core Settings ---
global nxtProbeToolID = { limits.tools - 1 } ; Touch probe RRF slot (T49 on 50-tool table)
; nxtReservedFrom removed from always-on declares (was a dual-slot/range alias; OM budget).
; Legacy SD may still `set` it — boot clears/syncs only if it already exists.
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
global nxtProbeResults = { vector(9, null) } ; Slots 0–8 = U1–U9 (rows sized at runtime to #move.axes+1)
; Tool-length cache for relative offsets (tpost) — two scalars, not vector(limits.tools) (OM ~8KB)
global nxtToolCacheIdx = -1            ; tool index for nxtToolCacheZ (-1 = empty)
global nxtToolCacheZ = null            ; last measured Z / virtual toolsetter Z for that tool
global nxtProbeVirtualTsZ = null       ; mill length datum = M5016 platen Z (user-vars + nxt-probe-virtual.g)
global nxtLastProbeResult = null   ; Stores the result of the last probing operation
global nxtProbeTipRadius = 0.0    ; Radius of the probe tip for compensation (mm)
global nxtProbeDeflection = {0.0, 0.0, 0.0} ; {X,Y,Z} touch-probe deflection (mm); legacy {X,Y}/scalar ok
global nxtDatumToolRadius = null  ; Datum tool radius when touch probe feature is off (mm)
global nxtProtectedMoveBackOff = null ; Protected move back-off distance (mm)
global nxtTouchProbeRefPos = null ; Touch probe reference surface [X, Y, Z] machine coords
global nxtRefSurfaceProbed = false ; Session flag: G6511 reference surface probed (reset each boot)
; G9000 / M5014 calibration travel — allocated on first use (OM ~8KB budget)
global nxtCalTravelCmd = null
global nxtCalTravelMeas = null
global nxtCalTravelAxis = null
; M5017 deflection spans — session results (UI applies deflection)
global nxtCalDefSpan = null
global nxtCalDefSpanX = null
global nxtCalDefSpanY = null
global nxtCalDefZ = null          ; unused (Z deflection discarded); G6511 clears
; G6512 H-slot contacts — allocated on first H= write (OM ~8KB budget)
global nxtProbeHitXY = null
; Face-line / corner-intersect scratch (session; not persisted)
global nxtFaceLineN = 0
global nxtFaceCornerX = null
global nxtFaceCornerY = null
global nxtFaceThetaDeg = 0
global nxtProbeMaxSkewDeg = 5.0   ; Abort rectangle/bore skew solve if |theta| exceeds this (deg)
; Job-scoped G68 (session only — not persisted to nxt-user-vars.g)
; Policy armed by M6520 Q. G68 only from M5011 while a job file is running.
global nxtG68Policy = 0            ; 0=prompt at M5011, 1=always (job file), 2=never (translation)
global nxtJobG68Deg = null         ; null = no job rotation; else degrees last applied
global nxtJobG68Wcs = null         ; workplace 1–9 that owns nxtJobG68Deg

; --- Probe repeatability (G6512; all canned cycles use G6512) ---
; Defaults below. Optional touch/toolsetter-specific keys: declare+set in nxt-user-overrides.g
; (see nxt-user-overrides.g.example). Not in Configuration UI.
global nxtProbeInnerSampleCount = 3
global nxtProbeMaxSampleSpreadMm = 0.075
global nxtProbeSampleOuterRetries = 1
global nxtCornerOffset = 5.0   ; Along-face inset from corner before Z dive (mm)

global nxtToolSetterPos = null     ; Toolsetter position vector [X, Y, Z]
global nxtToolSetterV2 = false     ; V2.0: fixed ref pad geometry (13mm XY / -6mm Z vs platen)
global nxtToolSetterRefDir = 0     ; V2 ref pad side of platen: 0=+X 1=-X 2=+Y 3=-Y
global nxtToolSetterProbeTravelMm = 80.0 ; Downward travel from known Z (mill tpost platen; G6511 mill-touch)
global nxtToolSetterRadius = null ; Toolsetter platen radius for large-tool multi-point G37 (mm)
global nxtToolChangeState = null   ; Tracks the current tool change state (1=tfree, 2=tfree done, 3=tpre done, 4=tpost, null=complete)
global nxtToolChangeCancelled = false ; Operator Cancel in tfree/tpre: tpost skips measure (no T from firmware)
global nxtUserToolsFilePresent = false     ; set at boot by nxt.g: nxt-user-tools.g exists on SD
global nxtUserToolsDaemonReload = false      ; if true, daemon reloads library when 0:/sys/nxt-user-tools.reload.requested exists (see TOOLCHANGING.md)
global nxtTTLocked = false                   ; Tool Library edit-lock (persisted via nxt-user-tools-sync.g)
; After M6520 / nxt-wcs-apply, rewrite 0:/sys/nxt-user-wcs.g (G10 L2 + select).
global nxtAutoPersistWcs = true
; Probe cycles set true so stop.g skips XY G27 after numbered G65xx.
global nxtSkipJobPark = false

; --- RGB status LED (optional feature) -------------------------------------
; A single status light that mirrors what the machine is doing. The daemon
; turns the machine state into a colour a few times a second - see nxt-run-rgb.g.
global nxtRgbLedIndex = 0 ; legacy unused; strip length is nxtRGBCount (Configuration)

; Work-state hint. nxt macros set this (e.g. "probing", "homing"); the daemon
; clears it back to "" when the machine returns to idle, so a finished or
; aborted operation can never leave the light showing the wrong thing.
; (global nxtWS is declared above with operator / tutorial modes.)

; LED strip hardware. Configured in DWC and saved to nxt-user-vars.g. The strip
; is created on first run from these values.
global nxtRGBStrip = 0      ; LED strip number (the E in M950 E0 / M150 E0)
global nxtRGBPin   = null   ; data pin, e.g. "PA_10" - null until configured
global nxtRGBType  = 1      ; M950 T: 1=RGB NeoPixel, 2=RGBW NeoPixel
global nxtRGBOrder = 5      ; M950 K colour order: 0=BGR … 5=GRB (NeoPixel default)
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
; Tool life: null until first tick / nxt-maintenance.g (50×0.0 floats blow the SBC ~8KB global cap)
global nxtToolLife = null
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

; Aux gpOut roles (Configuration UI). Scylla labels: Aux0→nxtAux1ID, Aux1→nxtAux2ID, Aux2→nxtAux3ID
global nxtAux1ID = null
global nxtAux2ID = null
global nxtAux3ID = null

; Named board pins created as fans (M950 F) instead of gpOut (M950 P).
; Default filled by Scylla gpio.g when null: always aux0 (aux/relay are 24V rails).
; Idempotent: gpio.g may declare this before nxt-vars on some boot paths.
if { !exists(global.nxtBoardFanPins) }
    global nxtBoardFanPins = null
else
    set global.nxtBoardFanPins = null

; UART accessory on board serial header (Scylla PD8/PD9 aux2). 0=off 1=PanelDue 2=TFT 3=pendant
global nxtUartDevice = 0
global nxtUartBaud = 57600

; --- Coolant Control ---
global nxtCoolantAirID = null ; Coolant Air Output Pin ID
global nxtCoolantMistID = null ; Coolant Mist Output Pin ID
global nxtCoolantFloodID = null ; Coolant Flood Output Pin ID
global nxtPinStates = null ; gpOut PWM snapshot; allocated in pause.g (OM budget)
global nxtCoolantMistPulseEnabled = false ; Pulse mist output when M7 is used
global nxtCoolantFloodPulseEnabled = false ; Pulse flood output when M8 is used
global nxtCoolantPulseOnSec = 5 ; Coolant pulse ON phase length (seconds)
global nxtCoolantPulseOffSec = 25 ; Coolant pulse OFF phase length (seconds)
global nxtCoolantMistRequested = false ; Runtime: M7 issued (cleared by M9)
global nxtCoolantFloodRequested = false ; Runtime: M8 issued (cleared by M9)
global nxtCoolantPulseActive = false ; Runtime: daemon should tick pulse phases
global nxtCoolantPulsePhaseOn = true ; Runtime: current pulse phase (true = ON)
global nxtCoolantPulseLastMs = 0 ; Runtime: state.upTime*1000+state.msUpTime at last phase transition

; --- Daemon loop (coolant pulse, plugins, user hooks) ---
global nxtDaemonEnabled = true ; Enable macros/system/daemon.g background loop
global nxtDaemonInterval = 250 ; Minimum milliseconds between daemon iterations
; Packed fileexists cache: bit0=plugin-init, bit1=plugin-daemon, bit2=tools-reload
global nxtDaemonHooks = 0

; --- Spindle Control ---
; Idempotent: must exist before nxt-user-vars.g set (do not bare-declare after a mid-file abort).
; Accel default 10 s (M3.9 floor); omit unset from nxt-user-vars. ArborCTL VFD Apply overlays measured ramp.
if { !exists(global.nxtSpindleID) }
    global nxtSpindleID = 0
else
    set global.nxtSpindleID = 0
if { !exists(global.nxtSpindleAccelSec) }
    global nxtSpindleAccelSec = 10
else
    set global.nxtSpindleAccelSec = 10
if { !exists(global.nxtSpindleDecelSec) }
    global nxtSpindleDecelSec = 10
else
    set global.nxtSpindleDecelSec = 10

; VSSC session state (M7000/M7001 overlay; do not persist to nxt-user-vars.g)
global nxtVSEnabled = false ; Daemon gate for nxt-run-vssc.g
global nxtVSP = 0           ; Period (ms) of one speed-adjustment cycle
global nxtVSV = 0           ; Full-swing variance (RPM)
global nxtVSPS = 0          ; Programmed base RPM
global nxtVSPT = 0          ; Last phase timestamp (state.upTime*1000+state.msUpTime)

; --- Canned drilling cycles (G81, G73, G83, …) ---
; When non-null, nxtCannedCycle is a vector:
; [0]=kind (81,73,83,82,85,89), [1]=Z, [2]=R, [3]=Q or null, [4]=F, [5]=seriesInitZ (G98), [6]=retractMode (98|99), [7]=P dwell s or null
global nxtCannedCycle = null
global nxtCannedRetractMode = 98   ; G98 initial plane / G99 R plane — set by G98.g / G99.g
global nxtCannedZi = 0              ; scratch: Z axis index (set by nxt-canned-zindex.g)

; --- Board / platform selection (UI + pack loader) ---
; Custom-platform keys: nxt-custom-globals.g when Custom is active (sentinel / overlays).
; Deprecated nxtBoardKitKey / nxtScyllaMotorVoltage: not declared here (OM budget); migrate in UI/resolvers.
global nxtPlatformProfile = null   ; platform id = nxt-config/machine/<id>/ directory name
global nxtBoardShortNameOverride = null ; RRF boards[0].shortName override for pack resolution, or null
global nxtBoardMotorVoltage = null ; 24 | 48 | null (motor-24v / motor-48v board packs)
; Pack path telemetry (Entry / Expected / ShortName / SysDeploy): declare on first use in
; nxt-board-pack-resolve.g / Configuration Save (OM budget — not always-on nulls).
global nxtBoardBootstrapMode = "off" ; "off" | "auto" (Save syncs nxt-board-bootstrap.requested)

; --- Optional magazine / ATC extension (not allocated here) ---
; Bay maps, job sequence vectors, and related globals are defined only when a tool changer
; macro pack is installed on the machine. Base nxt does not create atc*. globals nxtET and
; nxtTT are allocated by nxt-tooltable.g (invoked from nxt.g) when not already present from
; mos-vars.g, and maintained by M4000/M4001 for post-driven tool definitions.
; See docs/TOOLCHANGING.md and ui/src/utils/nxtToolChangerOm.ts (OM key map).
