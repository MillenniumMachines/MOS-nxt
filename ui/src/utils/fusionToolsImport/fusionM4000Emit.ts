/**
 * Fusion geometry → M4000 R/F/L (ported from fusion-tools-m4000/m4000_emit.py).
 */

import type { FusionToolRecord } from './fusionImportPolicy'

export type BullNoseRadiusMode = 'corner' | 'diameter'

function geometryDict(rec: FusionToolRecord): Record<string, unknown> {
  const g = rec.geometry
  return g != null && typeof g === 'object' ? (g as Record<string, unknown>) : {}
}

export function fmtAxis(n: number): string {
  if (!Number.isFinite(n)) {
    return '0'
  }
  let s = n.toFixed(6).replace(/\.?0+$/, '')
  if (s === '' || s === '-0') {
    s = '0'
  }
  return s
}

export function sanitizeM4000Description(raw: string, toolIndex: number): string {
  let s = raw.trim()
  if (!s.length) {
    s = `T${toolIndex}`
  }
  return s.replace(/"/g, "'")
}

export function computeCamRadius(
  toolType: string | null | undefined,
  geometry: Record<string, unknown>,
  bullNoseMode: BullNoseRadiusMode
): number {
  const dcRaw = geometry.DC
  const diameter =
    typeof dcRaw === 'number' && Number.isFinite(dcRaw) ? dcRaw : null
  const t = (toolType ?? '').trim().toLowerCase()

  if (t === 'bull nose end mill') {
    const reRaw = geometry.RE
    const re =
      typeof reRaw === 'number' && Number.isFinite(reRaw) ? reRaw : null
    if (bullNoseMode === 'diameter') {
      return diameter != null ? diameter / 2 : 0
    }
    if (re != null && re > 0) {
      return re
    }
    return diameter != null ? diameter / 2 : 0
  }

  if (diameter == null) {
    return 0
  }
  return diameter / 2
}

function optionalNof(geometry: Record<string, unknown>): number | null {
  const nof = geometry.NOF
  if (typeof nof === 'boolean') {
    return null
  }
  if (typeof nof === 'number' && Number.isFinite(nof) && Number.isInteger(nof)) {
    return nof
  }
  if (typeof nof === 'number' && Number.isFinite(nof)) {
    return Math.trunc(nof)
  }
  return null
}

function optionalLcfMm(geometry: Record<string, unknown>): number | null {
  const lcf = geometry.LCF
  if (typeof lcf === 'number' && Number.isFinite(lcf)) {
    return lcf
  }
  return null
}

function enrichmentSuffix(geometry: Record<string, unknown>): string {
  const reRaw = geometry.RE
  if (typeof reRaw === 'number' && Number.isFinite(reRaw)) {
    return ` CR=${fmtAxis(reRaw)}`
  }
  return ''
}

export type EmitM4000Options = {
  enrichDescription?: boolean
  bullNoseMode?: BullNoseRadiusMode
  /** Emit C0/C1 from manual-tool-change (file export only; live DWC import omits C). */
  tcCapable?: boolean | null
  handLoadAll?: boolean
  markAtcCapable?: boolean
}

export function buildFusionM4000Line(
  rec: FusionToolRecord,
  options: EmitM4000Options = {}
): { pocket: number; line: string } {
  const pp = rec['post-process']
  if (pp == null || typeof pp !== 'object') {
    throw new Error('post-process.number must be an integer')
  }
  const pRaw = (pp as Record<string, unknown>).number
  if (typeof pRaw !== 'number' || !Number.isFinite(pRaw) || !Number.isInteger(pRaw)) {
    throw new Error('post-process.number must be an integer')
  }
  const pocket = pRaw

  const geom = geometryDict(rec)
  const toolType = typeof rec.type === 'string' ? rec.type : null
  const bullNoseMode = options.bullNoseMode ?? 'corner'
  const r = computeCamRadius(toolType, geom, bullNoseMode)

  const descRaw = typeof rec.description === 'string' ? rec.description : ''
  let desc = sanitizeM4000Description(descRaw, pocket)
  if (options.enrichDescription) {
    desc += enrichmentSuffix(geom)
  }

  let line = `M4000 P${pocket} R${fmtAxis(r)}`
  const nFl = optionalNof(geom)
  if (nFl != null) {
    line += ` F${nFl}`
  }
  const lf = optionalLcfMm(geom)
  if (lf != null) {
    line += ` L${fmtAxis(lf)}`
  }

  let tc: number | null = null
  if (options.handLoadAll) {
    tc = 0
  } else if (options.markAtcCapable) {
    tc = 1
  } else if (options.tcCapable != null) {
    tc = options.tcCapable ? 1 : 0
  } else {
    const manual = (pp as Record<string, unknown>)['manual-tool-change']
    if (manual === true) {
      tc = 0
    }
  }
  if (tc === 0) {
    line += ' C0'
  } else if (tc === 1 && options.markAtcCapable) {
    line += ' C1'
  }

  line += ` S"${desc}"`
  return { pocket, line }
}
