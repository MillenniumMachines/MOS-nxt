export type NxtRgbUiState = {
  r: number
  g: number
  b: number
  brightness: number
  on: boolean
}

export type NxtRgbw = { r: number; g: number; b: number; w: number }

/** Daemon test / status keys (match nxt-run-rgb.g / nxtRGBTest). */
export type NxtRgbStatusId = 'idle' | 'home' | 'probe' | 'tool' | 'run' | 'paused' | 'error'

export type NxtRgbStatusDef = {
  id: NxtRgbStatusId
  /** Index into global.nxtRGBCol */
  colIndex: number
  labelKey: string
}

export const NXT_RGB_UI_DEFAULT: NxtRgbUiState = {
  r: 255,
  g: 255,
  b: 255,
  brightness: 100,
  on: true
}

/** Mirrors macros/system/nxt-vars.g nxtRGBCol defaults. */
export const NXT_RGB_STATUS_DEFAULTS: Record<NxtRgbStatusId, NxtRgbw> = {
  idle: { r: 255, g: 255, b: 255, w: 255 },
  home: { r: 0, g: 0, b: 255, w: 0 },
  probe: { r: 0, g: 255, b: 255, w: 0 },
  tool: { r: 255, g: 150, b: 0, w: 0 },
  run: { r: 255, g: 255, b: 255, w: 255 },
  paused: { r: 255, g: 255, b: 255, w: 255 },
  error: { r: 255, g: 0, b: 0, w: 0 }
}

export const NXT_RGB_STATUS_DEFS: NxtRgbStatusDef[] = [
  { id: 'idle', colIndex: 0, labelKey: 'stateIdle' },
  { id: 'home', colIndex: 1, labelKey: 'stateHome' },
  { id: 'probe', colIndex: 2, labelKey: 'stateProbe' },
  { id: 'tool', colIndex: 3, labelKey: 'stateTool' },
  { id: 'run', colIndex: 4, labelKey: 'stateRun' },
  { id: 'paused', colIndex: 5, labelKey: 'statePaused' },
  { id: 'error', colIndex: 6, labelKey: 'stateError' }
]

export function clampByte(n: number): number {
  if (!Number.isFinite(n)) {
    return 0
  }
  return Math.max(0, Math.min(255, Math.round(n)))
}

export function clampBrightness(n: number): number {
  if (!Number.isFinite(n)) {
    return 0
  }
  return Math.max(0, Math.min(100, Math.round(n)))
}

export function scaleRgbByBrightness(
  r: number,
  g: number,
  b: number,
  brightnessPct: number
): { r: number; g: number; b: number } {
  const scale = clampBrightness(brightnessPct) / 100
  return {
    r: clampByte(r * scale),
    g: clampByte(g * scale),
    b: clampByte(b * scale)
  }
}

export function buildM6524Command(state: NxtRgbUiState): string {
  // Use U for green — RRF treats "Gnnn" on the same line as a G-code (e.g. G102).
  if (!state.on) {
    return 'M6524 R0 U0 B0'
  }
  const scaled = scaleRgbByBrightness(state.r, state.g, state.b, state.brightness)
  return `M6524 R${scaled.r} U${scaled.g} B${scaled.b}`
}

/**
 * Direct M150 for the Status RGB panel (avoids M6524 / G-param parsing issues).
 * Strip index and LED count come from nxt globals when available.
 */
export function buildRgbManualM150Command(
  state: NxtRgbUiState,
  opts?: { strip?: number; count?: number }
): string {
  const strip = Number.isFinite(opts?.strip) ? Math.max(0, Math.round(opts!.strip!)) : 0
  const count = Number.isFinite(opts?.count) ? Math.max(1, Math.round(opts!.count!)) : 1
  if (!state.on) {
    return `M150 E${strip} R0 U0 B0 W0 P255 S${count} F0`
  }
  const scaled = scaleRgbByBrightness(state.r, state.g, state.b, state.brightness)
  return `M150 E${strip} R${scaled.r} U${scaled.g} B${scaled.b} W0 P255 S${count} F0`
}

export function rgbToHex(r: number, g: number, b: number): string {
  const h = (n: number) => clampByte(n).toString(16).padStart(2, '0')
  return `#${h(r)}${h(g)}${h(b)}`
}

export function hexToRgb(hex: string): { r: number; g: number; b: number } | null {
  const m = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(String(hex).trim())
  if (!m) {
    return null
  }
  return {
    r: parseInt(m[1], 16),
    g: parseInt(m[2], 16),
    b: parseInt(m[3], 16)
  }
}

/** Parse OM / RRF vector (array, Map values, or comma string) into RGBW. */
export function parseRgbwVector(value: unknown, fallback: NxtRgbw): NxtRgbw {
  let nums: number[] | null = null
  if (Array.isArray(value)) {
    nums = value.map((x) => Number(x))
  } else if (value instanceof Map) {
    nums = Array.from(value.values()).map((x) => Number(x))
  } else if (typeof value === 'string') {
    const parts = value.replace(/[{}]/g, '').split(/[,\s]+/).filter(Boolean)
    nums = parts.map((p) => Number(p))
  } else if (value != null && typeof value === 'object') {
    const o = value as Record<string, unknown>
    if ('r' in o || '0' in o) {
      nums = [
        Number(o.r ?? o[0] ?? 0),
        Number(o.g ?? o[1] ?? 0),
        Number(o.b ?? o[2] ?? 0),
        Number(o.w ?? o[3] ?? 0)
      ]
    }
  }
  if (!nums || nums.length < 3) {
    return { ...fallback }
  }
  return {
    r: clampByte(nums[0]),
    g: clampByte(nums[1]),
    b: clampByte(nums[2]),
    w: clampByte(nums.length > 3 ? nums[3] : fallback.w)
  }
}

export function formatRgbwSetCommand(colIndex: number, c: NxtRgbw): string {
  const i = Math.max(0, Math.min(6, Math.round(colIndex)))
  return `set global.nxtRGBCol[${i}] = {${clampByte(c.r)}, ${clampByte(c.g)}, ${clampByte(c.b)}, ${clampByte(c.w)}}`
}

export function formatRgbTestCommand(state: NxtRgbStatusId | ''): string {
  if (state === '') {
    return 'set global.nxtRGBTest = ""'
  }
  return `set global.nxtRGBTest = "${state}"`
}

export function forceRgbRepaintCommand(): string {
  return 'set global.nxtRGBLast = "none"'
}
