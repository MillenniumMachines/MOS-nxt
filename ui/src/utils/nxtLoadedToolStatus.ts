import { augmentRrfToolForNxtUi, readFirmwareGlobal } from './nxtToolChangerOm'
import { NXT_PROBE_TOOL_ID } from './nxtProbeToolId'

export type LoadedToolRole = 'none' | 'spindle' | 'probe'

export type LoadedToolStatus = {
  toolIndex: number | null
  name: string | null
  nameShort: string
  /** Legacy-style `T{n} — {name}` (or `T{n}` if unnamed). Empty when no tool. */
  label: string
  /** Same as label with a shortened name portion for compact chips. */
  labelShort: string
  radiusMm: number | null
  zOffset: number | null
  fluteCount: number | null
  fluteLengthMm: number | null
  role: LoadedToolRole
}

function shortenName(name: string, maxLen = 20): string {
  return name.length > maxLen ? `${name.substring(0, maxLen)}...` : name
}

/**
 * Legacy display: `T{n} — {name}` when M4000 S / tools[n].name is set, else `T{n}`.
 * Returns "" when index is invalid (caller shows “None”).
 */
export function formatToolLabel(
  index: number,
  name: string | null | undefined,
  options?: { shortenNameTo?: number }
): string {
  if (typeof index !== 'number' || !Number.isFinite(index) || index < 0) {
    return ''
  }
  const raw = typeof name === 'string' ? name.trim() : ''
  if (raw.length === 0) {
    return `T${index}`
  }
  const maxLen = options?.shortenNameTo
  const display =
    typeof maxLen === 'number' && maxLen > 0 && raw.length > maxLen
      ? shortenName(raw, maxLen)
      : raw
  return `T${index} — ${display}`
}

/** Resolve tools[n].name then {@link formatToolLabel}. */
export function formatToolLabelFromTools(
  tools: unknown,
  index: number,
  options?: { shortenNameTo?: number }
): string {
  if (typeof index !== 'number' || !Number.isFinite(index) || index < 0 || !Array.isArray(tools)) {
    return formatToolLabel(index, null, options)
  }
  const toolObj = tools[index]
  const name =
    toolObj != null &&
    typeof toolObj === 'object' &&
    typeof (toolObj as { name?: unknown }).name === 'string'
      ? (toolObj as { name: string }).name
      : null
  return formatToolLabel(index, name, options)
}

function resolveProbeToolIndex(firmwareGlobals: unknown): number {
  const probe = readFirmwareGlobal(firmwareGlobals, 'nxtProbeToolID')
  if (typeof probe === 'number' && probe >= 0) {
    return probe
  }
  const legacy = readFirmwareGlobal(firmwareGlobals, 'mosPTID')
  return typeof legacy === 'number' && legacy >= 0 ? legacy : NXT_PROBE_TOOL_ID
}

export function buildLoadedToolStatus(
  tools: unknown,
  currentToolIndex: number,
  firmwareGlobals: unknown
): LoadedToolStatus {
  const empty: LoadedToolStatus = {
    toolIndex: null,
    name: null,
    nameShort: '',
    label: '',
    labelShort: '',
    radiusMm: null,
    zOffset: null,
    fluteCount: null,
    fluteLengthMm: null,
    role: 'none'
  }
  if (currentToolIndex < 0 || !Array.isArray(tools)) {
    return empty
  }
  const toolObj = tools[currentToolIndex]
  if (toolObj == null) {
    return empty
  }
  const augmented = augmentRrfToolForNxtUi(toolObj, firmwareGlobals, currentToolIndex)
  const name =
    typeof augmented.name === 'string' && augmented.name.length > 0 ? augmented.name : null
  const offsets =
    toolObj != null && typeof toolObj === 'object'
      ? (toolObj as { offsets?: number[] }).offsets
      : undefined
  const zOffset =
    Array.isArray(offsets) && offsets.length > 2 && Number.isFinite(offsets[2]) ? offsets[2] : null
  const probeIndex = resolveProbeToolIndex(firmwareGlobals)
  const role: LoadedToolRole =
    probeIndex >= 0 && currentToolIndex === probeIndex ? 'probe' : 'spindle'
  return {
    toolIndex: currentToolIndex,
    name,
    nameShort: name != null ? shortenName(name) : '',
    label: formatToolLabel(currentToolIndex, name),
    labelShort: formatToolLabel(currentToolIndex, name, { shortenNameTo: 20 }),
    radiusMm: augmented.nxtRadiusMm,
    zOffset,
    fluteCount: augmented.nxtFluteCount,
    fluteLengthMm: augmented.nxtFluteLengthMm,
    role: currentToolIndex >= 0 ? role : 'none'
  }
}
