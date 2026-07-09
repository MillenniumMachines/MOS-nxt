/** Format maintenance durations and distances for DWC panels. */

export function fmtDist(mm: number): string {
  if (!Number.isFinite(mm)) {
    return '—'
  }
  if (mm >= 1000) {
    return (mm / 1000).toFixed(2) + ' km'
  }
  return mm.toFixed(1) + ' mm'
}

export function fmtDur(sec: number): string {
  if (!Number.isFinite(sec) || sec <= 0) {
    return '0 s'
  }
  const h = Math.floor(sec / 3600)
  const m = Math.floor((sec % 3600) / 60)
  const s = Math.round(sec % 60)
  if (h > 0) {
    return h + 'h ' + m + 'm'
  }
  if (m > 0) {
    return m + 'm ' + s + 's'
  }
  return s + ' s'
}

export function fmtToolLife(sec: number): string {
  if (!Number.isFinite(sec) || sec <= 0) {
    return '—'
  }
  return fmtDur(sec)
}
