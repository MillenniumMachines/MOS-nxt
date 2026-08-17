/**
 * Fusion tool library → live M4000 import policy (nxt plugin; no ATC C flag on live import).
 */

export type FusionToolRecord = {
  description?: unknown
  type?: unknown
  unit?: unknown
  geometry?: unknown
  'post-process'?: unknown
}

export type FusionImportRow = {
  index: number
  name: string
  radius: number
  flutes: number | null
  fluteLengthMm: number | null
}

export type FusionImportPreview = {
  rows: FusionImportRow[]
  warnings: string[]
}

function postProcessNumber(rec: FusionToolRecord): number | null {
  const pp = rec['post-process']
  if (pp == null || typeof pp !== 'object') {
    return null
  }
  const raw = (pp as Record<string, unknown>).number
  if (typeof raw === 'boolean') {
    return null
  }
  if (typeof raw === 'number' && Number.isFinite(raw) && Number.isInteger(raw)) {
    return raw
  }
  if (typeof raw === 'number' && Number.isFinite(raw)) {
    return Math.trunc(raw)
  }
  return null
}

function geometryDict(rec: FusionToolRecord): Record<string, unknown> {
  const g = rec.geometry
  return g != null && typeof g === 'object' ? (g as Record<string, unknown>) : {}
}

function unitScale(rec: FusionToolRecord): number {
  const u = typeof rec.unit === 'string' ? rec.unit.toLowerCase() : 'millimeters'
  if (u === 'in' || u.startsWith('inch')) {
    return 25.4
  }
  return 1
}

function roundMm(n: number): number {
  return Math.round(n * 1000) / 1000
}

/**
 * Max user pocket index: 0 .. (limits.tools - 2), e.g. 48 when limits.tools = 50.
 */
export function maxUserToolIndex(
  limitsTools: number | null | undefined,
  reservedFrom: number | null | undefined
): number {
  if (typeof reservedFrom === 'number' && Number.isFinite(reservedFrom) && reservedFrom > 0) {
    return reservedFrom - 1
  }
  if (typeof limitsTools === 'number' && Number.isFinite(limitsTools) && limitsTools > 1) {
    return limitsTools - 2
  }
  return 48
}

export function buildFusionImportPreview(
  tools: readonly FusionToolRecord[],
  opts: {
    maxIndex: number
    probeIndex: number
  }
): FusionImportPreview {
  const warnings: string[] = []
  const rows: FusionImportRow[] = []
  const seen = new Set<number>()

  for (const rec of tools) {
    if (rec == null || typeof rec !== 'object') {
      continue
    }
    const pocket = postProcessNumber(rec)
    const geom = geometryDict(rec)
    const descRaw = typeof rec.description === 'string' ? rec.description.trim() : ''
    const label = descRaw || `tool ${pocket ?? '?'}`

    if (pocket == null || pocket < 0 || pocket > opts.maxIndex) {
      warnings.push(
        `Skipped ${label}: tool ${pocket ?? '?'} exceeds the user tool range (0–${opts.maxIndex}).`
      )
      continue
    }
    if (pocket === opts.probeIndex) {
      warnings.push(`Skipped tool ${pocket} (${label}): that number is reserved for the probe.`)
      continue
    }

    const scale = unitScale(rec)
    if (scale !== 1) {
      warnings.push(`Tool ${pocket} (${label}) was in inches; converted to mm.`)
    }

    let name = descRaw || `Tool ${pocket}`
    if (!descRaw) {
      warnings.push(`Tool ${pocket} had no description; named "Tool ${pocket}".`)
    }

    let radius = 0
    const dc = geom.DC
    if (typeof dc === 'number' && Number.isFinite(dc) && dc > 0) {
      radius = roundMm((dc / 2) * scale)
    } else {
      warnings.push(`Tool ${pocket} (${label}) had no diameter; radius set to 0.`)
    }

    const nof = geom.NOF
    const flutes =
      typeof nof === 'number' && Number.isFinite(nof) && nof > 0 && Number.isInteger(nof)
        ? nof
        : null

    const lcf = geom.LCF
    const fluteLengthMm =
      typeof lcf === 'number' && Number.isFinite(lcf) && lcf > 0
        ? roundMm(lcf * scale)
        : null

    if (seen.has(pocket)) {
      warnings.push(`Tool number ${pocket} appears more than once; the later entry wins.`)
      const existing = rows.findIndex((r) => r.index === pocket)
      if (existing >= 0) {
        rows.splice(existing, 1)
      }
    }
    seen.add(pocket)
    rows.push({ index: pocket, name, radius, flutes, fluteLengthMm })
  }

  rows.sort((a, b) => a.index - b.index)
  return { rows, warnings }
}
