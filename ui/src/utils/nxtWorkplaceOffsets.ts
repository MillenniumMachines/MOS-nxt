/**
 * Live RRF workplace (G10 L2) offsets for the Probing WCS list.
 * Reads move.axes[].workplaceOffsets — not nxtProbeResults.
 */
import type { Axis } from '@duet3d/objectmodel'
import { readFirmwareGlobal, readOmVectorCell } from './nxtToolChangerOm'

export const NXT_WCS_MAX = 9
export const NXT_WCS_GCODES = [
  'G54',
  'G55',
  'G56',
  'G57',
  'G58',
  'G59',
  'G59.1',
  'G59.2',
  'G59.3'
] as const

export function clampNxtWcs(n: number): number {
  if (!Number.isFinite(n)) return 1
  const i = Math.round(n)
  if (i < 1) return 1
  if (i > NXT_WCS_MAX) return NXT_WCS_MAX
  return i
}

export function nxtWcsGCode(wcs: number): string {
  return NXT_WCS_GCODES[clampNxtWcs(wcs) - 1]
}

export function nxtWcsLabel(wcs: number): string {
  const n = clampNxtWcs(wcs)
  return `WCS${n} (${nxtWcsGCode(n)})`
}

export function workplaceOffsetLength(axis: Axis | undefined | null): number {
  const offs: unknown = axis?.workplaceOffsets
  if (offs == null) return 0
  if (Array.isArray(offs)) return offs.length
  if (offs instanceof Map) return offs.size
  if (typeof offs === 'object') return Object.keys(offs as object).length
  return 0
}

export function workplaceCount(opts: {
  limitsWorkplaces?: number | null
  offsetLength?: number | null
}): number {
  const lim =
    typeof opts.limitsWorkplaces === 'number' && opts.limitsWorkplaces > 0
      ? opts.limitsWorkplaces
      : NXT_WCS_MAX
  const off =
    typeof opts.offsetLength === 'number' && opts.offsetLength > 0
      ? opts.offsetLength
      : lim
  return Math.min(NXT_WCS_MAX, lim, off)
}

export function readWorkplaceOffset(
  axis: Axis | undefined | null,
  workplaceIndex: number
): number | null {
  if (axis == null) return null
  const v = readOmVectorCell(axis.workplaceOffsets, workplaceIndex)
  if (v == null) return null
  const n = Number(v)
  return Number.isFinite(n) ? n : null
}

export function readWpDeg(globalVal: unknown, workplaceIndex: number): number | null {
  const raw = readFirmwareGlobal(globalVal, 'nxtWPDeg')
  const v = readOmVectorCell(raw, workplaceIndex)
  if (v == null) return null
  const n = Number(v)
  return Number.isFinite(n) ? n : null
}

export function findVisibleAxis(
  axes: readonly Axis[] | undefined,
  letter: string
): Axis | undefined {
  return (axes ?? []).find((a: Axis) => a.visible && a.letter === letter)
}

export function formatMmDisplay(value: number | null): string {
  if (value == null || !Number.isFinite(value)) return '—'
  const s = value.toFixed(4)
  return s.replace(/(\.\d*?)0+$/, '$1').replace(/\.$/, '')
}

export function formatMmGcode(value: number): string {
  return value.toFixed(4)
}

export function mmUnchanged(live: number | null, next: number): boolean {
  if (live == null) return false
  return Math.abs(live - next) < 5e-5
}
