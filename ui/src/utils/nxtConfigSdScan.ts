/**
 * Compare bundled nxt-config manifest with on-SD tree under 0:/sys/nxt/config/.
 */
import { nxtConfigManifest, nxtPlatformFromManifest } from './nxtConfigManifestData'
import { nxtBoardPackRelPath } from './nxtBoardManifest'
import { dwcFileExists, listDwcDirectory } from './nxtFileUpload'

export type NxtConfigSdScanResult = {
  installedPlatformIds: string[]
  missingPlatforms: string[]
  missingEntryPaths: string[]
  extraPlatformIds: string[]
  scanError: string | null
}

const NXT_CONFIG_SD_ROOT = '0:/sys/nxt/config'

export function expectedSdPathsForPlatform(
  platformId: string | null | undefined,
  boardShortName: string | null | undefined,
  motorVoltage: number | null | undefined
): string[] {
  const paths: string[] = []
  const plat = nxtPlatformFromManifest(platformId)
  if (!plat) {
    return paths
  }
  paths.push(`${NXT_CONFIG_SD_ROOT}/${plat.id}/OVERVIEW.txt`)
  const entry = nxtBoardPackRelPath(platformId, boardShortName, motorVoltage)
  if (entry) {
    paths.push(`0:/sys/${entry}`)
  }
  for (const b of plat.boards) {
    paths.push(`0:/sys/${b.entryPath}`)
  }
  return [...new Set(paths)]
}

export async function scanNxtConfigOnSd(
  selectedPlatformId: string | null | undefined,
  boardShortName: string | null | undefined,
  motorVoltage: number | null | undefined
): Promise<NxtConfigSdScanResult> {
  const bundledIds = nxtConfigManifest.platforms.map((p) => p.id)
  const names = await listDwcDirectory(NXT_CONFIG_SD_ROOT)
  if (names == null) {
    return {
      installedPlatformIds: [],
      missingPlatforms: bundledIds,
      missingEntryPaths: [],
      extraPlatformIds: [],
      scanError: 'Could not read SD directory (machine not connected or API unavailable)'
    }
  }
  const installedPlatformIds = names.filter((n) => !n.includes('.'))
  const missingPlatforms = bundledIds.filter((id) => !installedPlatformIds.includes(id))
  const extraPlatformIds = installedPlatformIds.filter((id) => !bundledIds.includes(id))

  const missingEntryPaths: string[] = []
  if (selectedPlatformId) {
    const overview = `${NXT_CONFIG_SD_ROOT}/${selectedPlatformId}/OVERVIEW.txt`
    if (!installedPlatformIds.includes(selectedPlatformId)) {
      missingEntryPaths.push(overview)
    } else if (!(await dwcFileExists(overview))) {
      missingEntryPaths.push(overview)
    }
    const entry = nxtBoardPackRelPath(selectedPlatformId, boardShortName, motorVoltage)
    if (entry) {
      const full = `0:/sys/${entry}`
      if (!(await dwcFileExists(full))) {
        missingEntryPaths.push(full)
      }
    }
  }

  return {
    installedPlatformIds,
    missingPlatforms,
    missingEntryPaths,
    extraPlatformIds,
    scanError: null
  }
}

export function formatSdScanWarnings(result: NxtConfigSdScanResult): string[] {
  const messages: string[] = []
  if (result.scanError) {
    return [result.scanError]
  }
  if (result.missingPlatforms.length > 0) {
    messages.push(
      `Missing on SD (reinstall NeXT plugin): nxt/config/${result.missingPlatforms.join(', ')}`
    )
  }
  if (result.missingEntryPaths.length > 0) {
    messages.push(`Missing pack files: ${result.missingEntryPaths.join('; ')}`)
  }
  if (result.extraPlatformIds.length > 0) {
    messages.push(`SD has extra platform folders (not in this plugin build): ${result.extraPlatformIds.join(', ')}`)
  }
  return messages
}
