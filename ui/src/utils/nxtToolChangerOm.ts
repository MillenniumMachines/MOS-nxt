/**
 * NeXT tool changer — object model helpers (firmware / optional ATC pack).
 *
 * Base NeXT (`nxt-vars.g`) does **not** define magazine/ATC globals. Those keys exist only
 * when an optional tool changer firmware pack is installed (same wire format as the legacy
 * mos-atc macro set). **Magazine / bay / job-sequence / M-code operator UI** belongs in the
 * **mos-atc** DWC plugin; this module stays in NeXT as the shared OM key map and helpers
 * (e.g. legacy probe ID, `mosTT` radius) for that plugin or forks.
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
  /** Legacy tool table radius column (MillenniumOS-style OM); optional. */
  legacyToolTableRadius: 'mosTT',
  /** Legacy probe tool index in OM; optional — prefer `nxtTouchProbeID` when set. */
  legacyProbeToolIdKey: 'mosPTID'
} as const

/**
 * Tool tip radius from optional legacy `mosTT[tool][0]` global when present.
 * RRF `tools[].radius` in the object model is preferred by callers when available.
 */
export function readLegacyToolTableRadius(globalVal: unknown, toolIndex: number): number | null {
  const mosTT = readFirmwareGlobal(globalVal, NxtToolChangerOmKeys.legacyToolTableRadius)
  if (!mosTT || !Array.isArray(mosTT) || toolIndex < 0 || toolIndex >= mosTT.length) {
    return null
  }
  const row = mosTT[toolIndex]
  if (row == null || !Array.isArray(row)) {
    return null
  }
  const r = row[0]
  return typeof r === 'number' && Number.isFinite(r) ? r : null
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
 * M-code numbers for the optional NeXT-compatible tool changer macro pack on SD (`0:/sys/`).
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
