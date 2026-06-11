import { augmentRrfToolForNeXtUi, readFirmwareGlobal } from './nxtToolChangerOm'

export type LoadedToolRole = 'none' | 'spindle' | 'probe'

export type LoadedToolStatus = {
  toolIndex: number | null
  name: string | null
  nameShort: string
  radiusMm: number | null
  zOffset: number | null
  fluteCount: number | null
  fluteLengthMm: number | null
  role: LoadedToolRole
}

function shortenName(name: string, maxLen = 20): string {
  return name.length > maxLen ? `${name.substring(0, maxLen)}...` : name
}

function resolveProbeToolIndex(firmwareGlobals: unknown): number {
  const probe = readFirmwareGlobal(firmwareGlobals, 'nxtProbeToolID')
  if (typeof probe === 'number' && probe >= 0) {
    return probe
  }
  const legacy = readFirmwareGlobal(firmwareGlobals, 'mosPTID')
  return typeof legacy === 'number' && legacy >= 0 ? legacy : -1
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
  const augmented = augmentRrfToolForNeXtUi(toolObj, firmwareGlobals, currentToolIndex)
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
    radiusMm: augmented.nxtRadiusMm,
    zOffset,
    fluteCount: augmented.nxtFluteCount,
    fluteLengthMm: augmented.nxtFluteLengthMm,
    role: currentToolIndex >= 0 ? role : 'none'
  }
}
