/**
 * Board kit metadata for NeXT Configuration UI and bootstrap hints.
 * Keep shortName lists aligned with macros/system/nxt-board-bootstrap.g (calibrate on hardware).
 */

export type NxtPlatformId = 'v1.5' | 'v1.6_v2' | 'atlas'

export type NxtBoardKitKey = 'fly_cdyv3' | 'scylla_24' | 'scylla_48'

export const NXT_PLATFORM_OPTIONS: Array<{ value: NxtPlatformId; title: string }> = [
  { value: 'v1.5', title: 'Milo v1.5' },
  { value: 'v1.6_v2', title: 'Milo v1.6 / v2.0 (baseline kit tree)' },
  { value: 'atlas', title: 'Atlas (kits not bundled yet)' }
]

/** LDO kits: same keys for v1.5 and v1.6_v2 SD trees; path prefix differs by platform. */
export const NXT_LDO_KIT_OPTIONS: Array<{ value: NxtBoardKitKey; title: string }> = [
  { value: 'fly_cdyv3', title: 'LDO Fly CDYv3' },
  { value: 'scylla_24', title: 'LDO Scylla (24 V motor supply)' },
  { value: 'scylla_48', title: 'LDO Scylla (48 V motor supply)' }
]

/** @deprecated Use nxtKitEntryPath(platform, kit) */
export const NXT_V15_KIT_OPTIONS = NXT_LDO_KIT_OPTIONS

const KIT_ENTRY_SUFFIX: Record<NxtBoardKitKey, string> = {
  fly_cdyv3: 'ldo-kit-fly-cdyv3/entry.g',
  scylla_24: 'ldo-kit-scylla-24v/entry.g',
  scylla_48: 'ldo-kit-scylla-48v/entry.g'
}

/** Config folder under 0:/sys/nxt/config/ */
export function nxtKitConfigBase(platform: NxtPlatformId | null | undefined): string {
  if (platform === 'v1.6_v2') {
    return 'nxt/config/v1.6_v2'
  }
  return 'nxt/config/v1.5'
}

/** Relative to 0:/sys/ */
export function nxtKitEntryPath(
  platform: NxtPlatformId | null | undefined,
  kit: NxtBoardKitKey
): string {
  return `${nxtKitConfigBase(platform)}/${KIT_ENTRY_SUFFIX[kit]}`
}

/** v1.5 paths only — for bootstrap macro parity or legacy callers */
export const NXT_KIT_ENTRY_PATH: Record<NxtBoardKitKey, string> = {
  fly_cdyv3: nxtKitEntryPath('v1.5', 'fly_cdyv3'),
  scylla_24: nxtKitEntryPath('v1.5', 'scylla_24'),
  scylla_48: nxtKitEntryPath('v1.5', 'scylla_48')
}

/** RRF boards[0].shortName → kit (must match nxt-board-bootstrap.g; values are firmware-defined). */
export function suggestKitKeyFromBoardShortName(shortName: string | null | undefined): NxtBoardKitKey | null {
  if (shortName == null || typeof shortName !== 'string') {
    return null
  }
  const s = shortName.trim()
  if (s === 'cdy3_f4') {
    return 'fly_cdyv3'
  }
  if (s === 'scylla1_0_h723') {
    return 'scylla_24'
  }
  return null
}

export type GpOutItem = { id: number; name: string }

/** gpOut indices for coolant mapping; labels are generic until OM exposes named outputs. */
export function gpOutItemsForKit(kitKey: NxtBoardKitKey | null | undefined, maxPorts: number): GpOutItem[] {
  const n = Math.max(0, Math.min(maxPorts, 32))
  const prefix =
    kitKey === 'fly_cdyv3' ? 'Fly CDYv3' : kitKey === 'scylla_24' || kitKey === 'scylla_48' ? 'Scylla' : 'GP out'
  return Array.from({ length: n }, (_, i) => ({
    id: i,
    name: `${prefix} — out ${i}`
  }))
}

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
