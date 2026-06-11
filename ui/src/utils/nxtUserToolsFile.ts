/**
 * Build `0:/sys/nxt-user-tools.g` content for nxt: M4000 (library) + G10 L1 (offsets).
 * Loaded at boot from nxt.g when the file exists; optional UI upload via rr_upload.
 * Also rewritten on the board by `nxt-user-tools-sync.g` after M4000/M4001 (unless load depth > 0).
 */

import {
  readFirmwareGlobal,
  resolveToolRadiusMm,
  readMosTTFluteMeta,
  resolveToolFluteCount,
  readMosTTRow,
  readOmVectorCell
} from './nxtToolChangerOm'

/** Must match `nxt-user-tools-sync.g` and enclose all M4000 blocks so M98 load does not re-enter sync. */
export const NXT_USER_TOOLS_LOAD_DEPTH_OPEN = [
  'if { !exists(global.nxtUserToolsLoadDepth) }',
  '    global nxtUserToolsLoadDepth = 0',
  'set global.nxtUserToolsLoadDepth = { global.nxtUserToolsLoadDepth + 1 }',
  ''
] as const

export const NXT_USER_TOOLS_LOAD_DEPTH_CLOSE = [
  'set global.nxtUserToolsLoadDepth = { global.nxtUserToolsLoadDepth - 1 }',
  ''
] as const

/** True for a non-null object model tool row (not `null`, `undefined`, or a primitive). */
export function isToolRecord(t: unknown): t is Record<string, unknown> {
  return t != null && typeof t === 'object'
}

/** Match ToolManagementPanel: RRF slots that count as “configured” for listing. */
export function isNxtToolSlotConfiguredInLibrary(tool: unknown): boolean {
  if (!isToolRecord(tool)) {
    return false
  }
  const t = tool
  const name = t.name
  if (typeof name === 'string' && name.trim().length > 0) {
    return true
  }
  if (Array.isArray(t.spindles) && t.spindles.length > 0) {
    return true
  }
  if (typeof t.spindle === 'number' && t.spindle >= 0) {
    return true
  }
  if (Array.isArray(t.extruders) && t.extruders.length > 0) {
    return true
  }
  if (Array.isArray(t.heaters) && t.heaters.length > 0) {
    return true
  }
  if (Array.isArray(t.drives) && t.drives.length > 0) {
    return true
  }
  return false
}

function fmtAxis(n: number): string {
  if (!Number.isFinite(n)) {
    return '0'
  }
  let s = n.toFixed(6).replace(/\.?0+$/, '')
  if (s === '' || s === '-0') {
    s = '0'
  }
  return s
}

/** M4000 S"..." — avoid raw double quotes inside the string. */
function sanitizeM4000Description(raw: string, toolIndex: number): string {
  let s = raw.trim()
  if (!s.length) {
    s = `T${toolIndex}`
  }
  return s.replace(/"/g, "'")
}

function readDefaultSpindleId(firmwareGlobals: unknown): number {
  const v = readFirmwareGlobal(firmwareGlobals, 'nxtSpindleID')
  if (typeof v === 'number' && Number.isFinite(v) && v >= 0) {
    return v
  }
  return 0
}

function readMosTTProbeDeflection(
  firmwareGlobals: unknown,
  toolIndex: number
): { x?: number; y?: number } {
  const row = readMosTTRow(firmwareGlobals, toolIndex)
  if (row == null) {
    return {}
  }
  const xy = readOmVectorCell(row, 1)
  if (xy == null) {
    return {}
  }
  const x = readOmVectorCell(xy, 0)
  const y = readOmVectorCell(xy, 1)
  const out: { x?: number; y?: number } = {}
  if (typeof x === 'number' && Number.isFinite(x)) {
    out.x = x
  }
  if (typeof y === 'number' && Number.isFinite(y)) {
    out.y = y
  }
  return out
}

function buildM4000Line(
  toolIndex: number,
  tool: Record<string, unknown>,
  firmwareGlobals: unknown,
  defaultSpindleId: number
): string {
  const radiusRaw = resolveToolRadiusMm(tool, firmwareGlobals, toolIndex)
  const radius = radiusRaw != null && Number.isFinite(radiusRaw) ? radiusRaw : 0

  let desc =
    typeof tool.name === 'string' && tool.name.length > 0
      ? tool.name
      : `T${toolIndex}`
  desc = sanitizeM4000Description(desc, toolIndex)

  let line = `M4000 P${toolIndex} R${fmtAxis(radius)} S"${desc}"`

  const spin =
    typeof tool.spindle === 'number' && Number.isFinite(tool.spindle) && tool.spindle >= 0
      ? tool.spindle
      : defaultSpindleId
  if (spin !== defaultSpindleId) {
    line += ` I${spin}`
  }

  const defl = readMosTTProbeDeflection(firmwareGlobals, toolIndex)
  if (defl.x !== undefined) {
    line += ` X${fmtAxis(defl.x)}`
  }
  if (defl.y !== undefined) {
    line += ` Y${fmtAxis(defl.y)}`
  }

  const nxtFluteCount = resolveToolFluteCount(tool, firmwareGlobals, toolIndex)
  if (nxtFluteCount != null && nxtFluteCount >= 0) {
    line += ` F${nxtFluteCount}`
  }
  const { nxtFluteLengthMm } = readMosTTFluteMeta(firmwareGlobals, toolIndex)
  if (nxtFluteLengthMm != null && nxtFluteLengthMm >= 0) {
    line += ` L${fmtAxis(nxtFluteLengthMm)}`
  }

  return line
}

/**
 * `tools[n].offsets` from DWC may be an array or an object-shaped vector; align indices with `move.axes`.
 */
function normalizeToolOffsetsForAxes(
  tool: Record<string, unknown>,
  axisCount: number
): (number | undefined)[] {
  if (!Number.isFinite(axisCount) || axisCount < 1) {
    return []
  }
  const raw = tool.offsets
  const out: (number | undefined)[] = []
  for (let i = 0; i < axisCount; i++) {
    let v: unknown
    if (Array.isArray(raw)) {
      v = raw[i]
    } else if (raw != null && typeof raw === 'object') {
      const o = raw as Record<string | number, unknown>
      v = o[i]
      if (v === undefined) {
        v = o[String(i)]
      }
    }
    out.push(typeof v === 'number' && Number.isFinite(v) ? v : undefined)
  }
  return out
}

function buildG10L1Line(
  toolIndex: number,
  tool: Record<string, unknown>,
  axes: ReadonlyArray<{ letter: string }>
): string | null {
  const off = normalizeToolOffsetsForAxes(tool, axes.length)
  if (off.length === 0) {
    return null
  }
  const parts: string[] = [`G10 L1 P${toolIndex}`]
  let any = false
  for (let i = 0; i < off.length; i++) {
    const v = off[i]
    const letter = axes[i]?.letter
    if (!letter || typeof letter !== 'string') {
      continue
    }
    if (v === undefined) {
      continue
    }
    parts.push(`${letter.toUpperCase()}${fmtAxis(v)}`)
    any = true
  }
  if (!any) {
    return null
  }
  return parts.join(' ')
}

function shouldIncludeToolIndex(
  toolIndex: number,
  tools: readonly unknown[],
  probeToolIndex: number,
  currentToolIndex: number
): boolean {
  const t = tools[toolIndex]
  if (!isToolRecord(t)) {
    return false
  }
  const inSpindle = toolIndex === currentToolIndex
  const isProbeSlot = probeToolIndex >= 0 && toolIndex === probeToolIndex
  if (!inSpindle && !isProbeSlot && !isNxtToolSlotConfiguredInLibrary(t)) {
    return false
  }
  return true
}

export type BuildNxtUserToolsGArgs = {
  /** ISO timestamp for file comment */
  generatedAt: string
  tools: readonly unknown[]
  firmwareGlobals: unknown
  /** Same order as `tools[n].offsets` (e.g. `move.axes` from the object model). */
  axes: ReadonlyArray<{ letter: string }>
  probeToolIndex: number
  currentToolIndex: number
}

/**
 * Full-file body for `/sys/nxt-user-tools.g` (no leading SD path).
 * Pair each M4000 with a G10 L1 line when offsets exist.
 */
export function buildNxtUserToolsGContent(args: BuildNxtUserToolsGArgs): string {
  const {
    generatedAt,
    tools,
    firmwareGlobals,
    axes,
    probeToolIndex,
    currentToolIndex
  } = args

  const defaultSpindleId = readDefaultSpindleId(firmwareGlobals)
  const lines: string[] = [
    '; nxt user tool library (persisted)',
    '; Auto-generated — Tool Library "Save to board", M4000/M4001 (nxt-user-tools-sync.g), or edit on SD.',
    `; Generated: ${generatedAt}`,
    '',
    '; Load order: nxt-tooltable.g then nxt-user-vars.g then this file.',
    '; M4000 defines M563 + mosTT; G10 L1 restores axis offsets per tool.',
    '; Wrapper: nxtUserToolsLoadDepth keeps M98 load from calling sync until the file finishes.',
    ...NXT_USER_TOOLS_LOAD_DEPTH_OPEN
  ]

  const indices: number[] = []
  for (let i = 0; i < tools.length; i++) {
    if (shouldIncludeToolIndex(i, tools, probeToolIndex, currentToolIndex)) {
      indices.push(i)
    }
  }

  if (
    currentToolIndex >= 0 &&
    currentToolIndex < tools.length &&
    !indices.includes(currentToolIndex) &&
    isToolRecord(tools[currentToolIndex])
  ) {
    indices.push(currentToolIndex)
  }

  indices.sort((a, b) => a - b)

  for (const i of indices) {
    const t = tools[i]
    if (!isToolRecord(t)) {
      continue
    }
    const rec = t as Record<string, unknown>
    lines.push(buildM4000Line(i, rec, firmwareGlobals, defaultSpindleId))
    const g10 = buildG10L1Line(i, rec, axes)
    if (g10) {
      lines.push(g10)
    }
    lines.push('')
  }

  lines.push(...NXT_USER_TOOLS_LOAD_DEPTH_CLOSE)

  return lines.join('\n').replace(/\n+$/, '\n')
}
