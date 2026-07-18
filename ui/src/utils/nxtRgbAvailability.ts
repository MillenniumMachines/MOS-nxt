import { nxtBoardPackFromManifest } from './nxtConfigManifestData'
import { readFirmwareGlobal } from './nxtToolChangerOm'

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

/** RRF object-model LED strip count (after M950 E/L). */
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

function rgbPinConfigured(rgbPin: unknown): boolean {
  if (rgbPin == null) {
    return false
  }
  const s = String(rgbPin).trim()
  return s.length > 0 && s !== 'null' && s !== 'undefined'
}

/**
 * True when RGB hardware is present or declared for this board.
 * DWC often omits `model.leds` from the OM query, so also trust nxt RGB globals
 * (set by board `rgb.g`) and the board pinmap.
 */
export function isRgbLightHardwareConfigured(ctx: {
  leds: unknown
  boardShortName: string | null
  /** global.nxtRGBPin — set by board pack rgb.g */
  rgbPin?: unknown
  /** global.nxtRGBReady — true after M950 */
  rgbReady?: unknown
}): boolean {
  if (countOmLeds(ctx.leds) > 0) {
    return true
  }
  if (ctx.rgbReady === true || ctx.rgbReady === 1) {
    return true
  }
  if (rgbPinConfigured(ctx.rgbPin)) {
    return true
  }
  const pack = nxtBoardPackFromManifest(ctx.boardShortName)
  return pinmapDeclaresRgbLed(pack?.pinmap ?? null)
}

/** Map-safe read of nxtFeatureRgbLight from OM global. */
export function isRgbFeatureEnabled(globalVal: unknown): boolean {
  const v = readFirmwareGlobal(globalVal, 'nxtFeatureRgbLight')
  return v === true || v === 1
}

