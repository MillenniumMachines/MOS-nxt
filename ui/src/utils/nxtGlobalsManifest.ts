/**
 * Expected nxt `global.*` keys (base install: nxt.g / nxt-vars.g).
 * Used by Configuration panel snapshot; keep aligned with macros/system/nxt-vars.g and nxt.g.
 */
import { readFirmwareGlobal } from './nxtToolChangerOm'

export type NxtGlobalManifestEntry = { key: string; description: string }

export const NXT_GLOBAL_MANIFEST: NxtGlobalManifestEntry[] = [
  { key: 'nxtVersion', description: 'nxt build/version (set in nxt.g)' },
  { key: 'nxtVarsLoaded', description: 'True after nxt-vars.g has been run once' },
  { key: 'nxtFeatureTouchProbe', description: 'Feature: touch probe' },
  { key: 'nxtFeatureToolSetter', description: 'Feature: tool setter' },
  { key: 'nxtFeatureCoolantControl', description: 'Feature: coolant control' },
  { key: 'nxtFeatureRgbLight', description: 'Feature: RGB work light (M150)' },
  { key: 'nxtFeatureFourthAxis', description: 'Feature: fourth / A axis (Scylla axis-a.g; MosFourthAxis for steps)' },
  { key: 'nxtFeatureAtc', description: 'Feature: magazine / ATC (MosAtc init macros; gated OM atc* globals)' },
  { key: 'nxtFeatureMachinePower', description: 'Feature: motor/VFD contactor (M80.9 / M42 gpOut or ATX)' },
  { key: 'nxtRgbLedIndex', description: 'Legacy unused LED index (kept for OM compatibility)' },
  { key: 'nxtRGBCount', description: 'NeoPixel LED count (M950 U / M150 S)' },
  { key: 'nxtRGBStrip', description: 'LED strip object number (M950 E / M150 E)' },
  { key: 'nxtRGBPin', description: 'NeoPixel data pin / alias for M950 C' },
  { key: 'nxtRGBType', description: 'Strip format for M950 T (1=RGB, 2=RGBW)' },
  { key: 'nxtRGBOrder', description: 'Colour order for M950 K (0=BGR … 5=GRB NeoPixel default)' },
  { key: 'nxtRGBBri', description: 'Daemon RGB brightness 0-255' },
  { key: 'nxtRGBReady', description: 'True after M950 has created the strip' },
  { key: 'nxtRGBCol', description: 'Packed RGBW colours for seven daemon states' },
  { key: 'nxtProbeToolID', description: 'RRF tool index for probe' },
  { key: 'nxtTouchProbeID', description: 'Touch probe sensor ID' },
  { key: 'nxtTouchProbeInvert', description: 'Touch probe pin active-low invert (M558 C"!…")' },
  { key: 'nxtToolSetterID', description: 'Tool setter sensor ID' },
  { key: 'nxtToolSetterInvert', description: 'Toolsetter pin active-low invert (M558 C"!…")' },
  { key: 'nxtError', description: 'Last nxt error message' },
  { key: 'nxtLoaded', description: 'nxt boot completed successfully' },
  { key: 'nxtBootOk', description: 'Boot checks passed; nxtLoaded set after nxt-user-overrides.g' },
  { key: 'nxtUserVarsPresent', description: 'True after nxt-user-vars.g was loaded from SD (nxt.g)' },
  { key: 'nxtConfigPending', description: 'True when nxt-user-vars.g is missing — complete setup in Configuration UI' },
  { key: 'nxtDeltaMachine', description: 'Static datum Z (toolsetter ↔ reference)' },
  { key: 'nxtTouchProbeRefPos', description: 'Touch probe reference surface [X, Y, Z] machine coords' },
  { key: 'nxtRefSurfaceProbed', description: 'Session flag: G6511 reference surface probed' },
  { key: 'nxtCalTravelCmd', description: 'G9000 session: commanded travel distances [8,16,24]' },
  { key: 'nxtCalTravelMeas', description: 'G9000 session: measured travel distances' },
  { key: 'nxtCalTravelAxis', description: 'G9000 session: axis letter last tested' },
  { key: 'nxtCalDefSpan', description: 'M5017 session: legacy/compat span (mm); prefer SpanX/Y' },
  { key: 'nxtCalDefSpanX', description: 'M5017 session: X external span ~3in (mm)' },
  { key: 'nxtCalDefSpanY', description: 'M5017 session: Y external span ~2in (mm)' },
  { key: 'nxtCalDefZ', description: 'Unused (Z deflection discarded); G6511 clears to null' },
  { key: 'nxtProbeMaxSkewDeg', description: 'Max |θ| (deg) for rectangle/bore skew before abort' },
  { key: 'nxtG68Policy', description: 'Session: job-start G68 policy (0=prompt 1=always while job file 2=never); armed by M6520 Q; omitted Q=0' },
  { key: 'nxtWPDeg', description: 'Probed G68 skew per workplace (deg); always-on for M5011. Other nxtWP* via nxt-wp-ensure.g' },
  { key: 'nxtOvertravel', description: 'Probe overtravel past expected surface (mm)' },
  { key: 'nxtClearance', description: 'Probe standoff / operator clear height (mm)' },
  { key: 'nxtJobG68Deg', description: 'Session: job-scoped G68 angle (null when inactive; set by job M5011)' },
  { key: 'nxtJobG68Wcs', description: 'Session: workplace 1–9 owning nxtJobG68Deg' },
  { key: 'nxtProbeResults', description: 'Last probe results table (vector)' },
  { key: 'nxtToolCacheIdx', description: 'Tool-length cache: tool index (-1 empty)' },
  { key: 'nxtToolCacheZ', description: 'Tool-length cache: measured Z for nxtToolCacheIdx' },
  { key: 'nxtProbeVirtualTsZ', description: 'Mill length datum = M5016 platen Z (user-vars + nxt-probe-virtual.g)' },
  { key: 'nxtLastProbeResult', description: 'Last single probe result' },
  { key: 'nxtProbeTipRadius', description: 'Probe tip radius (mm)' },
  { key: 'nxtProbeDeflection', description: 'Probe deflection {X,Y,Z} mm; Z unused (always 0)' },
  { key: 'nxtProbeInnerSampleCount', description: 'G6512 inner samples when R omitted (default nxt-vars.g; override nxt-user-overrides.g)' },
  { key: 'nxtProbeMaxSampleSpreadMm', description: 'G6512 max consecutive-pair deviation (mm); 0 disables (default 0.0075 in nxt-vars.g)' },
  { key: 'nxtProbeSampleOuterRetries', description: 'G6512 extra sample blocks after failed spread (default nxt-vars.g)' },
  { key: 'nxtCornerOffset', description: 'Along-face inset from corner before Z dive (mm); G6508/G6509/G6520 when E omitted' },
  { key: 'nxtFaceLineN', description: 'Session: last nxt-probe-face-line point count (1 or 3)' },
  { key: 'nxtFaceCornerX', description: 'Session: nxt-corner-intersect corner X (mm)' },
  { key: 'nxtFaceCornerY', description: 'Session: nxt-corner-intersect corner Y (mm)' },
  { key: 'nxtFaceThetaDeg', description: 'Session: nxt-corner-intersect skew (deg)' },
  { key: 'nxtTouchProbeInnerSampleCount', description: 'Touch probe G6512 inner samples (tpost touch-probe path)' },
  { key: 'nxtTouchProbeMaxSampleSpreadMm', description: 'Touch probe pair spread limit (mm); 0 disables tolerance' },
  { key: 'nxtTouchProbeSampleOuterRetries', description: 'Touch probe extra 3-touch retry cycles' },
  { key: 'nxtToolSetterInnerSampleCount', description: 'Toolsetter G6512 inner samples (tpost enforces minimum 2)' },
  { key: 'nxtToolSetterMaxSampleSpreadMm', description: 'Toolsetter pair spread limit (mm); 0 disables tolerance' },
  { key: 'nxtToolSetterSampleOuterRetries', description: 'Toolsetter extra 3-touch retry cycles' },
  { key: 'nxtToolSetterPos', description: 'Toolsetter position [X,Y,Z]' },
  { key: 'nxtToolSetterV2', description: 'V2.0 toolsetter: compute ref pad from orientation (13mm XY / -6mm Z)' },
  { key: 'nxtToolSetterRefDir', description: 'V2 ref pad side of platen: 0=+X 1=-X 2=+Y 3=-Y' },
  { key: 'nxtToolSetterProbeTravelMm', description: 'Downward travel from known Z (mill tpost platen; G6511 mill-touch) (mm)' },
  { key: 'nxtToolChangeState', description: 'Tool-change macro state' },
  { key: 'nxtToolChangeCancelled', description: 'Operator cancelled tfree/tpre; tpost skips measure; firmware never issues T' },
  { key: 'nxtCoolantAirID', description: 'Coolant air GP out ID' },
  { key: 'nxtCoolantMistID', description: 'Coolant mist GP out ID (Scylla preferred P4)' },
  { key: 'nxtCoolantFloodID', description: 'Coolant flood GP out ID (Scylla preferred P3)' },
  { key: 'nxtRelayID', description: 'Motor/VFD relay gpOut (Scylla P5 / PD_5)' },
  { key: 'nxtAux1ID', description: 'Aux 0 GP out ID (Scylla preferred P0, 24V)' },
  { key: 'nxtAux2ID', description: 'Aux 1 GP out ID (Scylla preferred P1, 24V)' },
  { key: 'nxtAux3ID', description: 'Aux 2 GP out ID (Scylla preferred P2, 24V)' },
  { key: 'nxtBoardFanPins', description: 'Named board pins created as fans (M950 F); default aux0' },
  { key: 'nxtUartDevice', description: 'UART accessory: 0=off 1=PanelDue 2=TFT 3=pendant (Scylla PD8/PD9)' },
  { key: 'nxtUartBaud', description: 'UART accessory baud (default 57600)' },
  { key: 'nxtCoolantMistPulseEnabled', description: 'Pulse mist output when M7 is used' },
  { key: 'nxtCoolantFloodPulseEnabled', description: 'Pulse flood output when M8 is used' },
  { key: 'nxtCoolantPulseOnSec', description: 'Coolant pulse ON phase (seconds)' },
  { key: 'nxtCoolantPulseOffSec', description: 'Coolant pulse OFF phase (seconds)' },
  { key: 'nxtCoolantMistRequested', description: 'Runtime: M7 issued (cleared by M9)' },
  { key: 'nxtCoolantFloodRequested', description: 'Runtime: M8 issued (cleared by M9)' },
  { key: 'nxtCoolantPulseActive', description: 'Runtime: coolant pulse daemon active' },
  { key: 'nxtDaemonEnabled', description: 'Enable macros/system/daemon.g loop' },
  { key: 'nxtDaemonInterval', description: 'Daemon loop interval (ms)' },
  { key: 'nxtPinStates', description: 'gpOut snapshot vector' },
  { key: 'nxtSpindleID', description: 'Default spindle ID' },
  { key: 'nxtSpindleAccelSec', description: 'Spindle accel time (s)' },
  { key: 'nxtSpindleDecelSec', description: 'Spindle decel time (s)' },
  { key: 'nxtVSEnabled', description: 'Runtime: VSSC daemon gate (M7000/M7001)' },
  { key: 'nxtVSP', description: 'Runtime: VSSC period (ms)' },
  { key: 'nxtVSV', description: 'Runtime: VSSC full-swing variance (RPM)' },
  { key: 'nxtVSPS', description: 'Runtime: VSSC programmed base RPM' },
  { key: 'nxtVSPT', description: 'Runtime: VSSC last phase timestamp (millis)' },
  { key: 'nxtCannedCycle', description: 'Active canned cycle state vector' },
  { key: 'nxtCannedRetractMode', description: 'G98/G99 retract mode' },
  { key: 'nxtCannedZi', description: 'Canned cycle scratch: Z axis index' },
  { key: 'nxtPlatformProfile', description: 'Machine profile (v1.5 / v1.6 / v2.0-milo / v2.0-miley / custom); nxt-config/machine/<id>/ at boot' },
  { key: 'nxtCustomXMin', description: 'Custom platform X min (M208)' },
  { key: 'nxtCustomXMax', description: 'Custom platform X max (M208)' },
  { key: 'nxtCustomYMin', description: 'Custom platform Y min (M208)' },
  { key: 'nxtCustomYMax', description: 'Custom platform Y max (M208)' },
  { key: 'nxtCustomZMin', description: 'Custom platform Z min (M208)' },
  { key: 'nxtCustomZMax', description: 'Custom platform Z max (M208)' },
  { key: 'nxtCustomAMin', description: 'Custom platform A min (M208)' },
  { key: 'nxtCustomAMax', description: 'Custom platform A max (M208)' },
  { key: 'nxtCustomXSteps', description: 'Custom platform X steps/mm (M92)' },
  { key: 'nxtCustomYSteps', description: 'Custom platform Y steps/mm (M92)' },
  { key: 'nxtCustomZSteps', description: 'Custom platform Z steps/mm (M92)' },
  { key: 'nxtCustomASteps', description: 'Custom platform A steps/mm (M92 / M4806)' },
  { key: 'nxtCustomXHomeAt', description: 'Custom X endstop side 1=min 2=max (M574)' },
  { key: 'nxtCustomYHomeAt', description: 'Custom Y endstop side 1=min 2=max (M574)' },
  { key: 'nxtCustomZHomeAt', description: 'Custom Z endstop side 1=min 2=max (M574)' },
  { key: 'nxtCustomAHomeAt', description: 'Custom A endstop side 1=min 2=max (M574)' },
  { key: 'nxtCustomXEndstopPin', description: 'Custom X endstop pin(s) M574 P — single or pin1+pin2' },
  { key: 'nxtCustomYEndstopPin', description: 'Custom Y endstop pin(s) M574 P — single or pin1+pin2' },
  { key: 'nxtCustomZEndstopPin', description: 'Custom Z endstop pin(s) M574 P — single or pin1+pin2' },
  { key: 'nxtCustomAEndstopPin', description: 'Custom A endstop pin(s) M574 P — single or pin1+pin2' },
  { key: 'nxtCustomXDrives', description: 'Custom X drive map e.g. 0 or 0:1 (M584)' },
  { key: 'nxtCustomYDrives', description: 'Custom Y drive map (M584)' },
  { key: 'nxtCustomZDrives', description: 'Custom Z drive map e.g. 2:3 (M584)' },
  { key: 'nxtCustomADrives', description: 'Custom A drive map e.g. 3 (M584)' },
  { key: 'nxtCustomXCurrent', description: 'Custom X motor current mA (M906)' },
  { key: 'nxtCustomYCurrent', description: 'Custom Y motor current mA (M906)' },
  { key: 'nxtCustomZCurrent', description: 'Custom Z motor current mA (M906)' },
  { key: 'nxtCustomACurrent', description: 'Custom A motor current mA (M906)' },
  { key: 'nxtCustomDriveDirs', description: 'Custom M569 dirs e.g. 0:1,1:1,2:0' },
  { key: 'nxtCustomXBacklash', description: 'Custom X backlash mm (M425)' },
  { key: 'nxtCustomYBacklash', description: 'Custom Y backlash mm (M425)' },
  { key: 'nxtCustomZBacklash', description: 'Custom Z backlash mm (M425)' },
  { key: 'nxtCustomABacklash', description: 'Custom A backlash (M425)' },
  { key: 'nxtBoardShortNameOverride', description: 'Optional RRF boards[0].shortName override; null uses object model primary board' },
  { key: 'nxtBoardKitKey', description: 'Legacy kit key (deprecated; use shortName + nxtBoardMotorVoltage)' },
  { key: 'nxtBoardMotorVoltage', description: 'Motor supply 24 or 48 V for motor-24v/48v board packs' },
  { key: 'nxtScyllaMotorVoltage', description: 'Deprecated — use nxtBoardMotorVoltage' },
  { key: 'nxtBoardPackExpectedEntry', description: 'UI-only expected pack path (comment in user-vars; not an OM global)' },
  { key: 'nxtBoardSysDeployPlatform', description: 'Platform whose home*.g were last deployed to 0:/sys/' },
  { key: 'nxtBoardPackEntry', description: 'Runtime: last resolved board pack entry path (nxt-board-pack-loader.g)' },
  { key: 'nxtDaemonHooks', description: 'Packed fileexists cache: bit0=plugin-init, bit1=plugin-daemon, bit2=tools-reload' },
  { key: 'nxtBoardPackResolveBrd', description: 'Scratch board shortName passed loader → pack resolver (M98)' },
  { key: 'nxtBoardBootstrapMode', description: 'Pack load preference (off|auto); SD sentinel enables load' },
  { key: 'nxtUserToolsFilePresent', description: 'True if 0:/sys/nxt-user-tools.g existed at last nxt.g boot load' },
  { key: 'nxtUserToolsDaemonReload', description: 'If true, daemon reloads nxt-user-tools.g when reload sentinel exists' },
  { key: 'nxtAutoPersistWcs', description: 'If true, M6520 / nxt-wcs-apply / nxt-wcs-set / nxt-wcs-clear rewrite 0:/sys/nxt-user-wcs.g (G10 L2)' },
  { key: 'nxtSkipJobPark', description: 'Session: probe cycle asks stop.g not to G27 XY (numbered G65xx / HTTP)' }
]

/** Human-readable value from RRF object model global (may be Map or plain object). */
export function formatOmGlobalValue(val: unknown): string {
  if (val === undefined) {
    return '—'
  }
  if (val === null) {
    return 'null'
  }
  if (typeof val === 'boolean' || typeof val === 'number') {
    return String(val)
  }
  if (typeof val === 'string') {
    return val.length > 160 ? `${val.slice(0, 157)}…` : val
  }
  if (Array.isArray(val)) {
    if (val.length === 0) {
      return '[]'
    }
    if (val.length > 8) {
      const head = val
        .slice(0, 4)
        .map((x) => formatOmGlobalValue(x))
        .join(', ')
      return `[${val.length} items] ${head}…`
    }
    try {
      return JSON.stringify(val)
    } catch {
      return `[${val.length} items]`
    }
  }
  if (typeof val === 'object') {
    try {
      const s = JSON.stringify(val)
      return s.length > 280 ? `${s.slice(0, 277)}…` : s
    } catch {
      return String(val)
    }
  }
  return String(val)
}

export function snapshotNxtGlobals(globalVal: unknown): Array<{
  key: string
  description: string
  raw: unknown
  valueText: string
  missing: boolean
}> {
  return NXT_GLOBAL_MANIFEST.map(({ key, description }) => {
    const raw = readFirmwareGlobal(globalVal, key)
    const missing = raw === undefined
    return {
      key,
      description,
      raw,
      valueText: missing ? '(not in object model)' : formatOmGlobalValue(raw),
      missing
    }
  })
}
