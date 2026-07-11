/**
 * nxt tool changer — object model helpers (firmware / optional ATC pack).
 *
 * Base nxt does **not** define magazine/ATC globals. Those keys exist only
 * when an optional tool changer firmware pack is installed (same wire format as the legacy
 * mos-atc macro set). **Magazine / bay / job-sequence / M-code operator UI** belongs in the
 * **mos-atc** DWC plugin; this module stays in nxt as the shared OM key map and helpers
 * (e.g. legacy probe ID, `nxtTT` radius) for that plugin or forks.
 *
 * See docs/TOOLCHANGING.md for RRF T/tpre/tfree/tpost and extension layout.
 *
 * RRF meta note: in user M-codes (e.g. M871), avoid `global.atcPocketToTool[param.P]` —
 * copy `param.P` / `param.R` into `var.*` first, then subscript; some RRF 3.6.x builds
 * mis-parse `param` inside `[ ]` (bogus `atcPocketToTool^` errors).
 */

export function readFirmwareGlobal(globalVal: unknown, key: string): unknown {
  if (globalVal == null) {
    return undefined
  }
  if (globalVal instanceof Map) {
    return globalVal.get(key)
  }
  if (typeof globalVal === 'object') {
    return (globalVal as Record<string, unknown>)[key]
  }
  return undefined
}

/**
 * One element from an RRF object-model "vector" (may be `Array`, `Map`, or plain object with indices).
 */
export function readOmVectorCell(row: unknown, index: number): unknown {
  if (row == null) {
    return undefined
  }
  if (row instanceof Map) {
    const direct = row.get(index)
    if (direct !== undefined) {
      return direct
    }
    return row.get(String(index))
  }
  if (Array.isArray(row)) {
    return index < row.length ? row[index] : undefined
  }
  if (typeof row === 'object') {
    const o = row as Record<string | number, unknown>
    const v = o[index]
    if (v !== undefined) {
      return v
    }
    return o[String(index)]
  }
  return undefined
}

/**
 * OM keys for the optional magazine / bay map extension. Values are the actual RRF global
 * names emitted by the installed firmware pack (unchanged for compatibility).
 */
export const NxtToolChangerOmKeys = {
  magazineCount: 'atcMagazineCount',
  slotsPerMagazine: 'atcSlotsPerMagazine',
  pocketCount: 'atcPocketCount',
  pocketToTool: 'atcPocketToTool',
  toolToPocket: 'atcToolToPocket',
  enabled: 'atcEnabled',
  toolChangeMode: 'atcToolChangeMode',
  bayMode: 'atcBayMode',
  jobOverflowWarning: 'atcJobOverflowWarning',
  jobSeqLength: 'atcJobSeqLength',
  jobSeqTool: 'atcJobSeqTool',
  jobSeqOverflow: 'atcJobSeqOverflow',
  jobSeqBay: 'atcJobSeqBay',
  jobSeqComplete: 'atcJobSeqComplete',
  resolvedTool: 'atcResolvedTool',
  resolvedPocket: 'atcResolvedPocket',
  /** CAM tool table metadata (`global.nxtTT`); falls back to legacy `mosTT` on migrated SD. */
  toolTable: 'nxtTT',
  /** @deprecated MillenniumOS OM key — use {@link toolTable} / `nxtTT`. */
  legacyToolTableRadius: 'mosTT',
  /** Legacy probe tool index in OM; optional — prefer `nxtTouchProbeID` when set. */
  legacyProbeToolIdKey: 'mosPTID'
} as const

/** `global.nxtTT[toolIndex]` (or legacy `mosTT` on migrated firmware). */
export function readNxtTTRow(globalVal: unknown, toolIndex: number): unknown | null {
  const nxtTT = readFirmwareGlobal(globalVal, NxtToolChangerOmKeys.toolTable)
  const legacy = readFirmwareGlobal(globalVal, NxtToolChangerOmKeys.legacyToolTableRadius)
  const table = nxtTT != null ? nxtTT : legacy
  if (table == null) {
    return null
  }
  if (table instanceof Map) {
    const row = table.get(toolIndex) ?? table.get(String(toolIndex))
    return row !== undefined && row !== null ? row : null
  }
  if (Array.isArray(table)) {
    if (toolIndex < 0 || toolIndex >= table.length) {
      return null
    }
    const row = table[toolIndex]
    return row !== undefined && row !== null ? row : null
  }
  if (typeof table === 'object') {
    const o = table as Record<string | number, unknown>
    const row = o[toolIndex]
    if (row !== undefined) {
      return row
    }
    const rs = o[String(toolIndex)]
    return rs !== undefined && rs !== null ? rs : null
  }
  return null
}

/** @deprecated Use {@link readNxtTTRow}. */
export function readMosTTRow(globalVal: unknown, toolIndex: number): unknown | null {
  return readNxtTTRow(globalVal, toolIndex)
}

/**
 * Tool tip radius from optional legacy `mosTT[tool][0]` global when present.
 * RRF `tools[].radius` in the object model is preferred by callers when available.
 */
export function readLegacyToolTableRadius(globalVal: unknown, toolIndex: number): number | null {
  const row = readMosTTRow(globalVal, toolIndex)
  if (row == null) {
    return null
  }
  const r = readOmVectorCell(row, 0)
  return typeof r === 'number' && Number.isFinite(r) ? r : null
}

/**
 * Optional flute count / flute length from `mosTT[tool][2]` and `[3]` (firmware: -1 = unset).
 */
export function readMosTTFluteMeta(
  globalVal: unknown,
  toolIndex: number
): { nxtFluteCount: number | null; nxtFluteLengthMm: number | null } {
  const row = readMosTTRow(globalVal, toolIndex)
  if (row == null) {
    return { nxtFluteCount: null, nxtFluteLengthMm: null }
  }
  let nxtFluteCount: number | null = null
  let nxtFluteLengthMm: number | null = null
  const f = readOmVectorCell(row, 2)
  if (typeof f === 'number' && Number.isFinite(f) && f >= 0) {
    nxtFluteCount = Math.round(f)
  }
  const l = readOmVectorCell(row, 3)
  if (typeof l === 'number' && Number.isFinite(l) && l >= 0) {
    nxtFluteLengthMm = l
  }
  return { nxtFluteCount, nxtFluteLengthMm }
}

/**
 * Parse `tools[n].mix` from the OM into a numeric list (array, lone number, or sparse object).
 */
function readNumericMixVector(raw: unknown): number[] | null {
  if (typeof raw === 'number' && Number.isFinite(raw)) {
    return [raw]
  }
  if (raw == null) {
    return null
  }
  if (Array.isArray(raw)) {
    const nums = raw.filter((x): x is number => typeof x === 'number' && Number.isFinite(x))
    return nums.length > 0 ? nums : null
  }
  if (raw instanceof Map) {
    const out: number[] = []
    for (let i = 0; i < 16; i++) {
      const v = raw.get(i) ?? raw.get(String(i))
      if (typeof v === 'number' && Number.isFinite(v)) {
        out.push(v)
      } else {
        break
      }
    }
    return out.length > 0 ? out : null
  }
  if (typeof raw === 'object') {
    const o = raw as Record<string | number, unknown>
    const out: number[] = []
    for (let i = 0; i < 16; i++) {
      let v = o[i]
      if (v === undefined) {
        v = o[String(i)]
      }
      if (typeof v === 'number' && Number.isFinite(v)) {
        out.push(v)
      } else {
        break
      }
    }
    return out.length > 0 ? out : null
  }
  return null
}

/** Typical multi-extruder mix rows: non-negative, sum ≈ 1. */
function mixLooksLikeExtruderRatios(nums: number[]): boolean {
  if (nums.length < 2) {
    return false
  }
  const sum = nums.reduce((a, b) => a + b, 0)
  if (sum <= 0 || Math.abs(sum - 1) > 0.05) {
    return false
  }
  return nums.every((x) => x >= 0 && x <= 1)
}

function integerFluteCandidate(n: number): number | null {
  if (!Number.isFinite(n)) {
    return null
  }
  const r = Math.round(n)
  if (Math.abs(n - r) > 1e-6) {
    return null
  }
  if (r < 1 || r > 64) {
    return null
  }
  return r
}

/**
 * Flute count from RRF **`tools[n].mix`** when **`mosTT`** does not define **`F`**.
 * Skips tools that map **extruders** (avoids mistaking **mixing ratios** for flute count).
 * Skips vectors that look like normalized **extruder mix ratios** (sum ≈ 1, values in [0, 1]).
 * Uses the **first** mix entry when it is an integer in **1…64** (CNC repurpose of `mix`).
 */
export function readFluteCountFromToolMix(toolObj: unknown): number | null {
  if (!toolObj || typeof toolObj !== 'object') {
    return null
  }
  const t = toolObj as { extruders?: unknown; mix?: unknown }
  if (Array.isArray(t.extruders) && t.extruders.length > 1) {
    return null
  }
  const vec = readNumericMixVector(t.mix)
  if (!vec || vec.length === 0) {
    return null
  }
  if (mixLooksLikeExtruderRatios(vec)) {
    return null
  }
  return integerFluteCandidate(vec[0])
}

/**
 * **`M4000 F`** / display flute count: **`mosTT[n][2]`** when set (≥ 0), else **`tools[n].mix`**
 * per {@link readFluteCountFromToolMix}.
 */
export function resolveToolFluteCount(
  toolObj: unknown,
  firmwareGlobals: unknown,
  toolIndex: number
): number | null {
  const fromMos = readMosTTFluteMeta(firmwareGlobals, toolIndex).nxtFluteCount
  if (fromMos != null) {
    return fromMos
  }
  return readFluteCountFromToolMix(toolObj)
}

/** Normalize a firmware int vector (array or sparse object) to fixed length, -1 = empty. */
export function normalizeIntVector(raw: unknown, length: number): number[] {
  if (!Number.isFinite(length) || length < 1) {
    return []
  }
  const out: number[] = []
  if (Array.isArray(raw)) {
    for (let i = 0; i < length; i++) {
      const v = raw[i]
      out.push(typeof v === 'number' ? v : -1)
    }
    return out
  }
  if (raw && typeof raw === 'object') {
    for (let i = 0; i < length; i++) {
      const v = (raw as Record<number, number>)[i]
      out.push(typeof v === 'number' ? v : -1)
    }
    return out
  }
  for (let i = 0; i < length; i++) {
    out.push(-1)
  }
  return out
}

/**
 * M-code numbers for the optional nxt-compatible tool changer macro pack on SD (`0:/sys/`).
 * Absent until that pack is installed; numbers match the legacy mos-atc pack for compatibility.
 */
/** Prefer RRF tool OM, then optional legacy `mosTT` column. */
export function resolveToolRadiusMm(
  toolObj: unknown,
  globalVal: unknown,
  toolIndex: number
): number | null {
  if (toolObj && typeof toolObj === 'object') {
    const t = toolObj as { radius?: number; diameter?: number }
    if (typeof t.radius === 'number' && Number.isFinite(t.radius)) {
      return t.radius
    }
    if (typeof t.diameter === 'number' && Number.isFinite(t.diameter)) {
      return t.diameter / 2
    }
  }
  return readLegacyToolTableRadius(globalVal, toolIndex)
}

/**
 * Shallow merge of a DWC `machine.model.tools[n]` entry with nxt display fields.
 *
 * RepRapFirmware’s canonical `tools[]` object model does not include cutter radius/diameter
 * (see upstream `Tool` / OM); `M4000` stores CAM radius in `global.mosTT`. Until/unless RRF
 * adds native geometry on `tools[n]`, **`nxtRadiusMm` / `nxtDiameterMm`** are enriched from
 * `resolveToolRadiusMm` (OM-first, then `mosTT`). **`nxtFluteLengthMm`** comes from **`mosTT[n][3]`**.
 * **`nxtFluteCount`** uses `resolveToolFluteCount` (**`mosTT`** / **`M4000 F`** first, then OM **`mix`**
 * when repurpose rules in `readFluteCountFromToolMix` match).
 * **Always treat `tools[n]` from the machine model as the primary tool record**; use this helper only for display.
 */
export type NxtAugmentedRrfTool = Record<string, unknown> & {
  nxtRadiusMm: number | null
  nxtDiameterMm: number | null
  nxtFluteCount: number | null
  nxtFluteLengthMm: number | null
}

export function augmentRrfToolForNxtUi(
  toolObj: unknown,
  firmwareGlobals: unknown,
  toolIndex: number
): NxtAugmentedRrfTool {
  const base =
    toolObj != null && typeof toolObj === 'object'
      ? { ...(toolObj as Record<string, unknown>) }
      : {}
  const nxtRadiusMm = resolveToolRadiusMm(toolObj, firmwareGlobals, toolIndex)
  const nxtDiameterMm = nxtRadiusMm != null && Number.isFinite(nxtRadiusMm) ? 2 * nxtRadiusMm : null
  const nxtFluteCount = resolveToolFluteCount(toolObj, firmwareGlobals, toolIndex)
  const { nxtFluteLengthMm } = readMosTTFluteMeta(firmwareGlobals, toolIndex)
  return Object.assign(base, { nxtRadiusMm, nxtDiameterMm, nxtFluteCount, nxtFluteLengthMm })
}

export const NxtToolChangerExtensionM = {
  resolvePocket: 872,
  resolveTool: 873,
  seedIdentity: 874,
  selectFromPocketDemo: 875,
  mapPocket: 871,
  init: 870,
  setLayout: 876,
  clearBay: 4011,
  presentBay: 4013,
  unloadAll: 4010,
  statusDump: 4012,
  bayTest: 4014,
  saveLibrary: 878,
  loadLibrary: 879
} as const
