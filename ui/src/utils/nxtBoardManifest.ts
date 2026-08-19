/**
 * Board pack metadata for nxt Configuration UI and nxt-board-pack-loader.g.
 * Boards: nxt-config/board/<shortName>/ — machines: nxt-config/machine/<profile>/.
 */
import {
  boardEntriesList,
  machinesList,
  nxtBoardPackFromManifest,
  nxtConfigManifest,
  nxtMachineFromManifest,
  nxtPlatformFromManifest
} from './nxtConfigManifestData'

export type NxtPlatformId = string

export type NxtBoardVariantKind = 'single' | 'motor-24v-48v'

/** @deprecated Legacy UI key; use shortName + nxtBoardMotorVoltage */
export type NxtBoardKitKey = 'fly_cdyv3' | 'scylla_24' | 'scylla_48'

export type NxtBundledBoardMeta = {
  shortName: string
  title: string
  variant: NxtBoardVariantKind
}

const BOARD_TITLE_OVERRIDE: Record<string, string> = {
  scylla1_0_h723: 'Scylla v1.0'
}

function machineDisplayTitle(id: string, overviewTitle: string): string {
  if (id === 'v1.5') {
    return 'Milo v1.5'
  }
  if (id === 'v1.6') {
    return 'Milo v1.6'
  }
  if (id === 'v2.0-milo' || id === 'v2.0') {
    return 'V2.0 Milo'
  }
  if (id === 'v2.0-miley') {
    return 'V2.0 Miley'
  }
  if (id === 'custom') {
    return 'Custom'
  }
  return overviewTitle.replace(/\s*(nxt)\s*$/i, '').trim() || id
}

/** Migrate legacy platform ids (combined v1.6_v2; unsplit v2.0). */
export function migratePlatformProfileId(id: string | null | undefined): string | null {
  if (id == null || typeof id !== 'string') {
    return null
  }
  const s = id.trim()
  if (s === '') {
    return null
  }
  if (s === 'v1.6_v2') {
    return 'v1.6'
  }
  if (s === 'v2.0') {
    return 'v2.0-milo'
  }
  return s
}

export const NXT_PLATFORM_OPTIONS: Array<{ value: NxtPlatformId; title: string }> =
  machinesList().map((m) => ({
    value: m.id,
    title: machineDisplayTitle(m.id, m.title)
  }))

/** Boards with vendored packs (from nxt-config/board/, not per-machine). */
export const NXT_BUNDLED_BOARDS: NxtBundledBoardMeta[] = (nxtConfigManifest.boards ?? []).map(
  (b) => ({
    shortName: b.shortName,
    title: b.title,
    variant: b.variant as NxtBoardVariantKind
  })
)

export function bundledBoardMeta(shortName: string | null | undefined): NxtBundledBoardMeta | null {
  if (shortName == null || typeof shortName !== 'string') {
    return null
  }
  const s = shortName.trim()
  return NXT_BUNDLED_BOARDS.find((b) => b.shortName === s) ?? null
}

/** Board profiles (independent of machine profile selection). */
export function boardProfileSelectItems(
  _platform?: NxtPlatformId | null | undefined
): Array<{ value: string; title: string }> {
  const seen = new Set<string>()
  const items: Array<{ value: string; title: string }> = []
  for (const b of boardEntriesList()) {
    if (seen.has(b.shortName)) {
      continue
    }
    seen.add(b.shortName)
    const title = BOARD_TITLE_OVERRIDE[b.shortName] ?? b.title.split(' (')[0]
    items.push({ value: b.shortName, title: `${title} (${b.shortName})` })
  }
  return items
}

export const NXT_SCYLLA_MOTOR_VOLTAGE_ITEMS: Array<{ value: number; title: string }> = [
  { value: 24, title: '24 V motor supply' },
  { value: 48, title: '48 V motor supply' }
]

/** Machine config folder on SD (0:/sys/nxt-config/machine/<id>/). */
export function nxtMachineConfigBase(machineId: NxtPlatformId | null | undefined): string | null {
  if (machineId == null || machineId === '') {
    return null
  }
  if (nxtMachineFromManifest(machineId)) {
    return `0:/sys/nxt-config/machine/${machineId}`
  }
  return null
}

/** @deprecated Use nxtMachineConfigBase */
export function nxtKitConfigBase(platform: NxtPlatformId | null | undefined): string | null {
  return nxtMachineConfigBase(platform)
}

/**
 * Relative path from 0:/sys/ to the board pack entry macro (nxt-config/board/...).
 */
export function nxtBoardPackRelPath(
  _platform: NxtPlatformId | null | undefined,
  boardShortName: string | null | undefined,
  motorVoltage: number | null | undefined
): string | null {
  if (boardShortName == null || boardShortName === '') {
    return null
  }
  const sn = String(boardShortName).trim()
  if (motorVoltage === 48) {
    const b = boardEntriesList().find((x) => x.shortName === sn && x.variant === '48v')
    return b?.entryPath ?? null
  }
  if (motorVoltage === 24) {
    const b = boardEntriesList().find((x) => x.shortName === sn && x.variant === '24v')
    return b?.entryPath ?? null
  }
  const b = boardEntriesList().find((x) => x.shortName === sn && x.variant == null)
  return b?.entryPath ?? null
}

/** Machine pack entry path (boot loads after board pack). */
export function nxtMachinePackRelPath(machineId: NxtPlatformId | null | undefined): string | null {
  const m = nxtMachineFromManifest(machineId)
  return m?.machineEntryPath ?? null
}

/** @deprecated Use nxtBoardPackRelPath */
export function nxtKitEntryPath(
  platform: NxtPlatformId | null | undefined,
  kit: NxtBoardKitKey
): string | null {
  const m = migrateLegacyBoardKitKey(kit)
  if (!m) {
    return null
  }
  return nxtBoardPackRelPath(platform, m.shortName, m.motorVoltage)
}

/** @deprecated */
export const NXT_KIT_ENTRY_PATH: Record<NxtBoardKitKey, string | null> = {
  fly_cdyv3: null,
  scylla_24: nxtKitEntryPath('v1.5', 'scylla_24'),
  scylla_48: nxtKitEntryPath('v1.5', 'scylla_48')
}

export function suggestBundledBoardShortName(shortName: string | null | undefined): string | null {
  if (shortName == null || typeof shortName !== 'string') {
    return null
  }
  const s = shortName.trim()
  return bundledBoardMeta(s) != null ? s : null
}

export type GpOutItem = {
  id: number
  name: string
  /** When true, another role already owns this pin — show but do not select. */
  disabled?: boolean
  pinLabel?: string
}

export type ProbeSelectItem = {
  id: number
  name: string
  type: number
  disabled?: boolean
  pinLabel?: string
}

export type GpOutRoleOccupancy = {
  nxtRelayID?: number | null
  nxtAux1ID?: number | null
  nxtAux2ID?: number | null
  nxtAux3ID?: number | null
  nxtCoolantAirID?: number | null
  nxtCoolantMistID?: number | null
  nxtCoolantFloodID?: number | null
}

export type ProbeRoleOccupancy = {
  nxtTouchProbeID?: number | null
  nxtToolSetterID?: number | null
}

const GPOUT_ROLE_LABELS: Array<{ key: keyof GpOutRoleOccupancy; label: string }> = [
  { key: 'nxtRelayID', label: 'Relay' },
  { key: 'nxtAux1ID', label: 'Aux 0' },
  { key: 'nxtAux2ID', label: 'Aux 1' },
  { key: 'nxtAux3ID', label: 'Aux 2' },
  { key: 'nxtCoolantAirID', label: 'Air' },
  { key: 'nxtCoolantMistID', label: 'Mist' },
  { key: 'nxtCoolantFloodID', label: 'Flood' }
]

/** Canonical Scylla named-output create order (matches gpio.g; relay is P5, not a fan). */
export const NXT_NAMED_OUTPUT_ALIASES = [
  'aux0',
  'aux1',
  'aux2',
  'coolant',
  'mist'
] as const

export type NxtNamedOutputAlias = (typeof NXT_NAMED_OUTPUT_ALIASES)[number]

/** Default tool fan pin; aux outputs are 24V regardless of motor pack voltage. */
export function defaultBoardFanPinsForVoltage(
  _voltage: number | null | undefined
): string[] {
  return ['aux0']
}

/** True when the board pinmap assigns a fixed motor/VFD relay (hide picker, no hold-to-test). */
export function boardHasAtxMotorRelay(boardShortName: string | null | undefined): boolean {
  const pack = nxtBoardPackFromManifest(boardShortName)
  const assigned = pack?.pinmap?.assigned ?? []
  return assigned.some(
    (p) => p.id === 'motor_relay' || (p.aliases != null && p.aliases.includes('relay'))
  )
}

/** gpOut index for the board-assigned motor relay, or null. */
export function boardMotorRelayGpOutIndex(
  boardShortName: string | null | undefined
): number | null {
  const pack = nxtBoardPackFromManifest(boardShortName)
  const assigned = pack?.pinmap?.assigned ?? []
  const pin = assigned.find(
    (p) => p.id === 'motor_relay' || (p.aliases != null && p.aliases.includes('relay'))
  )
  if (pin != null && typeof pin.gpOutIndex === 'number' && pin.gpOutIndex >= 0) {
    return pin.gpOutIndex
  }
  return null
}

/**
 * Fan index (M106 P) for a pin alias, given create order among fan pins.
 * Matches Scylla gpio.g sequential F0…Fn assignment.
 */
export function fanIndexForPinAlias(
  fanPins: string[] | null | undefined,
  alias: string
): number | null {
  if (fanPins == null || fanPins.length === 0) {
    return null
  }
  const set = new Set(fanPins.map((p) => String(p).toLowerCase()))
  let idx = 0
  for (const name of NXT_NAMED_OUTPUT_ALIASES) {
    if (!set.has(name)) {
      continue
    }
    if (name === alias) {
      return idx
    }
    idx += 1
  }
  return null
}

export function namedOutputSelectItems(
  boardShortName: string | null | undefined
): Array<{ value: string; title: string }> {
  const pack = nxtBoardPackFromManifest(boardShortName)
  const named =
    (pack?.pinmap as { namedOutputs?: string[] } | null)?.namedOutputs ??
    [...NXT_NAMED_OUTPUT_ALIASES]
  const free = pack?.pinmap?.free ?? []
  return named.map((id) => {
    const hit = free.find((p) => p.id === id || p.aliases?.includes(id))
    return {
      value: id,
      title: hit?.label ? `${hit.label} (${id})` : id
    }
  })
}

const PROBE_ROLE_LABELS: Array<{ key: keyof ProbeRoleOccupancy; label: string }> = [
  { key: 'nxtTouchProbeID', label: 'Touch probe' },
  { key: 'nxtToolSetterID', label: 'Toolsetter' }
]

export function gpOutRoleLabelForId(
  id: number,
  occupancy: GpOutRoleOccupancy | null | undefined
): string | null {
  if (occupancy == null) {
    return null
  }
  const labels: string[] = []
  for (const { key, label } of GPOUT_ROLE_LABELS) {
    if (occupancy[key] === id) {
      labels.push(label)
    }
  }
  return labels.length ? labels.join(', ') : null
}

export function probeRoleLabelForId(
  id: number,
  occupancy: ProbeRoleOccupancy | null | undefined
): string | null {
  if (occupancy == null) {
    return null
  }
  const labels: string[] = []
  for (const { key, label } of PROBE_ROLE_LABELS) {
    if (occupancy[key] === id) {
      labels.push(label)
    }
  }
  return labels.length ? labels.join(', ') : null
}

/**
 * Pin literal for M558 C"…" from board pinmap.
 * Prefer hardware pin (matches board toolsetter.g / touchprobe.g); fall back to alias.
 * Does not include invert (`!`) prefix.
 */
export function probePinLiteralForIndex(
  boardShortName: string | null | undefined,
  probeIndex: number | null | undefined
): string | null {
  if (probeIndex == null || probeIndex < 0) {
    return null
  }
  const pack = nxtBoardPackFromManifest(boardShortName)
  const entries = [...(pack?.pinmap?.assigned ?? []), ...(pack?.pinmap?.free ?? [])]
  const hit = entries.find(
    (p) => p.kind === 'probe' && p.probeIndex === probeIndex
  )
  if (hit == null) {
    return null
  }
  if (hit.pin != null && String(hit.pin).trim().length > 0) {
    return String(hit.pin).trim().replace(/^!/, '')
  }
  const alias = hit.aliases?.find((a) => typeof a === 'string' && a.trim().length > 0)
  if (alias) {
    return String(alias).trim().replace(/^!/, '')
  }
  return null
}

/** Build M558 pin argument with optional active-low invert (`!` prefix). */
export function formatProbeM558Pin(pinLiteral: string, invert: boolean): string {
  const bare = String(pinLiteral).trim().replace(/^!+/, '')
  return invert ? `!${bare}` : bare
}

/**
 * RRF M558 requires P (probe type) whenever the probe is (re)configured.
 * Prefer live OM type; else role/index defaults (touch=P5, toolsetter=P8).
 */
export function resolveProbeM558Type(
  omType: number | null | undefined,
  probeIndex: number,
  roleHint?: 'touch' | 'toolsetter' | null
): number {
  if (omType != null && omType >= 5 && omType <= 11) {
    return omType
  }
  if (roleHint === 'toolsetter' || probeIndex === 1) {
    return 8
  }
  if (roleHint === 'touch' || probeIndex === 0) {
    return 5
  }
  return 8
}

/** Full M558 line to set pin polarity without dropping required P. */
export function buildProbeM558PinCommand(opts: {
  probeId: number
  pinLiteral: string
  invert: boolean
  type: number
}): string {
  const c = formatProbeM558Pin(opts.pinLiteral, opts.invert)
  return `M558 K${opts.probeId} P${opts.type} C"${c}"`
}

function formatPinSelectName(label: string, pin: string | undefined): string {
  return pin != null && pin.length > 0 ? `${label} (${pin})` : label
}

function probeTypeLabel(t: number): string {
  if (t === 5) return 'switch'
  if (t === 6) return 'digital'
  if (t === 7) return 'filtered'
  if (t === 8) return 'analog'
  return `type ${t}`
}

/**
 * Named gpOut options from board pinmap free[] (kind gpout), with occupancy disable.
 * Falls back to Output N when the board has no named free outputs.
 */
export function gpOutItemsForBoard(
  boardShortName: string | null | undefined,
  maxPorts: number,
  occupancy?: GpOutRoleOccupancy | null,
  options?: {
    currentRoleKey?: keyof GpOutRoleOccupancy | null
    motorVoltage?: number | null
  }
): GpOutItem[] {
  const pack = nxtBoardPackFromManifest(boardShortName)
  const free = (pack?.pinmap?.free ?? []).filter(
    (p) => p.kind === 'gpout' && typeof p.gpOutIndex === 'number' && p.gpOutIndex >= 0
  )
  const currentKey = options?.currentRoleKey ?? null
  const currentId =
    currentKey != null && occupancy != null ? occupancy[currentKey] ?? null : null

  if (free.length > 0) {
    return free
      .map((p) => {
        const id = p.gpOutIndex as number
        const role = gpOutRoleLabelForId(id, occupancy)
        const ownedByOther = role != null && id !== currentId
        let label = p.label ?? p.aliases?.[0] ?? `Output ${id}`
        let pin = p.pin
        // Keep the human pin name clean; occupancy only disables the row.
        const name = ownedByOther
          ? `${formatPinSelectName(label, pin)} — used by ${role}`
          : formatPinSelectName(label, pin)
        return {
          id,
          pinLabel: label,
          name,
          disabled: ownedByOther
        }
      })
      .sort((a, b) => a.id - b.id)
  }

  const n = Math.max(0, Math.min(maxPorts, 32))
  return Array.from({ length: n }, (_, i) => {
    const role = gpOutRoleLabelForId(i, occupancy)
    const ownedByOther = role != null && i !== currentId
    return {
      id: i,
      pinLabel: `Output ${i}`,
      name: ownedByOther ? `Output ${i} — used by ${role}` : `Output ${i}`,
      disabled: ownedByOther
    }
  })
}

/**
 * Probe / toolsetter options from board pinmap (Probe, Toolsetter as separate pins).
 * OM probes enrich type when present; pinmap entries stay selectable even if not yet in OM.
 */
export function probeSelectItemsForBoard(
  boardShortName: string | null | undefined,
  omProbes: Array<{ id: number; type: number }>,
  occupancy?: ProbeRoleOccupancy | null,
  options?: { currentRoleKey?: keyof ProbeRoleOccupancy | null }
): ProbeSelectItem[] {
  const pack = nxtBoardPackFromManifest(boardShortName)
  const pinProbes = [
    ...(pack?.pinmap?.assigned ?? []),
    ...(pack?.pinmap?.free ?? [])
  ].filter((p) => p.kind === 'probe' && typeof p.probeIndex === 'number')

  const byId = new Map<number, ProbeSelectItem>()
  const currentKey = options?.currentRoleKey ?? null
  const currentId =
    currentKey != null && occupancy != null ? occupancy[currentKey] ?? null : null

  for (const p of pinProbes) {
    const id = p.probeIndex as number
    const role = probeRoleLabelForId(id, occupancy)
    const ownedByOther = role != null && id !== currentId
    const label = p.label ?? p.aliases?.[0] ?? `Probe ${id}`
    const om = omProbes.find((o) => o.id === id)
    const type = om?.type && om.type > 0 ? om.type : 0
    const base = formatPinSelectName(label, p.pin)
    byId.set(id, {
      id,
      type,
      pinLabel: label,
      name: ownedByOther ? `${base} — used by ${role}` : base,
      disabled: ownedByOther
    })
  }

  for (const om of omProbes) {
    // Skip empty / unused probe slots (type 0).
    if (!om.type || om.type < 5 || om.type > 8) {
      continue
    }
    const existing = byId.get(om.id)
    if (existing) {
      existing.type = om.type
      continue
    }
    const role = probeRoleLabelForId(om.id, occupancy)
    const ownedByOther = role != null && om.id !== currentId
    const label = `Probe ${om.id}`
    const base = `${label} (${probeTypeLabel(om.type)})`
    byId.set(om.id, {
      id: om.id,
      type: om.type,
      pinLabel: label,
      name: ownedByOther ? `${base} — used by ${role}` : base,
      disabled: ownedByOther
    })
  }

  return Array.from(byId.values()).sort((a, b) => a.id - b.id)
}

/** Keys that share the gpOut pool (mutual exclusion). */
export const NXT_GPOUT_ROLE_KEYS = [
  'nxtRelayID',
  'nxtAux1ID',
  'nxtAux2ID',
  'nxtAux3ID',
  'nxtCoolantAirID',
  'nxtCoolantMistID',
  'nxtCoolantFloodID'
] as const

export type NxtGpOutRoleKey = (typeof NXT_GPOUT_ROLE_KEYS)[number]

export const NXT_PROBE_ROLE_KEYS = ['nxtTouchProbeID', 'nxtToolSetterID'] as const

export type NxtProbeRoleKey = (typeof NXT_PROBE_ROLE_KEYS)[number]

/** Keys that share the Custom endstop pin pool (mutual exclusion). */
export const NXT_CUSTOM_ENDSTOP_ROLE_KEYS = [
  'nxtCustomXEndstopPin',
  'nxtCustomYEndstopPin',
  'nxtCustomZEndstopPin',
  'nxtCustomAEndstopPin'
] as const

export type NxtCustomEndstopRoleKey = (typeof NXT_CUSTOM_ENDSTOP_ROLE_KEYS)[number]

export type CustomEndstopRoleOccupancy = {
  nxtCustomXEndstopPin?: string | null
  nxtCustomYEndstopPin?: string | null
  nxtCustomZEndstopPin?: string | null
  nxtCustomAEndstopPin?: string | null
}

export type EndstopPinSelectItem = {
  value: string
  title: string
  disabled?: boolean
  pinLabel?: string
}

const CUSTOM_ENDSTOP_ROLE_LABELS: Array<{ key: keyof CustomEndstopRoleOccupancy; label: string }> = [
  { key: 'nxtCustomXEndstopPin', label: 'X' },
  { key: 'nxtCustomYEndstopPin', label: 'Y' },
  { key: 'nxtCustomZEndstopPin', label: 'Z' },
  { key: 'nxtCustomAEndstopPin', label: 'A' }
]

/** Split "+" joined endstop pin lists (dual homing). */
export function parseCustomEndstopPins(raw: string | null | undefined): string[] {
  if (raw == null || !String(raw).trim()) return []
  return String(raw)
    .split('+')
    .map((s) => s.replace(/"/g, '').trim())
    .filter((s) => s.length > 0)
}

export function customEndstopRoleLabelForPin(
  pin: string,
  occupancy: CustomEndstopRoleOccupancy | null | undefined
): string | null {
  if (occupancy == null || !pin) {
    return null
  }
  const labels: string[] = []
  for (const { key, label } of CUSTOM_ENDSTOP_ROLE_LABELS) {
    const owned = occupancy[key]
    const pins = parseCustomEndstopPins(owned)
    if (pins.includes(pin)) {
      labels.push(label)
    }
  }
  return labels.length ? labels.join(', ') : null
}

/** Endstop pin options from board pinmap for Custom M574 remapping. */
export function endstopPinItemsForBoard(
  boardShortName: string | null | undefined,
  occupancy?: CustomEndstopRoleOccupancy | null,
  options?: { currentRoleKey?: NxtCustomEndstopRoleKey | null }
): EndstopPinSelectItem[] {
  const pack = nxtBoardPackFromManifest(boardShortName)
  const entries = [...(pack?.pinmap?.assigned ?? []), ...(pack?.pinmap?.free ?? [])].filter(
    (p) => p.kind === 'endstop'
  )
  const currentKey = options?.currentRoleKey ?? null
  const currentPins =
    currentKey != null && occupancy != null
      ? parseCustomEndstopPins(occupancy[currentKey] ?? null)
      : []

  const byPin = new Map<string, EndstopPinSelectItem>()
  for (const p of entries) {
    if (p.pin == null || !String(p.pin).trim()) continue
    const pin = String(p.pin).trim()
    const assignment = (p.aliases?.[0] ?? p.label ?? pin).trim()
    const role = customEndstopRoleLabelForPin(pin, occupancy)
    const ownedByOther = role != null && !currentPins.includes(pin)
    const base = formatPinSelectName(assignment, pin)
    byPin.set(pin, {
      value: pin,
      title: ownedByOther ? `${base} — used by ${role}` : base,
      pinLabel: assignment,
      disabled: ownedByOther
    })
  }

  return Array.from(byPin.values()).sort((a, b) => a.title.localeCompare(b.title))
}

/** @deprecated Use gpOutItemsForBoard */
export function gpOutItemsForKit(kitKey: NxtBoardKitKey | null | undefined, maxPorts: number): GpOutItem[] {
  const m = migrateLegacyBoardKitKey(kitKey)
  return gpOutItemsForBoard(m?.shortName ?? null, maxPorts)
}

export function migrateLegacyBoardKitKey(
  kit: NxtBoardKitKey | null | undefined
): { shortName: string; motorVoltage: number | null } | null {
  if (kit == null || kit === ('' as any)) {
    return null
  }
  // Fly CDYv3 is not supported on RRF 3.7 — treat as unset so the UI re-prompts.
  if (kit === 'fly_cdyv3') {
    return null
  }
  if (kit === 'scylla_24') {
    return { shortName: 'scylla1_0_h723', motorVoltage: 24 }
  }
  if (kit === 'scylla_48') {
    return { shortName: 'scylla1_0_h723', motorVoltage: 48 }
  }
  return null
}

/** @deprecated */
export function suggestKitKeyFromBoardShortName(shortName: string | null | undefined): NxtBoardKitKey | null {
  const s = suggestBundledBoardShortName(shortName)
  if (s === 'scylla1_0_h723') {
    return 'scylla_24'
  }
  return null
}

/** @deprecated */
export function applyKitKeyToGlobals(
  kit: NxtBoardKitKey
): { nxtBoardKitKey: NxtBoardKitKey; nxtBoardMotorVoltage: number | null } {
  if (kit === 'scylla_48') {
    return { nxtBoardKitKey: kit, nxtBoardMotorVoltage: 48 }
  }
  if (kit === 'scylla_24') {
    return { nxtBoardKitKey: kit, nxtBoardMotorVoltage: 24 }
  }
  return { nxtBoardKitKey: kit, nxtBoardMotorVoltage: null }
}

export function platformStructureSummary(
  machineId: NxtPlatformId | null | undefined,
  boardShortName?: string | null
): {
  sysDeployFiles: string[]
  boardEntryPaths: string[]
  machineEntryPath: string | null
  boardTxtPath: string | null
} {
  const m = nxtMachineFromManifest(machineId)
  const pack = nxtBoardPackFromManifest(boardShortName)
  const boardTxtPath =
    pack?.boardTxtPath != null && String(pack.boardTxtPath).trim() !== ''
      ? String(pack.boardTxtPath)
      : null
  if (!m) {
    return { sysDeployFiles: [], boardEntryPaths: [], machineEntryPath: null, boardTxtPath }
  }
  return {
    sysDeployFiles: [...m.sysDeployFiles],
    boardEntryPaths: boardEntriesList().map((b) => b.entryPath),
    machineEntryPath: m.machineEntryPath,
    boardTxtPath
  }
}
