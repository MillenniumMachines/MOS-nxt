/**
 * Calibration tab wizard session (DWC plugin settings — not firmware globals).
 * Survives leave-/nxt remounts; durable M92/M425/D still use Apply + Save.
 */

import { PluginDataType, setPluginData } from '../compat/dwcStore'
import type { TravelClassification, TravelLeg } from './nxtCalibrationMath'
import type { Nxt123FaceId, Nxt123FacePairId } from './nxtCalibrationMath'
import { NXT_123_AXIS_DEFAULTS } from './nxtCalibrationMath'
import { isFactoryZeroDeflection } from './nxtUserVarsPersistence'

export const NXT_CAL_SESSION_KEY = 'nxtCalSession'
export const NXT_CAL_SESSION_PLUGIN = 'nxt'
export const NXT_CAL_SESSION_VERSION = 1 as const
/** Match OM D vs last confirmed fingerprint (mm). */
export const NXT_CAL_DEFLECTION_EPS = 1e-5

export type NxtCalAxisLetter = 'X' | 'Y' | 'Z' | 'A'

export type NxtCalSessionV1 = {
  v: typeof NXT_CAL_SESSION_VERSION
  selectedAxis: NxtCalAxisLetter
  openPhase: string | null
  calMode: 'manual' | 'probe'
  sessionDeflectionOk: boolean
  needsDeflectionRecheck: boolean
  /** Last OM / applied D vector the operator confirmed. */
  confirmedDeflection: number[] | null
  travelLegs: TravelLeg[]
  travelClassification: TravelClassification | null
  p1FaceAway: 1 | -1
  p1Repeat3x: boolean
  p1Commanded: number | null
  p4DiveMm: number
  defMeasuredX: number | null
  defMeasuredY: number | null
  defProposedZEdit: number | null
  blockFacePair: Nxt123FacePairId
  p2Face1Left: number | null
  p2Face1Right: number | null
  p2Face2Left: number | null
  p2Face2Right: number | null
  p2Measured1: number | null
  p2Measured2: number | null
  p2UseManualSpans: boolean
  probeTarget: number | null
  blMeanPos: number | null
  blMeanNeg: number | null
  blSamplesPos: number[]
  blSamplesNeg: number[]
  showScatter: boolean
  blockDeflectFace: Nxt123FaceId
  defMeasured: number | null
  prevSteps: number | null
  prevBacklash: number | null
  prevDeflection: number[] | null
  pendingSteps: Partial<Record<NxtCalAxisLetter, number>>
  pendingBacklash: Partial<Record<NxtCalAxisLetter, number>>
  pendingDeflection: number[] | null
  rotaryWcs: number
  aCommanded: number | null
  aActual: number | null
}

/** Fields on CalibrationPanel that participate in the session blob. */
export type NxtCalSessionPanelFields = {
  selectedAxis: NxtCalAxisLetter
  openPhase: string | null
  calMode: 'manual' | 'probe'
  sessionDeflectionOk: boolean
  needsDeflectionRecheck: boolean
  confirmedDeflection: number[] | null
  travelLegs: TravelLeg[]
  travelClassification: TravelClassification | null
  p1FaceAway: 1 | -1
  p1Repeat3x: boolean
  p1Commanded: number | null
  p4DiveMm: number
  defMeasuredX: number | null
  defMeasuredY: number | null
  defProposedZEdit: number | null
  blockFacePair: Nxt123FacePairId
  p2Face1Left: number | null
  p2Face1Right: number | null
  p2Face2Left: number | null
  p2Face2Right: number | null
  p2Measured1: number | null
  p2Measured2: number | null
  p2UseManualSpans: boolean
  probeTarget: number | null
  blMeanPos: number | null
  blMeanNeg: number | null
  blSamplesPos: number[]
  blSamplesNeg: number[]
  showScatter: boolean
  blockDeflectFace: Nxt123FaceId
  defMeasured: number | null
  prevSteps: number | null
  prevBacklash: number | null
  prevDeflection: number[] | null
  pendingSteps: Partial<Record<NxtCalAxisLetter, number>>
  pendingBacklash: Partial<Record<NxtCalAxisLetter, number>>
  pendingDeflection: number[] | null
  rotaryWcs: number
  aCommanded: number | null
  aActual: number | null
}

export function emptyNxtCalSession(): NxtCalSessionV1 {
  return {
    v: NXT_CAL_SESSION_VERSION,
    selectedAxis: 'X',
    openPhase: '1',
    calMode: 'manual',
    sessionDeflectionOk: false,
    needsDeflectionRecheck: false,
    confirmedDeflection: null,
    travelLegs: [],
    travelClassification: null,
    p1FaceAway: 1,
    p1Repeat3x: false,
    p1Commanded: NXT_123_AXIS_DEFAULTS.X.p1Commanded,
    p4DiveMm: 10,
    defMeasuredX: null,
    defMeasuredY: null,
    defProposedZEdit: null,
    blockFacePair: NXT_123_AXIS_DEFAULTS.X.facePair,
    p2Face1Left: null,
    p2Face1Right: null,
    p2Face2Left: null,
    p2Face2Right: null,
    p2Measured1: null,
    p2Measured2: null,
    p2UseManualSpans: false,
    probeTarget: null,
    blMeanPos: null,
    blMeanNeg: null,
    blSamplesPos: [],
    blSamplesNeg: [],
    showScatter: false,
    blockDeflectFace: NXT_123_AXIS_DEFAULTS.X.primaryFace,
    defMeasured: null,
    prevSteps: null,
    prevBacklash: null,
    prevDeflection: null,
    pendingSteps: {},
    pendingBacklash: {},
    pendingDeflection: null,
    rotaryWcs: 54,
    aCommanded: 90,
    aActual: null
  }
}

function cloneNumArr(v: number[] | null | undefined): number[] | null {
  if (v == null || !Array.isArray(v)) return null
  return v.map((n: number) => Number(n))
}

function clonePending(
  p: Partial<Record<NxtCalAxisLetter, number>> | null | undefined
): Partial<Record<NxtCalAxisLetter, number>> {
  if (p == null || typeof p !== 'object') return {}
  const out: Partial<Record<NxtCalAxisLetter, number>> = {}
  for (const k of ['X', 'Y', 'Z', 'A'] as NxtCalAxisLetter[]) {
    const n = p[k]
    if (n != null && Number.isFinite(Number(n))) out[k] = Number(n)
  }
  return out
}

export function deflectionVectorsMatch(
  a: number[] | null | undefined,
  b: number[] | null | undefined,
  eps: number = NXT_CAL_DEFLECTION_EPS
): boolean {
  if (a == null || b == null || a.length < 3 || b.length < 3) return false
  for (let i = 0; i < 3; i++) {
    if (!Number.isFinite(a[i]) || !Number.isFinite(b[i])) return false
    if (Math.abs(a[i] - b[i]) > eps) return false
  }
  return true
}

/**
 * After restore: honor prior Confirm deflection when OM D still matches fingerprint.
 * Does not clear needsDeflectionRecheck (post-M92).
 */
export function reconcileDeflectionConfirm(args: {
  liveOm: number[] | null
  confirmedDeflection: number[] | null
  sessionDeflectionOk: boolean
  needsDeflectionRecheck: boolean
}): { sessionDeflectionOk: boolean; needsDeflectionRecheck: boolean } {
  if (args.needsDeflectionRecheck) {
    return { sessionDeflectionOk: false, needsDeflectionRecheck: true }
  }
  const live = args.liveOm
  if (live == null || live.length < 3 || isFactoryZeroDeflection(live)) {
    return { sessionDeflectionOk: false, needsDeflectionRecheck: false }
  }
  // Prior confirm/apply sticks when OM D still matches the fingerprint
  if (deflectionVectorsMatch(live, args.confirmedDeflection)) {
    return { sessionDeflectionOk: true, needsDeflectionRecheck: false }
  }
  return { sessionDeflectionOk: false, needsDeflectionRecheck: false }
}

export function pickCalSessionFromPanel(panel: NxtCalSessionPanelFields): NxtCalSessionV1 {
  return {
    v: NXT_CAL_SESSION_VERSION,
    selectedAxis: panel.selectedAxis,
    openPhase: panel.openPhase,
    calMode: panel.calMode,
    sessionDeflectionOk: panel.sessionDeflectionOk,
    needsDeflectionRecheck: panel.needsDeflectionRecheck,
    confirmedDeflection: cloneNumArr(panel.confirmedDeflection),
    travelLegs: (panel.travelLegs ?? []).map((l: TravelLeg) => ({
      commanded: Number(l.commanded),
      measured: Number(l.measured)
    })),
    travelClassification: panel.travelClassification
      ? ({ ...panel.travelClassification } as TravelClassification)
      : null,
    p1FaceAway: panel.p1FaceAway === -1 ? -1 : 1,
    p1Repeat3x: !!panel.p1Repeat3x,
    p1Commanded: panel.p1Commanded,
    p4DiveMm: Number(panel.p4DiveMm) || 10,
    defMeasuredX: panel.defMeasuredX,
    defMeasuredY: panel.defMeasuredY,
    defProposedZEdit: panel.defProposedZEdit,
    blockFacePair: panel.blockFacePair,
    p2Face1Left: panel.p2Face1Left,
    p2Face1Right: panel.p2Face1Right,
    p2Face2Left: panel.p2Face2Left,
    p2Face2Right: panel.p2Face2Right,
    p2Measured1: panel.p2Measured1,
    p2Measured2: panel.p2Measured2,
    p2UseManualSpans: !!panel.p2UseManualSpans,
    probeTarget: panel.probeTarget,
    blMeanPos: panel.blMeanPos,
    blMeanNeg: panel.blMeanNeg,
    blSamplesPos: [...(panel.blSamplesPos ?? [])],
    blSamplesNeg: [...(panel.blSamplesNeg ?? [])],
    showScatter: !!panel.showScatter,
    blockDeflectFace: panel.blockDeflectFace,
    defMeasured: panel.defMeasured,
    prevSteps: panel.prevSteps,
    prevBacklash: panel.prevBacklash,
    prevDeflection: cloneNumArr(panel.prevDeflection),
    pendingSteps: clonePending(panel.pendingSteps),
    pendingBacklash: clonePending(panel.pendingBacklash),
    pendingDeflection: cloneNumArr(panel.pendingDeflection),
    rotaryWcs: Number(panel.rotaryWcs) || 54,
    aCommanded: panel.aCommanded,
    aActual: panel.aActual
  }
}

export function applyCalSessionToPanel(
  panel: NxtCalSessionPanelFields,
  snap: NxtCalSessionV1
): void {
  panel.selectedAxis = snap.selectedAxis
  panel.openPhase = snap.openPhase
  panel.calMode = snap.calMode
  panel.sessionDeflectionOk = snap.sessionDeflectionOk
  panel.needsDeflectionRecheck = snap.needsDeflectionRecheck
  panel.confirmedDeflection = cloneNumArr(snap.confirmedDeflection)
  panel.travelLegs = (snap.travelLegs ?? []).map((l: TravelLeg) => ({
    commanded: Number(l.commanded),
    measured: Number(l.measured)
  }))
  panel.travelClassification = snap.travelClassification
    ? ({ ...snap.travelClassification } as TravelClassification)
    : null
  panel.p1FaceAway = snap.p1FaceAway === -1 ? -1 : 1
  panel.p1Repeat3x = !!snap.p1Repeat3x
  panel.p1Commanded = snap.p1Commanded
  panel.p4DiveMm = Number(snap.p4DiveMm) || 10
  panel.defMeasuredX = snap.defMeasuredX
  panel.defMeasuredY = snap.defMeasuredY
  panel.defProposedZEdit = snap.defProposedZEdit
  panel.blockFacePair = snap.blockFacePair
  panel.p2Face1Left = snap.p2Face1Left
  panel.p2Face1Right = snap.p2Face1Right
  panel.p2Face2Left = snap.p2Face2Left
  panel.p2Face2Right = snap.p2Face2Right
  panel.p2Measured1 = snap.p2Measured1
  panel.p2Measured2 = snap.p2Measured2
  panel.p2UseManualSpans = !!snap.p2UseManualSpans
  panel.probeTarget = snap.probeTarget
  panel.blMeanPos = snap.blMeanPos
  panel.blMeanNeg = snap.blMeanNeg
  panel.blSamplesPos = [...(snap.blSamplesPos ?? [])]
  panel.blSamplesNeg = [...(snap.blSamplesNeg ?? [])]
  panel.showScatter = !!snap.showScatter
  panel.blockDeflectFace = snap.blockDeflectFace
  panel.defMeasured = snap.defMeasured
  panel.prevSteps = snap.prevSteps
  panel.prevBacklash = snap.prevBacklash
  panel.prevDeflection = cloneNumArr(snap.prevDeflection)
  panel.pendingSteps = clonePending(snap.pendingSteps)
  panel.pendingBacklash = clonePending(snap.pendingBacklash)
  panel.pendingDeflection = cloneNumArr(snap.pendingDeflection)
  panel.rotaryWcs = Number(snap.rotaryWcs) || 54
  panel.aCommanded = snap.aCommanded
  panel.aActual = snap.aActual
}

/** After Save: drop mid-wizard captures; keep confirm fingerprint / mode / axis / dive. */
export function clearWizardProgressKeepConfirm(panel: NxtCalSessionPanelFields): void {
  panel.travelLegs = []
  panel.travelClassification = null
  panel.defMeasuredX = null
  panel.defMeasuredY = null
  panel.defProposedZEdit = null
  panel.p2Face1Left = null
  panel.p2Face1Right = null
  panel.p2Face2Left = null
  panel.p2Face2Right = null
  panel.p2Measured1 = null
  panel.p2Measured2 = null
  panel.p2UseManualSpans = false
  panel.probeTarget = null
  panel.blMeanPos = null
  panel.blMeanNeg = null
  panel.blSamplesPos = []
  panel.blSamplesNeg = []
  panel.defMeasured = null
  panel.prevSteps = null
  panel.prevBacklash = null
  panel.prevDeflection = null
  panel.pendingSteps = {}
  panel.pendingBacklash = {}
  panel.pendingDeflection = null
  panel.aActual = null
}

function isAxisLetter(v: unknown): v is NxtCalAxisLetter {
  return v === 'X' || v === 'Y' || v === 'Z' || v === 'A'
}

export function normalizeNxtCalSession(raw: unknown): NxtCalSessionV1 | null {
  if (raw == null || typeof raw !== 'object') return null
  const o = raw as Record<string, unknown>
  if (o.v !== NXT_CAL_SESSION_VERSION) return null
  const base = emptyNxtCalSession()
  const axis = o.selectedAxis
  if (isAxisLetter(axis)) base.selectedAxis = axis
  if (o.openPhase === null || typeof o.openPhase === 'string') {
    base.openPhase = o.openPhase as string | null
  }
  if (o.calMode === 'manual' || o.calMode === 'probe') base.calMode = o.calMode
  base.sessionDeflectionOk = !!o.sessionDeflectionOk
  base.needsDeflectionRecheck = !!o.needsDeflectionRecheck
  base.confirmedDeflection = cloneNumArr(o.confirmedDeflection as number[] | null)
  if (Array.isArray(o.travelLegs)) {
    base.travelLegs = o.travelLegs
      .filter((l: unknown) => l != null && typeof l === 'object')
      .map((l: { commanded?: unknown; measured?: unknown }) => ({
        commanded: Number(l.commanded),
        measured: Number(l.measured)
      }))
      .filter(
        (l: TravelLeg) => Number.isFinite(l.commanded) && Number.isFinite(l.measured)
      )
  }
  if (o.travelClassification != null && typeof o.travelClassification === 'object') {
    base.travelClassification = o.travelClassification as TravelClassification
  }
  if (o.p1FaceAway === 1 || o.p1FaceAway === -1) base.p1FaceAway = o.p1FaceAway
  base.p1Repeat3x = !!o.p1Repeat3x
  if (o.p1Commanded == null || typeof o.p1Commanded === 'number') {
    base.p1Commanded = o.p1Commanded as number | null
  }
  if (typeof o.p4DiveMm === 'number' && o.p4DiveMm > 0) base.p4DiveMm = o.p4DiveMm
  for (const k of [
    'defMeasuredX',
    'defMeasuredY',
    'defProposedZEdit',
    'p2Face1Left',
    'p2Face1Right',
    'p2Face2Left',
    'p2Face2Right',
    'p2Measured1',
    'p2Measured2',
    'probeTarget',
    'blMeanPos',
    'blMeanNeg',
    'defMeasured',
    'prevSteps',
    'prevBacklash',
    'aCommanded',
    'aActual'
  ] as const) {
    const val = o[k]
    if (val == null || typeof val === 'number') {
      base[k] = val as number | null
    }
  }
  if (o.blockFacePair === '1x2' || o.blockFacePair === '1x3' || o.blockFacePair === '2x3') {
    base.blockFacePair = o.blockFacePair
  }
  if (o.blockDeflectFace === '1' || o.blockDeflectFace === '2' || o.blockDeflectFace === '3') {
    base.blockDeflectFace = o.blockDeflectFace
  }
  base.p2UseManualSpans = !!o.p2UseManualSpans
  base.showScatter = !!o.showScatter
  if (Array.isArray(o.blSamplesPos)) {
    base.blSamplesPos = o.blSamplesPos.map((n: unknown) => Number(n)).filter((n: number) => Number.isFinite(n))
  }
  if (Array.isArray(o.blSamplesNeg)) {
    base.blSamplesNeg = o.blSamplesNeg.map((n: unknown) => Number(n)).filter((n: number) => Number.isFinite(n))
  }
  base.prevDeflection = cloneNumArr(o.prevDeflection as number[] | null)
  base.pendingSteps = clonePending(o.pendingSteps as Partial<Record<NxtCalAxisLetter, number>>)
  base.pendingBacklash = clonePending(o.pendingBacklash as Partial<Record<NxtCalAxisLetter, number>>)
  base.pendingDeflection = cloneNumArr(o.pendingDeflection as number[] | null)
  if (typeof o.rotaryWcs === 'number') base.rotaryWcs = o.rotaryWcs
  return base
}

export function readNxtCalSession(plugins: unknown): NxtCalSessionV1 | null {
  const raw =
    plugins != null && typeof plugins === 'object'
      ? (plugins as Record<string, Record<string, unknown>>)?.[NXT_CAL_SESSION_PLUGIN]?.[
          NXT_CAL_SESSION_KEY
        ]
      : undefined
  return normalizeNxtCalSession(raw)
}

export function writeNxtCalSession(snapshot: NxtCalSessionV1): void {
  setPluginData(
    NXT_CAL_SESSION_PLUGIN,
    PluginDataType.globalSetting,
    NXT_CAL_SESSION_KEY,
    snapshot
  )
}

export function defaultNxtCalSessionPluginData(): NxtCalSessionV1 {
  return emptyNxtCalSession()
}
