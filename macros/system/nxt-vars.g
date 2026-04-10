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

; --- Tooling & Probing ---
global nxtDeltaMachine = null      ; The static Z distance between the toolsetter and reference surface
global nxtProbeResults = { vector(10, null) } ; Last 10 probe results (rows sized at runtime to #move.axes+1)
global nxtToolCache = { vector(min(limits.tools, 50), null) } ; Per-tool cache (max 50 slots)
global nxtLastProbeResult = null   ; Stores the result of the last probing operation
global nxtProbeTipRadius = 0.0    ; Radius of the probe tip for compensation (mm)
global nxtProbeDeflection = 0.0   ; Probe deflection compensation value (mm)
global nxtToolSetterPos = null     ; Toolsetter position vector [X, Y, Z]
global nxtToolChangeState = null   ; Tracks the current tool change state (1=tfree, 2=tfree done, 3=tpre done, 4=tpost, null=complete)

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

; --- Board / platform selection (UI + bootstrap helpers) ---
global nxtPlatformProfile = null   ; "v1.5" | "v1.6_v2" | "atlas" | null
global nxtBoardKitKey = null       ; "fly_cdyv3" | "scylla_24" | "scylla_48" | null
global nxtScyllaMotorVoltage = null ; 24 | 48 | null (hint when kit is Scylla)
global nxtBoardBootstrapMode = "off" ; "off" | "auto" (UI preference; bootstrap uses SD sentinel files today)

; --- Optional magazine / ATC extension (not allocated here) ---
; Bay maps, job sequence vectors, and related globals are defined only when a tool changer
; macro pack is installed on the machine. NeXT base install does not create atc* or mosTT.
; See docs/TOOLCHANGING.md and ui/src/utils/nxtToolChangerOm.ts (OM key map).
