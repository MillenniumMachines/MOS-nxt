/**
 * Deploy machine homing files to 0:/sys/ (from build-time manifest; deploy-only, not boot M98).
 */
import { nxtMachineFromManifest, nxtPlatformFromManifest } from './nxtConfigManifestData'
import { downloadDwcTextFile, uploadDwcFile } from './nxtFileUpload'

function machineSysDeploySourcePath(platformId: string, fileName: string): string {
  return `0:/sys/nxt-config/machine/${platformId}/${fileName}`
}

export function sysDeployFilesForPlatform(platformId: string): string[] {
  const m = nxtMachineFromManifest(platformId) ?? nxtPlatformFromManifest(platformId)
  return m?.sysDeployFiles ?? []
}

/**
 * Upload homing macros listed in machine/<id>/sys-deploy-manifest.txt.
 * @returns paths written under 0:/sys/
 */
export async function deployPlatformSysFiles(platformId: string): Promise<string[]> {
  const machine = nxtMachineFromManifest(platformId) ?? nxtPlatformFromManifest(platformId)
  if (!machine?.hasCommonDeploy) {
    throw new Error(`Machine profile "${platformId}" has no sys deploy manifest`)
  }
  const written: string[] = []
  for (const name of machine.sysDeployFiles) {
    const sdPath = machineSysDeploySourcePath(platformId, name)
    let content: string
    try {
      content = await downloadDwcTextFile(sdPath)
    } catch {
      throw new Error(
        `Missing homing file ${sdPath} on SD — reinstall the NeXT plugin ZIP or copy macros/nxt-config/machine/${platformId}/${name}`
      )
    }
    const dest = `0:/sys/${name}`
    await uploadDwcFile(dest, content)
    written.push(dest)
  }
  return written
}
