/**
 * Helpers for mos-atc / RRF ATC tool library globals (RepRapFirmware 3.6+).
 * `machine.model.global` is a Map in stock DWC — use readFirmwareGlobal, not dot access.
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

/** MillenniumOS: global.mosTT[tool][0] is radius when present in OM. */
export function readMosTTRadius(globalVal: unknown, toolIndex: number): number | null {
  const mosTT = readFirmwareGlobal(globalVal, 'mosTT')
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

export function normalizeAtcVector(raw: unknown, length: number): number[] {
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

/** Default M-code numbers for mos-atc on SD (0:/sys/M8xx.g). */
export const ATC_TOOL_LIBRARY_M = {
  resolveTool: 873
} as const
