/**
 * Build-time manifest from macros/nxt-config/ (see dist/generate-nxt-config-manifest.mjs).
 */
import raw from '../generated/nxtConfigManifest.json'

export type NxtConfigBoardEntry = {
  relPath: string
  shortName: string
  variant: string | null
  title: string
  entryPath: string
}

export type NxtConfigPlatformEntry = {
  id: string
  title: string
  hasCommonDeploy: boolean
  sysDeployFiles: string[]
  sysDeployContents: Record<string, string>
  boards: NxtConfigBoardEntry[]
}

export type NxtConfigManifest = {
  generatedAt: string
  platforms: NxtConfigPlatformEntry[]
}

export const nxtConfigManifest = raw as NxtConfigManifest

export function nxtPlatformFromManifest(platformId: string | null | undefined): NxtConfigPlatformEntry | null {
  if (platformId == null || platformId === '') {
    return null
  }
  return nxtConfigManifest.platforms.find((p) => p.id === platformId) ?? null
}
