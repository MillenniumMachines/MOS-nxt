/**
 * Probe results table helpers: normalize RRF/DWC vector shapes and
 * DWC-refresh snapshot via nxtUiState.lastProbeResults (not nxt-user-vars).
 */
import { PluginDataType, setPluginData } from '../compat/dwcStore'
import {
  formatOmRhs,
  NXT_OM_SET_SCRATCH_PATH,
  type OmSetSender
} from './nxtOmEnsureSet'
import { uploadDwcFile } from './nxtFileUpload'

export const NXT_UI_STATE_PLUGIN = 'nxt'
export const NXT_UI_STATE_KEY = 'nxtUiState'

/** Matches U1–U9 → slots 0–8 (global.nxtProbeResults length). */
export const NXT_PROBE_RESULTS_SLOT_COUNT = 9

export type NxtProbeResultRow = number[] | null

export interface NxtUiStateProbeSlice {
  ready?: boolean
  dialogActive?: boolean
  dialogMessage?: unknown
  dialogResponse?: unknown
  lastProbeResults: NxtProbeResultRow[]
  selectedResultIndex?: number
  /** 1-based WCS (1 = G54 … 9 = G59.3). Drives probing Target WCS. */
  selectedWcs?: number
}

/** Map- or object-safe key lookup (DWC settings.plugins / nested buckets). */
function mapOrObjGet(container: unknown, key: string): unknown {
  if (container == null || typeof container !== 'object') return undefined
  if (container instanceof Map) {
    return container.get(key)
  }
  return (container as Record<string, unknown>)[key]
}

/** Coerce OM/DWC vector (array, Map, or numeric-key object) to number[]. */
export function normalizeOmNumberVector(raw: unknown): number[] | null {
  if (raw == null) return null
  if (Array.isArray(raw)) {
    const out: number[] = []
    for (let i = 0; i < raw.length; i++) {
      const n = Number(raw[i])
      out.push(Number.isFinite(n) ? n : 0)
    }
    return out.length > 0 ? out : null
  }
  if (raw instanceof Map) {
    const vals = Array.from(raw.values()).map((v: unknown) => Number(v))
    if (vals.length === 0) return null
    return vals.map((n: number) => (Number.isFinite(n) ? n : 0))
  }
  if (typeof raw === 'object') {
    const o = raw as Record<string | number, unknown>
    let max = -1
    for (const k of Object.keys(o)) {
      const i = Number(k)
      if (Number.isInteger(i) && i >= 0 && i > max) max = i
    }
    if (max < 0) return null
    const out: number[] = []
    for (let i = 0; i <= max; i++) {
      let v: unknown = o[i]
      if (v === undefined) v = o[String(i)]
      const n = Number(v)
      out.push(Number.isFinite(n) ? n : 0)
    }
    return out
  }
  return null
}

/** Normalize full nxtProbeResults table from OM. */
export function normalizeProbeResultsTable(raw: unknown): NxtProbeResultRow[] {
  if (raw == null) return []
  let rows: unknown[] = []
  if (Array.isArray(raw)) {
    rows = raw
  } else if (raw instanceof Map) {
    rows = Array.from(raw.values())
  } else if (typeof raw === 'object') {
    const o = raw as Record<string | number, unknown>
    let max = -1
    for (const k of Object.keys(o)) {
      const i = Number(k)
      if (Number.isInteger(i) && i >= 0 && i > max) max = i
    }
    for (let i = 0; i <= max; i++) {
      let v: unknown = o[i]
      if (v === undefined) v = o[String(i)]
      rows.push(v ?? null)
    }
  }
  return rows.map((r: unknown) => normalizeOmNumberVector(r))
}

export function probeResultsTableHasData(rows: NxtProbeResultRow[]): boolean {
  return rows.some((r: NxtProbeResultRow) => r != null && r.length >= 3)
}

/** Snapshot-friendly plain rows (null or number[]). */
export function snapshotProbeResults(rows: NxtProbeResultRow[]): NxtProbeResultRow[] {
  return rows.map((r: NxtProbeResultRow) => (r == null ? null : r.slice()))
}

export function readNxtUiState(plugins: unknown): NxtUiStateProbeSlice | null {
  if (plugins == null || typeof plugins !== 'object') return null
  const pluginBucket = mapOrObjGet(plugins, NXT_UI_STATE_PLUGIN)
  if (pluginBucket == null || typeof pluginBucket !== 'object') return null
  const raw = mapOrObjGet(pluginBucket, NXT_UI_STATE_KEY)
  if (raw == null || typeof raw !== 'object' || raw instanceof Map) return null
  const o = raw as Record<string, unknown>
  const last = normalizeProbeResultsTable(o.lastProbeResults)
  const wcsRaw = o.selectedWcs
  const selectedWcs =
    typeof wcsRaw === 'number' && wcsRaw >= 1 && wcsRaw <= 9 ? wcsRaw : 1
  return {
    ready: !!o.ready,
    dialogActive: !!o.dialogActive,
    dialogMessage: o.dialogMessage ?? null,
    dialogResponse: o.dialogResponse ?? null,
    lastProbeResults: last,
    selectedResultIndex:
      typeof o.selectedResultIndex === 'number' ? o.selectedResultIndex : 0,
    selectedWcs
  }
}

export function writeNxtUiProbeResults(
  lastProbeResults: NxtProbeResultRow[],
  plugins: unknown,
  selectedResultIndex?: number
): void {
  const prev = readNxtUiState(plugins)
  const next: NxtUiStateProbeSlice = {
    ready: prev?.ready ?? false,
    dialogActive: prev?.dialogActive ?? false,
    dialogMessage: prev?.dialogMessage ?? null,
    dialogResponse: prev?.dialogResponse ?? null,
    lastProbeResults: snapshotProbeResults(lastProbeResults),
    selectedResultIndex:
      selectedResultIndex !== undefined
        ? selectedResultIndex
        : (prev?.selectedResultIndex ?? 0),
    selectedWcs: prev?.selectedWcs ?? 1
  }
  setPluginData(NXT_UI_STATE_PLUGIN, PluginDataType.globalSetting, NXT_UI_STATE_KEY, next)
}

/** Update only the selected result index in nxtUiState (after a probe cycle). */
export function writeNxtUiSelectedResultIndex(
  selectedResultIndex: number,
  plugins: unknown
): void {
  const prev = readNxtUiState(plugins)
  const next: NxtUiStateProbeSlice = {
    ready: prev?.ready ?? false,
    dialogActive: prev?.dialogActive ?? false,
    dialogMessage: prev?.dialogMessage ?? null,
    dialogResponse: prev?.dialogResponse ?? null,
    lastProbeResults: prev?.lastProbeResults ?? [],
    selectedResultIndex,
    selectedWcs: prev?.selectedWcs ?? 1
  }
  setPluginData(NXT_UI_STATE_PLUGIN, PluginDataType.globalSetting, NXT_UI_STATE_KEY, next)
}

/** 1-based WCS for Probing Cycles / Work offsets / Push to WCS (also slots result index). */
export function writeNxtUiSelectedWcs(selectedWcs: number, plugins: unknown): void {
  const wcs =
    Number.isFinite(selectedWcs) && selectedWcs >= 1 && selectedWcs <= 9
      ? Math.round(selectedWcs)
      : 1
  const prev = readNxtUiState(plugins)
  const next: NxtUiStateProbeSlice = {
    ready: prev?.ready ?? false,
    dialogActive: prev?.dialogActive ?? false,
    dialogMessage: prev?.dialogMessage ?? null,
    dialogResponse: prev?.dialogResponse ?? null,
    lastProbeResults: prev?.lastProbeResults ?? [],
    selectedResultIndex: wcs - 1,
    selectedWcs: wcs
  }
  setPluginData(NXT_UI_STATE_PLUGIN, PluginDataType.globalSetting, NXT_UI_STATE_KEY, next)
}

/**
 * Suggest Push axis flags from a result row.
 * - Single non-zero axis → that axis only (Z = WCS only; X/Y = side surface)
 * - X+Y with Z≈0 → XY (bore/boss); leave Z off so travel keeps start height
 * - All zero but hasData → XY default (never suggest Z-only for travel)
 */
export function suggestPushAxesFromRow(
  row: { x: number; y: number; z: number; a: number; hasData: boolean },
  hasAAxis: boolean
): { x: boolean; y: boolean; z: boolean; a: boolean } {
  if (!row.hasData) {
    return { x: true, y: true, z: false, a: false }
  }
  const nz = (v: number) => Math.abs(v) >= 1e-9
  const xOn = nz(row.x)
  const yOn = nz(row.y)
  const zOn = nz(row.z)
  const aOn = hasAAxis && nz(row.a)
  const count = (xOn ? 1 : 0) + (yOn ? 1 : 0) + (zOn ? 1 : 0)
  // Top surface (Z only) or side surface (X or Y only)
  if (count === 1) {
    return { x: xOn, y: yOn, z: zOn, a: aOn }
  }
  if (xOn && yOn && !zOn) {
    return { x: true, y: true, z: false, a: aOn }
  }
  if (xOn || yOn || zOn) {
    return { x: xOn, y: yOn, z: zOn, a: aOn }
  }
  // All zeros but hasData (feature at machine 0) — XY only, never force Z
  return { x: true, y: true, z: false, a: false }
}

/** True if flag is bare `X` or valued `X1` (RRF meta presence form). */
function axisFlagPresent(axisFlags: string[], letter: string): boolean {
  return axisFlags.some(
    (f: string) => f === letter || f.startsWith(letter)
  )
}

/** Short note for toast after M6520 based on which axis flags were sent. */
export function wcsApplyTravelNote(axisFlags: string[]): string {
  const hasX = axisFlagPresent(axisFlags, 'X')
  const hasY = axisFlagPresent(axisFlags, 'Y')
  const hasZ = axisFlagPresent(axisFlags, 'Z')
  if (hasZ && !hasX && !hasY) {
    return ' (WCS Z set; cycle returns to start Z)'
  }
  if (hasX && hasY && hasZ) {
    return ' (WCS XYZ origin set; parked at feature)'
  }
  if (hasX && hasY && !hasZ) {
    return ' (WCS XY origin set; parked at feature)'
  }
  if (hasX && !hasY && !hasZ) {
    return ' (WCS X origin set)'
  }
  if (hasY && !hasX && !hasZ) {
    return ' (WCS Y origin set)'
  }
  return ''
}

/** Sparse restore of non-null probe result rows into firmware OM. */
export async function restoreProbeResultsToOm(
  rows: NxtProbeResultRow[],
  sendCode: OmSetSender
): Promise<void> {
  const lines: string[] = [
    '; nxt-om-set-scratch.g — restore nxtProbeResults (UI DWC refresh)',
    'if { !exists(global.nxtProbeResults) }',
    `    global nxtProbeResults = { vector(${NXT_PROBE_RESULTS_SLOT_COUNT}, null) }`
  ]
  let any = false
  for (let i = 0; i < rows.length; i++) {
    const row = rows[i]
    if (row == null || row.length < 3) continue
    any = true
    const rhs = formatOmRhs(row)
    lines.push(`set global.nxtProbeResults[${i}] = ${rhs}`)
  }
  if (!any) return
  lines.push('')
  await uploadDwcFile(NXT_OM_SET_SCRATCH_PATH, lines.join('\n'))
  await sendCode('M98 P"nxt-om-set-scratch.g"')
}

/** Clear plugin snapshot after M6521 (firmware clear is separate). */
export function clearNxtUiProbeResultsSnapshot(plugins: unknown): void {
  writeNxtUiProbeResults([], plugins)
}
