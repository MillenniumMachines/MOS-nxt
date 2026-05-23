import type { Probe } from '@duet3d/objectmodel'

/**
 * Read a probe entry from the RRF object model `sensors.probes` collection.
 */
export function getProbeByIndex(
  probes: readonly Probe[] | Probe[] | null | undefined,
  index: number | null | undefined
): Probe | null {
  if (index === null || index === undefined || index < 0 || probes == null) {
    return null
  }
  const list = probes as Probe[] & { at?: (i: number) => Probe | undefined }
  if (typeof list.at === 'function') {
    const p = list.at(index)
    return p ?? null
  }
  return list[index] ?? null
}

/**
 * RRF reports probe trip via reading vs threshold (not a boolean `triggered` field).
 */
export function isProbeTriggered(probe: Probe | null | undefined): boolean {
  if (probe == null) {
    return false
  }
  const reading = probe.value?.[0]
  const threshold = probe.threshold
  if (reading == null || threshold == null) {
    return false
  }
  return reading >= threshold
}

export function probeReadingText(probe: Probe | null | undefined): string {
  if (probe == null) {
    return '—'
  }
  const v = probe.value?.[0]
  return v == null ? '—' : String(v)
}
