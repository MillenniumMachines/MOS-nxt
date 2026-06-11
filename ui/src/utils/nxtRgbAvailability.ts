import { nxtBoardPackFromManifest } from './nxtConfigManifestData'

const RGB_LED_ROLES = new Set(['rgb_led', 'work_light', 'led_strip', 'work_light_rgb'])

type PinmapAssignedEntry = { kind?: string; role?: string }

function pinmapAssignedEntries(pinmap: Record<string, unknown> | null): PinmapAssignedEntry[] {
  if (pinmap == null || typeof pinmap !== 'object') {
    return []
  }
  const assigned = pinmap.assigned
  return Array.isArray(assigned) ? (assigned as PinmapAssignedEntry[]) : []
}

function entryIsRgbLed(entry: PinmapAssignedEntry): boolean {
  if (entry.kind === 'led') {
    return true
  }
  const role = typeof entry.role === 'string' ? entry.role.toLowerCase() : ''
  if (RGB_LED_ROLES.has(role)) {
    return true
  }
  return role.includes('rgb') || (role.includes('led') && role.includes('light'))
}

export function pinmapDeclaresRgbLed(pinmap: Record<string, unknown> | null | undefined): boolean {
  return pinmapAssignedEntries(pinmap ?? null).some(entryIsRgbLed)
}

/** RRF object-model LED strip count (after M950 L in config). */
export function countOmLeds(leds: unknown): number {
  if (leds == null) {
    return 0
  }
  if (Array.isArray(leds)) {
    return leds.length
  }
  if (leds instanceof Map) {
    return leds.size
  }
  if (typeof leds === 'object') {
    return Object.keys(leds as object).length
  }
  return 0
}

/** `leds` exists at runtime on RRF 3.x OM but is not on @duet3d/objectmodel ObjectModel yet. */
export function readOmLedsFromMachineModel(model: unknown): unknown {
  if (model == null || typeof model !== 'object') {
    return undefined
  }
  return (model as Record<string, unknown>).leds
}

export function isRgbLightHardwareConfigured(ctx: {
  leds: unknown
  boardShortName: string | null
}): boolean {
  if (countOmLeds(ctx.leds) > 0) {
    return true
  }
  const pack = nxtBoardPackFromManifest(ctx.boardShortName)
  return pinmapDeclaresRgbLed(pack?.pinmap ?? null)
}

export function rgbLedIndexItems(ledCount: number): Array<{ value: number; text: string }> {
  const n = Math.max(0, Math.min(ledCount, 8))
  if (n === 0) {
    return [{ value: 0, text: 'LED 0' }]
  }
  return Array.from({ length: n }, (_, i) => ({ value: i, text: `LED ${i}` }))
}
