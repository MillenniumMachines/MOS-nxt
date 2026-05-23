/**
 * Deploy machine homing files to 0:/sys/ (from build-time manifest; deploy-only, not boot M98).
 */
import { nxtMachineFromManifest, nxtPlatformFromManifest } from './nxtConfigManifestData'
import { uploadDwcFile } from './nxtFileUpload'

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
    const content = machine.sysDeployContents[name]
    if (content == null) {
      throw new Error(`Missing content for machine/${platformId}/${name} in manifest`)
    }
    const dest = `0:/sys/${name}`
    await uploadDwcFile(dest, content)
    written.push(dest)
  }
  return written
}
