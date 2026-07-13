/**
 * Build-time manifest from macros/nxt-config/ (see dist/generate-nxt-config-manifest.mjs).
 */
import raw from '../generated/nxtConfigManifest.json'

export type NxtConfigBoardEntry = {
  shortName: string
  variant: string | null
  title: string
  entryPath: string
}

export type NxtConfigPinmapEntry = {
  id?: string
  label?: string
  kind?: string
  pin?: string
  aliases?: string[]
  gpOutIndex?: number
  probeIndex?: number
  index?: number
  axis?: string
  note?: string
}

export type NxtConfigPinmap = {
  boardId?: string
  assigned?: NxtConfigPinmapEntry[]
  free?: NxtConfigPinmapEntry[]
  fanByVoltage?: Record<string, NxtConfigPinmapEntry>
}

export type NxtConfigBoardPack = {
  shortName: string
  title: string
  variant: 'single' | 'motor-24v-48v'
  entries: NxtConfigBoardEntry[]
  pinmap: NxtConfigPinmap | null
}

export type NxtConfigMachineEntry = {
  id: string
  title: string
  hasCommonDeploy: boolean
  sysDeployFiles: string[]
  /** @deprecated Not shipped in manifest — homing bodies are read from SD at deploy */
  sysDeployContents?: Record<string, string>
  machineEntryPath: string | null
}

/** @deprecated Alias — machine profile (was "platform") */
export type NxtConfigPlatformEntry = NxtConfigMachineEntry & {
  boards: NxtConfigBoardEntry[]
}

export type NxtConfigManifest = {
  generatedAt: string
  boards: NxtConfigBoardPack[]
  boardEntries: NxtConfigBoardEntry[]
  machines: NxtConfigMachineEntry[]
  /** Transitional: machines with boardEntries duplicated for older UI paths */
  platforms: NxtConfigPlatformEntry[]
}

export const nxtConfigManifest = raw as unknown as NxtConfigManifest

function machinesList(): NxtConfigMachineEntry[] {
  const m = nxtConfigManifest.machines
  if (m != null && m.length > 0) {
    return m
  }
  return (nxtConfigManifest.platforms ?? []) as NxtConfigMachineEntry[]
}

function boardEntriesList(): NxtConfigBoardEntry[] {
  const e = nxtConfigManifest.boardEntries
  if (e != null && e.length > 0) {
    return e
  }
  const fromPlatforms = nxtConfigManifest.platforms?.[0]?.boards
  return fromPlatforms ?? []
}

export { machinesList, boardEntriesList }

export function nxtMachineFromManifest(machineId: string | null | undefined): NxtConfigMachineEntry | null {
  if (machineId == null || machineId === '') {
    return null
  }
  return machinesList().find((m) => m.id === machineId) ?? null
}

/** @deprecated Use nxtMachineFromManifest */
export function nxtPlatformFromManifest(platformId: string | null | undefined): NxtConfigPlatformEntry | null {
  if (platformId == null || platformId === '') {
    return null
  }
  return nxtConfigManifest.platforms.find((p) => p.id === platformId) ?? null
}

export function nxtBoardPackFromManifest(shortName: string | null | undefined): NxtConfigBoardPack | null {
  if (shortName == null || shortName === '') {
    return null
  }
  return nxtConfigManifest.boards.find((b) => b.shortName === shortName) ?? null
}
