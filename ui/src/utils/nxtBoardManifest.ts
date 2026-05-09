/**
 * Board pack metadata for NeXT Configuration UI and nxt-board-pack-loader.g.
 * Bundled shortName values must match RRF boards[0].shortName (verify on hardware, M409).
 */

export type NxtPlatformId = 'v1.5' | 'v1.6_v2' | 'atlas'

export type NxtBoardVariantKind = 'single' | 'motor-24v-48v'

/** @deprecated Legacy UI key; use shortName + nxtScyllaMotorVoltage */
export type NxtBoardKitKey = 'fly_cdyv3' | 'scylla_24' | 'scylla_48'

export type NxtBundledBoardMeta = {
  shortName: string
  title: string
  variant: NxtBoardVariantKind
}

export const NXT_PLATFORM_OPTIONS: Array<{ value: NxtPlatformId; title: string }> = [
  { value: 'v1.5', title: 'Milo v1.5' },
  { value: 'v1.6_v2', title: 'Milo v1.6 / v2.0 (baseline board tree)' },
  { value: 'atlas', title: 'Atlas (bundled boards not yet shipped)' }
]

/** Boards with vendored packs under nxt/config/{platform}/boards/ */
export const NXT_BUNDLED_BOARDS: NxtBundledBoardMeta[] = [
  { shortName: 'cdy3_f4', title: 'Fly CDYv3', variant: 'single' },
  { shortName: 'scylla1_0_h723', title: 'Scylla v1.0', variant: 'motor-24v-48v' }
]

export function bundledBoardMeta(shortName: string | null | undefined): NxtBundledBoardMeta | null {
  if (shortName == null || typeof shortName !== 'string') {
    return null
  }
  const s = shortName.trim()
  return NXT_BUNDLED_BOARDS.find((b) => b.shortName === s) ?? null
}

/** Select items for platform (v1.5 / v1.6_v2 only have packs today). */
export function boardProfileSelectItems(
  platform: NxtPlatformId | null | undefined
): Array<{ value: string; title: string }> {
  if (platform !== 'v1.5' && platform !== 'v1.6_v2') {
    return []
  }
  return NXT_BUNDLED_BOARDS.map((b) => ({
    value: b.shortName,
    title: `${b.title} (${b.shortName})`
  }))
}

export const NXT_SCYLLA_MOTOR_VOLTAGE_ITEMS: Array<{ value: number; title: string }> = [
  { value: 24, title: '24 V motor supply' },
  { value: 48, title: '48 V motor supply' }
]

/** Config folder under 0:/sys/nxt/config/ */
export function nxtKitConfigBase(platform: NxtPlatformId | null | undefined): string | null {
  if (platform === 'v1.6_v2') {
    return 'nxt/config/v1.6_v2'
  }
  if (platform === 'v1.5') {
    return 'nxt/config/v1.5'
  }
  return null
}

/**
 * Relative path from 0:/sys/ to the board pack entry macro, or null if incomplete (e.g. Scylla without voltage).
 */
export function nxtBoardPackRelPath(
  platform: NxtPlatformId | null | undefined,
  boardShortName: string | null | undefined,
  motorVoltage: number | null | undefined
): string | null {
  const base = nxtKitConfigBase(platform)
  if (!base || boardShortName == null || boardShortName === '') {
    return null
  }
  const sn = String(boardShortName).trim()
  if (sn === 'cdy3_f4') {
    return `${base}/boards/cdy3_f4/entry.g`
  }
  if (sn === 'scylla1_0_h723') {
    if (motorVoltage === 48) {
      return `${base}/boards/scylla1_0_h723/motor-48v/entry.g`
    }
    if (motorVoltage === 24) {
      return `${base}/boards/scylla1_0_h723/motor-24v/entry.g`
    }
    return null
  }
  return null
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
  fly_cdyv3: nxtKitEntryPath('v1.5', 'fly_cdyv3'),
  scylla_24: nxtKitEntryPath('v1.5', 'scylla_24'),
  scylla_48: nxtKitEntryPath('v1.5', 'scylla_48')
}

/** RRF boards[0].shortName when it matches a bundled pack (firmware-defined strings). */
export function suggestBundledBoardShortName(shortName: string | null | undefined): string | null {
  if (shortName == null || typeof shortName !== 'string') {
    return null
  }
  const s = shortName.trim()
  return bundledBoardMeta(s) != null ? s : null
}

export type GpOutItem = { id: number; name: string }

export function gpOutItemsForBoard(
  boardShortName: string | null | undefined,
  maxPorts: number
): GpOutItem[] {
  const n = Math.max(0, Math.min(maxPorts, 32))
  const meta = bundledBoardMeta(boardShortName)
  const prefix =
    boardShortName === 'cdy3_f4'
      ? 'Fly CDYv3'
      : boardShortName === 'scylla1_0_h723'
        ? 'Scylla'
        : meta != null
          ? meta.title
          : 'GP out'
  return Array.from({ length: n }, (_, i) => ({
    id: i,
    name: `${prefix} — out ${i}`
  }))
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
  if (kit === 'fly_cdyv3') {
    return { shortName: 'cdy3_f4', motorVoltage: null }
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
  if (s === 'cdy3_f4') {
    return 'fly_cdyv3'
  }
  if (s === 'scylla1_0_h723') {
    return 'scylla_24'
  }
  return null
}

/** @deprecated */
export function applyKitKeyToGlobals(
  kit: NxtBoardKitKey
): { nxtBoardKitKey: NxtBoardKitKey; nxtScyllaMotorVoltage: number | null } {
  if (kit === 'scylla_48') {
    return { nxtBoardKitKey: kit, nxtScyllaMotorVoltage: 48 }
  }
  if (kit === 'scylla_24') {
    return { nxtBoardKitKey: kit, nxtScyllaMotorVoltage: 24 }
  }
  return { nxtBoardKitKey: kit, nxtScyllaMotorVoltage: null }
}
