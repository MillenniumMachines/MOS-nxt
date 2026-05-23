/**
 * Board pack metadata for NeXT Configuration UI and nxt-board-pack-loader.g.
 * Boards: nxt-config/board/<shortName>/ — machines: nxt-config/machine/<profile>/.
 */
import {
  boardEntriesList,
  machinesList,
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
  cdy3_f4: 'Fly CDYv3',
  scylla1_0_h723: 'Scylla v1.0'
}

function machineDisplayTitle(id: string, overviewTitle: string): string {
  if (id === 'v1.5') {
    return 'Milo v1.5'
  }
  if (id === 'v1.6_v2') {
    return 'Milo v1.6 / v2.0'
  }
  return overviewTitle.replace(/\s*\(NeXT\)\s*$/i, '').trim() || id
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

/** Machine config folder under 0:/sys/nxt-config/ */
export function nxtMachineConfigBase(machineId: NxtPlatformId | null | undefined): string | null {
  if (machineId == null || machineId === '') {
    return null
  }
  if (nxtMachineFromManifest(machineId)) {
    return `nxt-config/machine/${machineId}`
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
  fly_cdyv3: nxtKitEntryPath('v1.5', 'fly_cdyv3'),
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

export function platformStructureSummary(machineId: NxtPlatformId | null | undefined): {
  sysDeployFiles: string[]
  boardEntryPaths: string[]
  machineEntryPath: string | null
} {
  const m = nxtMachineFromManifest(machineId)
  if (!m) {
    return { sysDeployFiles: [], boardEntryPaths: [], machineEntryPath: null }
  }
  return {
    sysDeployFiles: [...m.sysDeployFiles],
    boardEntryPaths: boardEntriesList().map((b) => b.entryPath),
    machineEntryPath: m.machineEntryPath
  }
}
