/**
 * Deploy machine homing files to 0:/sys/ (from build-time manifest; deploy-only, not boot M98).
 * For custom platform, pass generatedContents to upload generated macros instead of SD templates.
 * Board packs may also ship board.txt → 0:/sys/board.txt via deployBoardTxt().
 */
import {
  nxtBoardPackFromManifest,
  nxtMachineFromManifest,
  nxtPlatformFromManifest
} from './nxtConfigManifestData'
import { downloadDwcTextFile, uploadDwcFile } from './nxtFileUpload'
import { CUSTOM_PACK_SD_DIR } from './nxtCustomPackGenerate'

function machineSysDeploySourcePath(platformId: string, fileName: string): string {
  return `0:/sys/nxt-config/machine/${platformId}/${fileName}`
}

export function sysDeployFilesForPlatform(platformId: string): string[] {
  const m = nxtMachineFromManifest(platformId) ?? nxtPlatformFromManifest(platformId)
  return m?.sysDeployFiles ?? []
}

export const NXT_SYS_BOARD_TXT_DEST = '0:/sys/board.txt'

/**
 * Copy vendored board pack board.txt to 0:/sys/board.txt (RRF firmware pin table).
 * @returns dest path when written, or null when the pack has no board.txt
 */
export async function deployBoardTxt(boardShortName: string | null | undefined): Promise<string | null> {
  if (boardShortName == null || String(boardShortName).trim() === '') {
    return null
  }
  const sn = String(boardShortName).trim()
  const pack = nxtBoardPackFromManifest(sn)
  const rel = pack?.boardTxtPath
  if (rel == null || rel === '') {
    return null
  }
  const sdPath = `0:/sys/${rel}`
  let content: string
  try {
    content = await downloadDwcTextFile(sdPath)
  } catch {
    throw new Error(
      `Missing ${sdPath} on SD — reinstall the nxt plugin ZIP or copy macros/nxt-config/board/${sn}/board.txt`
    )
  }
  await uploadDwcFile(NXT_SYS_BOARD_TXT_DEST, content)
  return NXT_SYS_BOARD_TXT_DEST
}

export type DeployPlatformSysOptions = {
  /** When set (custom Save/Apply), upload these bodies instead of downloading pack templates. */
  generatedContents?: Record<string, string>
  /** Also write generated pack overlays under 0:/sys/nxt-user-custom/ on SD. */
  packOverlayContents?: Record<string, string>
}

/**
 * Upload homing macros listed in machine/<id>/sys-deploy-manifest.txt.
 * @returns paths written under 0:/sys/ (and optional pack overlay paths)
 */
export async function deployPlatformSysFiles(
  platformId: string,
  options?: DeployPlatformSysOptions
): Promise<string[]> {
  const machine = nxtMachineFromManifest(platformId) ?? nxtPlatformFromManifest(platformId)
  if (!machine?.hasCommonDeploy) {
    throw new Error(`Machine profile "${platformId}" has no sys deploy manifest`)
  }
  const written: string[] = []

  if (options?.packOverlayContents) {
    for (const [name, content] of Object.entries(options.packOverlayContents)) {
      const dest = `${CUSTOM_PACK_SD_DIR}/${name}`
      await uploadDwcFile(dest, content)
      written.push(dest)
    }
  }

  const deployedFromManifest = new Set<string>()
  for (const name of machine.sysDeployFiles) {
    let content: string
    if (options?.generatedContents?.[name] != null) {
      content = options.generatedContents[name]
    } else {
      const sdPath = machineSysDeploySourcePath(platformId, name)
      try {
        content = await downloadDwcTextFile(sdPath)
      } catch {
        throw new Error(
          `Missing homing file ${sdPath} on SD — reinstall the nxt plugin ZIP or copy macros/nxt-config/machine/${platformId}/${name}`
        )
      }
    }
    const dest = `0:/sys/${name}`
    await uploadDwcFile(dest, content)
    written.push(dest)
    deployedFromManifest.add(name)
  }

  // Extra generated homes (e.g. homea.g when A is configured) not listed in sys-deploy-manifest.
  if (options?.generatedContents) {
    for (const [name, content] of Object.entries(options.generatedContents)) {
      if (deployedFromManifest.has(name)) continue
      const dest = `0:/sys/${name}`
      await uploadDwcFile(dest, content)
      written.push(dest)
    }
  }
  return written
}
