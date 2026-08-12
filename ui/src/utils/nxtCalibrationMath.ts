/**
 * Calibration formulas from docs/CALIBRATION.md (steps, backlash, deflection).
 * Commanded/actual/measured may be signed (e.g. negative axis travel or machine coords).
 *
 * Locked 1-2-3 block orientation (all XYZ / A setups):
 *   3″ (76.2 mm) parallel to machine X
 *   2″ (50.8 mm) parallel to machine Y
 *   1″ (25.4 mm) parallel to machine Z (height)
 */

export type StepsCorrectionResult = {
  newSteps: number
  ratio: number
  percentChange: number
}

export type CalibrationWarn = string

/** 1-2-3 block face lengths in mm (1″, 2″, 3″). */
export const NXT_123_BLOCK_MM = {
  inch1: 25.4,
  inch2: 50.8,
  inch3: 76.2
} as const

export type Nxt123FacePairId = '1x2' | '1x3' | '2x3'

export const NXT_123_FACE_PAIRS: Record<
  Nxt123FacePairId,
  { dim1: number; dim2: number; labelKey: string }
> = {
  '1x2': { dim1: NXT_123_BLOCK_MM.inch1, dim2: NXT_123_BLOCK_MM.inch2, labelKey: 'pair1x2' },
  '1x3': { dim1: NXT_123_BLOCK_MM.inch1, dim2: NXT_123_BLOCK_MM.inch3, labelKey: 'pair1x3' },
  '2x3': { dim1: NXT_123_BLOCK_MM.inch2, dim2: NXT_123_BLOCK_MM.inch3, labelKey: 'pair2x3' }
}

export type Nxt123FaceId = '1' | '2' | '3'

export const NXT_123_FACES: Record<Nxt123FaceId, { mm: number; labelKey: string }> = {
  '1': { mm: NXT_123_BLOCK_MM.inch1, labelKey: 'face1' },
  '2': { mm: NXT_123_BLOCK_MM.inch2, labelKey: 'face2' },
  '3': { mm: NXT_123_BLOCK_MM.inch3, labelKey: 'face3' }
}

export type NxtCalAxisLetter = 'X' | 'Y' | 'Z' | 'A'

/**
 * Per-axis defaults for the locked orientation (3″∥X, 2″∥Y, 1″∥Z).
 * Phase 2 pairs include the axis primary length for dual-dimension work.
 */
export const NXT_123_AXIS_DEFAULTS: Record<
  NxtCalAxisLetter,
  {
    primaryFace: Nxt123FaceId
    primaryMm: number
    facePair: Nxt123FacePairId
    /** Phase 1 commanded travel (mm); A uses degrees for rotary steps math. */
    p1Commanded: number
  }
> = {
  X: {
    primaryFace: '3',
    primaryMm: NXT_123_BLOCK_MM.inch3,
    facePair: '2x3',
    p1Commanded: NXT_123_BLOCK_MM.inch3
  },
  Y: {
    primaryFace: '2',
    primaryMm: NXT_123_BLOCK_MM.inch2,
    facePair: '1x2',
    p1Commanded: NXT_123_BLOCK_MM.inch2
  },
  Z: {
    primaryFace: '1',
    primaryMm: NXT_123_BLOCK_MM.inch1,
    facePair: '1x2',
    p1Commanded: NXT_123_BLOCK_MM.inch1
  },
  A: {
    primaryFace: '3',
    primaryMm: NXT_123_BLOCK_MM.inch3,
    facePair: '2x3',
    p1Commanded: 90
  }
}

export function nxt123DefaultsForAxis(axis: NxtCalAxisLetter) {
  return NXT_123_AXIS_DEFAULTS[axis]
}

const SOFT_PCT_WARN = 5

function isFiniteNumber(n: number): boolean {
  return typeof n === 'number' && Number.isFinite(n)
}

export function roughStepsCorrection(
  currentSteps: number,
  commanded: number,
  actual: number
): { result: StepsCorrectionResult | null; errors: string[]; warnings: CalibrationWarn[] } {
  const errors: string[] = []
  const warnings: CalibrationWarn[] = []
  if (!(currentSteps > 0)) errors.push('Current steps must be > 0')
  if (!isFiniteNumber(commanded) || commanded === 0) {
    errors.push('Commanded distance must be a non-zero number (may be negative)')
  }
  if (!isFiniteNumber(actual) || actual === 0) {
    errors.push('Actual measured distance must be a non-zero number (may be negative)')
  }
  if (errors.length) return { result: null, errors, warnings }

  if (Math.sign(commanded) !== Math.sign(actual)) {
    errors.push('Commanded and actual must have the same sign — check entries')
    return { result: null, errors, warnings }
  }

  const ratio = commanded / actual
  const newSteps = currentSteps * ratio
  const percentChange = (ratio - 1) * 100
  if (Math.abs(percentChange) > SOFT_PCT_WARN) {
    warnings.push(`Change is ${percentChange.toFixed(2)}% (over ±${SOFT_PCT_WARN}% soft limit)`)
  }
  return {
    result: { newSteps, ratio, percentChange },
    errors,
    warnings
  }
}

export function dualDimensionStepsCorrection(
  currentSteps: number,
  actual1: number,
  actual2: number,
  measured1: number,
  measured2: number
): { result: StepsCorrectionResult | null; errors: string[]; warnings: CalibrationWarn[] } {
  const errors: string[] = []
  const warnings: CalibrationWarn[] = []
  if (!(currentSteps > 0)) errors.push('Current steps must be > 0')
  for (const [label, n] of [
    ['Actual 1', actual1],
    ['Actual 2', actual2],
    ['Measured 1', measured1],
    ['Measured 2', measured2]
  ] as const) {
    if (!isFiniteNumber(n)) errors.push(`${label} must be a finite number (may be negative)`)
  }
  if (errors.length) return { result: null, errors, warnings }

  const dActual = actual2 - actual1
  const dMeasured = measured2 - measured1
  if (dActual === 0) errors.push('Actual span (size2 − size1) must be non-zero')
  if (dMeasured === 0) errors.push('Measured span must be non-zero')
  if (errors.length) return { result: null, errors, warnings }

  if (Math.sign(dActual) !== Math.sign(dMeasured)) {
    errors.push('Actual and measured spans must have the same sign — check face order')
    return { result: null, errors, warnings }
  }

  // Long measured span ⇒ M92 too low ⇒ increase steps
  const ratio = dMeasured / dActual
  const newSteps = currentSteps * ratio
  const percentChange = (ratio - 1) * 100
  if (Math.abs(percentChange) > SOFT_PCT_WARN) {
    warnings.push(`Change is ${percentChange.toFixed(2)}% (over ±${SOFT_PCT_WARN}% soft limit)`)
  }
  return {
    result: { newSteps, ratio, percentChange },
    errors,
    warnings
  }
}

export function backlashFromMeans(meanPositive: number, meanNegative: number): number {
  // Same surface, opposite free-space approach directions: deflection/tip cancel
  // in the difference after G6512 compensation; separation ≈ backlash.
  // Not valid as |leftFace − rightFace| on a solid block (that is a span).
  return Math.abs(meanPositive - meanNegative)
}

export function meanOf(samples: number[]): number | null {
  if (!samples.length) return null
  const sum = samples.reduce((a, b) => a + b, 0)
  return sum / samples.length
}

/** External span from two opposing face contacts on one block dimension. */
export function spanFromFaces(left: number, right: number): number {
  return Math.abs(right - left)
}

/**
 * External span shortfall Δ = actual − measured.
 * With G6512 tip on: Δ = 2[(R − R_true) + (D_phys − D)].
 */
export function externalSpanShortfall(measured: number, actual: number): number {
  return actual - measured
}

/** Ball diameter implied by configured tip radius (confirmation readout). */
export function probeTipDiameterMm(radiusMm: number): number {
  return 2 * radiusMm
}

/** Typical max physical stylus deflection (mm); above this → tip / setup issue. */
export const IMPLAUSIBLE_EXTERNAL_DEFLECTION_MM = 0.5

/**
 * Configured tip radius that looks like a common ball *diameter* entered as radius
 * (e.g. 2 mm for a 2 mm tip → true R = 1).
 */
export const SUSPECT_TIP_DIAMETER_AS_RADIUS_MM = 2.0

export function implausibleExternalDeflection(
  proposedD: number,
  limitMm: number = IMPLAUSIBLE_EXTERNAL_DEFLECTION_MM
): boolean {
  return Number.isFinite(proposedD) && Math.abs(proposedD) > limitMm
}

export function suspectTipDiameterAsRadius(
  tipRadiusMm: number,
  thresholdMm: number = SUSPECT_TIP_DIAMETER_AS_RADIUS_MM
): boolean {
  return Number.isFinite(tipRadiusMm) && tipRadiusMm >= thresholdMm
}

/**
 * Equivalent tip-radius overstatement if shortfall were pure tip error (D≈D_phys):
 *   R_ε ≈ Δ / 2
 */
export function tipRadiusErrorFromShortfall(
  delta: number,
  assumedPhysD = 0
): number {
  return delta / 2 - assumedPhysD
}

/**
 * External-block residual deflection update (XY spans — Phase 1 / M5017).
 * Span identity (G6512 tip on): S = L + 2(R_true − R) + 2(D − D_phys).
 * With tip correct: measured ≈ actual − 2×D_residual →
 *   newD = currentD + (actual − measured) / 2
 *
 * Not used for Z: Z deflection is discarded for now (G6512 Z = raw trigger).
 * G6512 Z does not apply tip radius or deflection.
 */
export function deflectionFromSpan(
  measured: number,
  actual: number,
  currentDeflection = 0
): { result: number | null; errors: string[]; warnings: CalibrationWarn[] } {
  const errors: string[] = []
  const warnings: CalibrationWarn[] = []
  if (!isFiniteNumber(measured)) errors.push('Measured span must be a finite number')
  if (!isFiniteNumber(actual)) errors.push('Actual span must be a finite number')
  if (!isFiniteNumber(currentDeflection)) errors.push('Current deflection must be a finite number')
  if (errors.length) return { result: null, errors, warnings }

  const next = currentDeflection + (actual - measured) / 2
  if (next < 0) {
    warnings.push(
      'Computed deflection is negative — check tip radius, span entries, or approach setup'
    )
  } else if (implausibleExternalDeflection(next)) {
    warnings.push(
      'Computed deflection is implausibly large — check tip radius (radius, not diameter)'
    )
  }
  return { result: next, errors, warnings }
}

export function stdDev(samples: number[]): number | null {
  if (samples.length < 2) return null
  const m = meanOf(samples)
  if (m == null) return null
  const v = samples.reduce((acc, x) => acc + (x - m) ** 2, 0) / (samples.length - 1)
  return Math.sqrt(v)
}

export type TravelLeg = { commanded: number; measured: number }

/**
 * Default leadscrew pitch for Millennium Machines linear axes (TR8×8 = 8 mm/rev).
 * Travel calibration legs are 1× / 2× / 3× this lead.
 */
export const DEFAULT_LEAD_SCREW_MM = 8

/** Commanded travel distances for Phase 1 / G9000: [lead, 2×lead, 3×lead]. */
export function travelCommandedLegs(
  leadMm: number = DEFAULT_LEAD_SCREW_MM
): [number, number, number] {
  return [leadMm, leadMm * 2, leadMm * 3]
}

/**
 * Nominal steps/mm hint for a leadscrew axis:
 * (motorSteps × microsteps × gear) / leadMm
 * e.g. 200 × 32 × 1 / 8 = 800
 */
export function nominalStepsPerMm(
  microsteps: number,
  gear = 1,
  leadMm: number = DEFAULT_LEAD_SCREW_MM,
  motorSteps = 200
): number {
  if (!(microsteps > 0) || !(gear > 0) || !(leadMm > 0) || !(motorSteps > 0)) {
    return NaN
  }
  return (motorSteps * microsteps * gear) / leadMm
}

/**
 * Convert dial/probe residual after zero → away D → return into measured travel.
 * R > 0 means ended short of the zeroed surface; measured = commanded − R.
 * Used by M5014 (manual) and G9000 (probe) before classifyTravelCalibration.
 */
export function measuredFromResidual(commanded: number, residual: number): number {
  return commanded - residual
}

/**
 * G9000 probe travel residual on one face (same geometric approach twice).
 * R = (hit1 − hit0) × dirToward, with dirToward = ±1 toward the surface.
 *
 * Same approach direction + speed ⇒ tip radius and stylus deflection cancel in R.
 * With mechanical backlash b and no M425: hit1 ≈ hit0 + dirToward×b ⇒ R ≈ b > 0
 * (machine reads past the true surface on the second hit after reversing onto it).
 */
export function probeTravelResidual(
  hit0: number,
  hit1: number,
  dirToward: 1 | -1
): number {
  return (hit1 - hit0) * dirToward
}

export type TravelClassification = {
  kind: 'backlash' | 'steps' | 'mixed'
  errors: number[]
  absErrors: number[]
  errorRange: number
  meanAbsError: number
  relativeErrors: number[]
  relativeRange: number
  proposedBacklash: number | null
  proposedStepsRatio: number | null
  proposedNewSteps: number | null
  summary: string
  warnings: CalibrationWarn[]
}

/** Max spread of |error| (mm) to treat as near-constant → backlash. */
const BACKLASH_ABS_RANGE_MM = 0.05
/** Ignore tiny intercept when error is mostly distance-proportional. */
const BACKLASH_INTERCEPT_MIN_MM = 0.005

/**
 * Least-squares fit: error ≈ c + k × commanded.
 * c is the distance-independent lost motion (backlash); k absorbs growth with travel
 * (e.g. the extra residual often seen on the 24 mm leg).
 */
export function fitTravelErrorVsDistance(
  legs: TravelLeg[],
  errors: number[]
): { intercept: number; slope: number } {
  const n = legs.length
  if (n < 2 || errors.length !== n) {
    return { intercept: 0, slope: 0 }
  }
  let sumD = 0
  let sumE = 0
  let sumDD = 0
  let sumDE = 0
  for (let i = 0; i < n; i++) {
    const d = legs[i].commanded
    const e = errors[i]
    sumD += d
    sumE += e
    sumDD += d * d
    sumDE += d * e
  }
  const denom = n * sumDD - sumD * sumD
  const slope = Math.abs(denom) < 1e-12 ? 0 : (n * sumDE - sumD * sumE) / denom
  const intercept = (sumE - slope * sumD) / n
  return { intercept, slope }
}

/**
 * Classify travel results (M5014 / G9000) — typically TR8x8 legs 8/16/24.
 * Round-trip / same-face tests isolate lost motion (backlash), not steps/mm.
 * M425 proposal uses the constant intercept of error-vs-distance — not mean |error| —
 * so a larger residual on the longest leg does not inflate backlash.
 * Never proposes M92 — use Phase 3 dual-dimension spans for steps.
 */
export function classifyTravelCalibration(
  legs: TravelLeg[],
  _currentSteps: number
): TravelClassification {
  const warnings: CalibrationWarn[] = []
  if (legs.length < 2) {
    return {
      kind: 'mixed',
      errors: [],
      absErrors: [],
      errorRange: 0,
      meanAbsError: 0,
      relativeErrors: [],
      relativeRange: 0,
      proposedBacklash: null,
      proposedStepsRatio: null,
      proposedNewSteps: null,
      summary: 'Need at least two travel legs',
      warnings
    }
  }

  const errors = legs.map((l: TravelLeg) => l.measured - l.commanded)
  const absErrors = errors.map((e: number) => Math.abs(e))
  const meanAbsError = absErrors.reduce((a: number, b: number) => a + b, 0) / absErrors.length
  const errorRange = Math.max(...absErrors) - Math.min(...absErrors)

  const relativeErrors = legs.map((l: TravelLeg) =>
    l.commanded !== 0 ? (l.measured - l.commanded) / l.commanded : 0
  )
  const relativeRange = Math.max(...relativeErrors) - Math.min(...relativeErrors)

  const { intercept, slope } = fitTravelErrorVsDistance(legs, errors)
  const dMin = Math.min(...legs.map((l: TravelLeg) => l.commanded))
  const dMax = Math.max(...legs.map((l: TravelLeg) => l.commanded))
  const distanceComponent = Math.abs(slope) * (dMax - dMin)
  const constantLost = Math.abs(intercept)

  const constantLike =
    errorRange <= BACKLASH_ABS_RANGE_MM && distanceComponent <= BACKLASH_ABS_RANGE_MM

  const proposedStepsRatio = null
  const proposedNewSteps = null
  let proposedBacklash: number | null = constantLost
  if (!constantLike && constantLost < BACKLASH_INTERCEPT_MIN_MM) {
    proposedBacklash = null
  }

  let kind: TravelClassification['kind'] = 'mixed'
  let summary: string
  const legLabel = legs.map((l: TravelLeg) => String(l.commanded)).join('/')
  if (constantLike) {
    kind = 'backlash'
    summary =
      `Near-constant lost motion (~${constantLost.toFixed(4)} mm) → M425 backlash` +
      ` [${legLabel} err ${errors.map((e: number) => e.toFixed(3)).join(', ')}]`
  } else {
    kind = 'mixed'
    const cStr = constantLost.toFixed(4)
    const dStr = distanceComponent.toFixed(4)
    summary =
      `Constant ~${cStr} mm + distance-varying ~${dStr} mm over travel — ` +
      `M425 uses constant only; Phase 2 for steps/mm` +
      ` [${legLabel} err ${errors.map((e: number) => e.toFixed(3)).join(', ')}]`
  }

  if (meanAbsError > (SOFT_PCT_WARN / 100) * DEFAULT_LEAD_SCREW_MM) {
    warnings.push('Large mean travel error — verify probe/dial setup before applying M425')
  }
  if (distanceComponent > BACKLASH_ABS_RANGE_MM || relativeRange > 0.05) {
    warnings.push(
      'Error grows with travel distance — constant intercept used for M425; check Phase 2 for steps/mm'
    )
  }

  return {
    kind,
    errors,
    absErrors,
    errorRange,
    meanAbsError,
    relativeErrors,
    relativeRange,
    proposedBacklash,
    proposedStepsRatio,
    proposedNewSteps,
    summary,
    warnings
  }
}

/** Self-test for node/tsx smoke. */
export function runNxtCalibrationMathSelfTest(): void {
  const rough = roughStepsCorrection(800, 100, 99)
  if (!rough.result || Math.abs(rough.result.newSteps - (800 * 100) / 99) > 1e-6) {
    throw new Error('roughStepsCorrection failed')
  }
  const roughNeg = roughStepsCorrection(800, -100, -99)
  if (!roughNeg.result || Math.abs(roughNeg.result.newSteps - (800 * 100) / 99) > 1e-6) {
    throw new Error('roughStepsCorrection negative travel failed')
  }
  const dual = dualDimensionStepsCorrection(800, 25.4, 50.8, 25.5, 51.0)
  if (!dual.result) throw new Error('dualDimensionStepsCorrection failed')
  const expected = (800 * (51.0 - 25.5)) / (50.8 - 25.4)
  if (Math.abs(dual.result.newSteps - expected) > 1e-6) {
    throw new Error('dualDimensionStepsCorrection value mismatch')
  }
  const dualLong = dualDimensionStepsCorrection(800, 25.4, 50.8, 50.8, 101.6)
  if (!dualLong.result || Math.abs(dualLong.result.newSteps - 1600) > 1e-6) {
    throw new Error('dualDimensionStepsCorrection 2x long should double steps')
  }
  const dualNeg = dualDimensionStepsCorrection(800, -50.8, -25.4, -51.0, -25.5)
  if (!dualNeg.result || Math.abs(dualNeg.result.newSteps - expected) > 1e-6) {
    throw new Error('dualDimensionStepsCorrection negative coords failed')
  }
  const dualSignErr = dualDimensionStepsCorrection(800, 25.4, 50.8, 25.5, -51.0)
  if (dualSignErr.result != null || dualSignErr.errors.length === 0) {
    throw new Error('dualDimensionStepsCorrection should reject opposite span signs')
  }
  const roughSignErr = roughStepsCorrection(800, 100, -99)
  if (roughSignErr.result != null || roughSignErr.errors.length === 0) {
    throw new Error('roughStepsCorrection should reject opposite signs')
  }
  if (Math.abs(spanFromFaces(0, 76.2) - 76.2) > 1e-9) {
    throw new Error('spanFromFaces failed')
  }
  if (Math.abs(backlashFromMeans(10.05, 10.0) - 0.05) > 1e-9) {
    throw new Error('backlashFromMeans failed')
  }
  const defl0 = deflectionFromSpan(76.15, 76.2, 0)
  if (!defl0.result || Math.abs(defl0.result - 0.025) > 1e-9) {
    throw new Error('deflectionFromSpan external first-cal failed')
  }
  const deflRecheck = deflectionFromSpan(76.2, 76.2, 0.025)
  if (!deflRecheck.result || Math.abs(deflRecheck.result - 0.025) > 1e-9) {
    throw new Error('deflectionFromSpan residual recheck failed')
  }
  const deflBad = deflectionFromSpan(76.3, 76.2, 0)
  if (!deflBad.result || deflBad.result >= 0 || deflBad.warnings.length === 0) {
    throw new Error('deflectionFromSpan should warn on negative result')
  }
  // Confirmed diameter-as-radius case: R=2, R_true=1, spans 73.466 / 48.265
  const dxRun = externalSpanShortfall(73.466, NXT_123_BLOCK_MM.inch3)
  const dyRun = externalSpanShortfall(48.265, NXT_123_BLOCK_MM.inch2)
  if (Math.abs(dxRun - 2.734) > 1e-9 || Math.abs(dyRun - 2.535) > 1e-9) {
    throw new Error('externalSpanShortfall M5017 sample mismatch')
  }
  const tipShare = 2 * (2 - 1) // 2×R_ε for R=2 vs R_true=1
  if (Math.abs(tipShare - 2) > 1e-9) {
    throw new Error('tip shortfall share should be 2 mm')
  }
  const leftoverDx = tipRadiusErrorFromShortfall(dxRun - tipShare)
  const leftoverDy = tipRadiusErrorFromShortfall(dyRun - tipShare)
  if (Math.abs(leftoverDx - 0.367) > 1e-9 || Math.abs(leftoverDy - 0.2675) > 1e-9) {
    throw new Error('leftover D after tip peel mismatch')
  }
  if (!suspectTipDiameterAsRadius(2) || suspectTipDiameterAsRadius(1)) {
    throw new Error('suspectTipDiameterAsRadius threshold failed')
  }
  if (Math.abs(probeTipDiameterMm(1) - 2) > 1e-9 || Math.abs(probeTipDiameterMm(2) - 4) > 1e-9) {
    throw new Error('probeTipDiameterMm failed')
  }
  const deflModest = deflectionFromSpan(76.0, 76.2, 0)
  if (
    !deflModest.result ||
    Math.abs(deflModest.result - 0.1) > 1e-9 ||
    implausibleExternalDeflection(deflModest.result) ||
    deflModest.warnings.some((w: string) => w.includes('implausibly'))
  ) {
    throw new Error('deflectionFromSpan should not warn under 0.5 mm')
  }
  const deflHuge = deflectionFromSpan(73.466, 76.2, 0)
  if (
    !deflHuge.result ||
    !implausibleExternalDeflection(deflHuge.result) ||
    deflHuge.warnings.length === 0
  ) {
    throw new Error('deflectionFromSpan should warn on implausible D')
  }
  if (NXT_123_FACE_PAIRS['1x2'].dim1 !== 25.4 || NXT_123_FACES['3'].mm !== 76.2) {
    throw new Error('1-2-3 block constants mismatch')
  }
  const legs = travelCommandedLegs()
  if (legs[0] !== 8 || legs[1] !== 16 || legs[2] !== 24) {
    throw new Error('travelCommandedLegs TR8x8 mismatch')
  }
  if (Math.abs(nominalStepsPerMm(32) - 800) > 1e-9) {
    throw new Error('nominalStepsPerMm 32µstep TR8x8 should be 800')
  }
  if (
    NXT_123_AXIS_DEFAULTS.X.primaryMm !== 76.2 ||
    NXT_123_AXIS_DEFAULTS.Y.primaryMm !== 50.8 ||
    NXT_123_AXIS_DEFAULTS.Z.primaryMm !== 25.4
  ) {
    throw new Error('1-2-3 axis orientation defaults mismatch')
  }

  const bl = classifyTravelCalibration(
    [
      { commanded: 8, measured: 8.3 },
      { commanded: 16, measured: 16.3 },
      { commanded: 24, measured: 24.3 }
    ],
    800
  )
  if (bl.kind !== 'backlash') throw new Error('classifyTravelCalibration expected backlash')
  if (bl.proposedNewSteps != null) {
    throw new Error('classifyTravelCalibration must not propose steps')
  }
  if (bl.proposedBacklash == null || Math.abs(bl.proposedBacklash - 0.3) > 1e-6) {
    throw new Error('classifyTravelCalibration backlash proposal failed')
  }

  // Constant 0.20 mm + slope −0.005 mm/mm → residuals grow on longer legs.
  // mean |error| = 0.28; M425 must use intercept 0.20, not the mean.
  const split = classifyTravelCalibration(
    [
      { commanded: 8, measured: 7.76 },
      { commanded: 16, measured: 15.72 },
      { commanded: 24, measured: 23.68 }
    ],
    800
  )
  if (split.kind !== 'mixed') throw new Error('classifyTravelCalibration expected mixed (distance term)')
  if (split.proposedNewSteps != null) {
    throw new Error('classifyTravelCalibration mixed must not propose steps')
  }
  if (split.proposedBacklash == null || Math.abs(split.proposedBacklash - 0.2) > 1e-3) {
    throw new Error(
      `classifyTravelCalibration must propose intercept backlash (~0.2), got ${split.proposedBacklash}`
    )
  }
  if (Math.abs(split.meanAbsError - 0.28) > 1e-6) {
    throw new Error('classifyTravelCalibration meanAbsError sanity failed')
  }

  const mixed = classifyTravelCalibration(
    [
      { commanded: 8, measured: 8.2 },
      { commanded: 16, measured: 16.8 },
      { commanded: 24, measured: 24.4 }
    ],
    800
  )
  if (mixed.kind !== 'mixed') throw new Error('classifyTravelCalibration expected mixed')
  if (mixed.proposedNewSteps != null) {
    throw new Error('classifyTravelCalibration mixed must not propose steps')
  }
  // Must not equal naive mean |error| when distance term dominates the spread.
  const mixedMean = (0.2 + 0.8 + 0.4) / 3
  if (mixed.proposedBacklash != null && Math.abs(mixed.proposedBacklash - mixedMean) < 1e-9) {
    throw new Error('classifyTravelCalibration must not use mean |error| as M425 when mixed')
  }

  if (Math.abs(measuredFromResidual(16, 0.2) - 15.8) > 1e-9) {
    throw new Error('measuredFromResidual failed')
  }
  if (Math.abs(measuredFromResidual(8, -0.1) - 8.1) > 1e-9) {
    throw new Error('measuredFromResidual negative residual failed')
  }

  // --- Probe travel backlash (G9000 identity) ---
  // dir=+1: after reverse onto face, hit1 ≈ hit0 + b
  const bProbe = 0.05
  const hit0 = 100
  const rPos = probeTravelResidual(hit0, hit0 + bProbe, 1)
  if (Math.abs(rPos - bProbe) > 1e-9) {
    throw new Error('probeTravelResidual +dir should equal backlash')
  }
  const rNeg = probeTravelResidual(hit0, hit0 - bProbe, -1)
  if (Math.abs(rNeg - bProbe) > 1e-9) {
    throw new Error('probeTravelResidual -dir should equal backlash')
  }
  // Stylus deflection shifts both hits equally → cancels in R
  const deflShift = 0.03
  const rDefl = probeTravelResidual(hit0 - deflShift, hit0 + bProbe - deflShift, 1)
  if (Math.abs(rDefl - bProbe) > 1e-9) {
    throw new Error('probeTravelResidual must cancel common-mode deflection')
  }
  const g9000Legs = [8, 16, 24].map((D) => ({
    commanded: D,
    measured: measuredFromResidual(D, rPos)
  }))
  const g9000Cls = classifyTravelCalibration(g9000Legs, 800)
  if (g9000Cls.kind !== 'backlash') {
    throw new Error('G9000-style constant residual should classify as backlash')
  }
  if (g9000Cls.proposedBacklash == null || Math.abs(g9000Cls.proposedBacklash - bProbe) > 1e-6) {
    throw new Error('G9000-style classify must propose |R| as M425')
  }
}
