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
    warnings.push('Commanded and actual have different signs — check entries')
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
    warnings.push('Actual and measured spans have different signs — check order of entries')
  }

  const ratio = dActual / dMeasured
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
  return Math.abs(meanPositive - meanNegative)
}

export function meanOf(samples: number[]): number | null {
  if (!samples.length) return null
  const sum = samples.reduce((a, b) => a + b, 0)
  return sum / samples.length
}

export function deflectionFromSpan(measured: number, actual: number): number {
  return (measured - actual) / 2
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
 * Convert dial/probe residual after zero → away D → return into measured travel.
 * R > 0 means ended short of the zeroed surface; measured = commanded − R.
 * Used by M5014 (manual) and G9000 (probe) before classifyTravelCalibration.
 */
export function measuredFromResidual(commanded: number, residual: number): number {
  return commanded - residual
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
/** Max spread of error/commanded to treat as near-proportional → steps. */
const STEPS_REL_RANGE = 0.01

/**
 * Classify 8/16/24 travel results (M5014 / G9000).
 * Legs use measuredFromResidual (commanded − residual).
 * Near-constant |error| → backlash; near-proportional error → steps/mm; else mixed.
 */
export function classifyTravelCalibration(
  legs: TravelLeg[],
  currentSteps: number
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

  const errors = legs.map((l) => l.measured - l.commanded)
  const absErrors = errors.map((e) => Math.abs(e))
  const meanAbsError = absErrors.reduce((a, b) => a + b, 0) / absErrors.length
  const errorRange = Math.max(...absErrors) - Math.min(...absErrors)

  const relativeErrors = legs.map((l) =>
    l.commanded !== 0 ? (l.measured - l.commanded) / l.commanded : 0
  )
  const relativeRange = Math.max(...relativeErrors) - Math.min(...relativeErrors)

  const ratios = legs
    .filter((l) => l.measured !== 0)
    .map((l) => l.commanded / l.measured)
  const meanRatio =
    ratios.length > 0 ? ratios.reduce((a, b) => a + b, 0) / ratios.length : null

  const proposedBacklash = meanAbsError
  const proposedStepsRatio = meanRatio
  const proposedNewSteps =
    meanRatio != null && currentSteps > 0 ? currentSteps * meanRatio : null

  if (proposedNewSteps != null && meanRatio != null) {
    const pct = (meanRatio - 1) * 100
    if (Math.abs(pct) > SOFT_PCT_WARN) {
      warnings.push(`Steps change would be ${pct.toFixed(2)}% (over ±${SOFT_PCT_WARN}% soft limit)`)
    }
  }

  const constantLike = errorRange <= BACKLASH_ABS_RANGE_MM
  const proportionalLike = relativeRange <= STEPS_REL_RANGE

  let kind: TravelClassification['kind'] = 'mixed'
  let summary: string
  if (constantLike && !proportionalLike) {
    kind = 'backlash'
    summary = `Near-constant error (~${meanAbsError.toFixed(4)} mm) → backlash`
  } else if (proportionalLike && !constantLike) {
    kind = 'steps'
    summary = `Near-proportional error → steps/mm (ratio ${meanRatio?.toFixed(6) ?? '—'})`
  } else if (constantLike && proportionalLike) {
    // Both fit (e.g. tiny errors): prefer steps if mean abs error is tiny, else backlash
    if (meanAbsError < 0.02) {
      kind = 'steps'
      summary = 'Errors small and consistent — prefer steps/mm fine-tune'
    } else {
      kind = 'backlash'
      summary = `Near-constant error (~${meanAbsError.toFixed(4)} mm) → backlash`
    }
  } else {
    kind = 'mixed'
    summary =
      'Mixed pattern — review both steps and backlash; apply manually after inspection'
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
  const expected = (800 * (50.8 - 25.4)) / (51.0 - 25.5)
  if (Math.abs(dual.result.newSteps - expected) > 1e-6) {
    throw new Error('dualDimensionStepsCorrection value mismatch')
  }
  const dualNeg = dualDimensionStepsCorrection(800, -50.8, -25.4, -51.0, -25.5)
  if (!dualNeg.result || Math.abs(dualNeg.result.newSteps - expected) > 1e-6) {
    throw new Error('dualDimensionStepsCorrection negative coords failed')
  }
  if (Math.abs(backlashFromMeans(10.05, 10.0) - 0.05) > 1e-9) {
    throw new Error('backlashFromMeans failed')
  }
  if (Math.abs(deflectionFromSpan(25.45, 25.4) - 0.025) > 1e-9) {
    throw new Error('deflectionFromSpan failed')
  }
  if (NXT_123_FACE_PAIRS['1x2'].dim1 !== 25.4 || NXT_123_FACES['3'].mm !== 76.2) {
    throw new Error('1-2-3 block constants mismatch')
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

  const st = classifyTravelCalibration(
    [
      { commanded: 8, measured: 8.2 },
      { commanded: 16, measured: 16.4 },
      { commanded: 24, measured: 24.6 }
    ],
    800
  )
  if (st.kind !== 'steps') throw new Error('classifyTravelCalibration expected steps')

  if (Math.abs(measuredFromResidual(16, 0.2) - 15.8) > 1e-9) {
    throw new Error('measuredFromResidual failed')
  }
  if (Math.abs(measuredFromResidual(8, -0.1) - 8.1) > 1e-9) {
    throw new Error('measuredFromResidual negative residual failed')
  }
}
