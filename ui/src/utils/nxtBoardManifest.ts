/**
 * Board pack metadata for NeXT Configuration UI and nxt-board-pack-loader.g.
 * Platform and board lists are driven by ui/src/generated/nxtConfigManifest.json.
 */
import { nxtConfigManifest, nxtPlatformFromManifest } from './nxtConfigManifestData'

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
  cdy3_f4: 'Fly CDYv3',
  scylla1_0_h723: 'Scylla v1.0'
}

function platformDisplayTitle(id: string, overviewTitle: string): string {
  if (id === 'v1.5') {
    return 'Milo v1.5'
  }
  if (id === 'v1.6_v2') {
    return 'Milo v1.6 / v2.0'
  }
  return overviewTitle.replace(/\s*\(NeXT\)\s*$/i, '').trim() || id
}

export const NXT_PLATFORM_OPTIONS: Array<{ value: NxtPlatformId; title: string }> =
  nxtConfigManifest.platforms.map((p) => ({
    value: p.id,
    title: platformDisplayTitle(p.id, p.title)
  }))

function boardsForPlatform(platform: NxtPlatformId | null | undefined) {
  return nxtPlatformFromManifest(platform)?.boards ?? []
}

/** Boards with vendored packs (union across platforms in manifest). */
export const NXT_BUNDLED_BOARDS: NxtBundledBoardMeta[] = (() => {
  const byShort = new Map<string, NxtBundledBoardMeta>()
  for (const plat of nxtConfigManifest.platforms) {
    for (const b of plat.boards) {
      if (byShort.has(b.shortName)) {
        continue
      }
      const hasMotorVariant = plat.boards.some(
        (x) => x.shortName === b.shortName && x.variant != null
      )
      byShort.set(b.shortName, {
        shortName: b.shortName,
        title: BOARD_TITLE_OVERRIDE[b.shortName] ?? b.title.split(' (')[0],
        variant: hasMotorVariant ? 'motor-24v-48v' : 'single'
      })
    }
  }
  return [...byShort.values()]
})()

export function bundledBoardMeta(shortName: string | null | undefined): NxtBundledBoardMeta | null {
  if (shortName == null || typeof shortName !== 'string') {
    return null
  }
  const s = shortName.trim()
  return NXT_BUNDLED_BOARDS.find((b) => b.shortName === s) ?? null
}

export function boardProfileSelectItems(
  platform: NxtPlatformId | null | undefined
): Array<{ value: string; title: string }> {
  const boards = boardsForPlatform(platform)
  const seen = new Set<string>()
  const items: Array<{ value: string; title: string }> = []
  for (const b of boards) {
    if (seen.has(b.shortName)) {
      continue
    }
    seen.add(b.shortName)
    const title = BOARD_TITLE_OVERRIDE[b.shortName] ?? b.title
    items.push({ value: b.shortName, title: `${title} (${b.shortName})` })
  }
  return items
}

export const NXT_SCYLLA_MOTOR_VOLTAGE_ITEMS: Array<{ value: number; title: string }> = [
  { value: 24, title: '24 V motor supply' },
  { value: 48, title: '48 V motor supply' }
]

/** Config folder under 0:/sys/nxt/config/ */
export function nxtKitConfigBase(platform: NxtPlatformId | null | undefined): string | null {
  if (platform == null || platform === '') {
    return null
  }
  if (nxtPlatformFromManifest(platform)) {
    return `nxt/config/${platform}`
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
  const plat = nxtPlatformFromManifest(platform)
  if (!plat || boardShortName == null || boardShortName === '') {
    return null
  }
  const sn = String(boardShortName).trim()
  if (motorVoltage === 48) {
    const b = plat.boards.find((x) => x.shortName === sn && x.variant === '48v')
    return b?.entryPath ?? null
  }
  if (motorVoltage === 24) {
    const b = plat.boards.find((x) => x.shortName === sn && x.variant === '24v')
    return b?.entryPath ?? null
  }
  const b = plat.boards.find((x) => x.shortName === sn && x.variant == null)
  return b?.entryPath ?? null
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
): { nxtBoardKitKey: NxtBoardKitKey; nxtBoardMotorVoltage: number | null } {
  if (kit === 'scylla_48') {
    return { nxtBoardKitKey: kit, nxtBoardMotorVoltage: 48 }
  }
  if (kit === 'scylla_24') {
    return { nxtBoardKitKey: kit, nxtBoardMotorVoltage: 24 }
  }
  return { nxtBoardKitKey: kit, nxtBoardMotorVoltage: null }
}

export function platformStructureSummary(platformId: NxtPlatformId | null | undefined): {
  sysDeployFiles: string[]
  boardEntryPaths: string[]
} {
  const p = nxtPlatformFromManifest(platformId)
  if (!p) {
    return { sysDeployFiles: [], boardEntryPaths: [] }
  }
  return {
    sysDeployFiles: [...p.sysDeployFiles],
    boardEntryPaths: p.boards.map((b) => b.entryPath)
  }
}
