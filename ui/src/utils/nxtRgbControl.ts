export type NxtRgbUiState = {
  r: number
  g: number
  b: number
  brightness: number
  on: boolean
}

export const NXT_RGB_UI_DEFAULT: NxtRgbUiState = {
  r: 255,
  g: 255,
  b: 255,
  brightness: 100,
  on: true
}

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
  if (!state.on) {
    return 'M6524 R0 G0 B0'
  }
  const scaled = scaleRgbByBrightness(state.r, state.g, state.b, state.brightness)
  return `M6524 R${scaled.r} G${scaled.g} B${scaled.b}`
}
