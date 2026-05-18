/**
 * Deploy platform common/ homing files to 0:/sys/ (from build-time manifest).
 */
import { nxtPlatformFromManifest } from './nxtConfigManifestData'
import { uploadDwcFile } from './nxtFileUpload'

export function sysDeployFilesForPlatform(platformId: string): string[] {
  const p = nxtPlatformFromManifest(platformId)
  return p?.sysDeployFiles ?? []
}

/**
 * Upload homing macros listed in sys-deploy-manifest.txt for the platform.
 * @returns paths written under 0:/sys/
 */
export async function deployPlatformSysFiles(platformId: string): Promise<string[]> {
  const platform = nxtPlatformFromManifest(platformId)
  if (!platform?.hasCommonDeploy) {
    throw new Error(`Platform "${platformId}" has no sys deploy manifest`)
  }
  const written: string[] = []
  for (const name of platform.sysDeployFiles) {
    const content = platform.sysDeployContents[name]
    if (content == null) {
      throw new Error(`Missing content for ${platformId}/common/${name} in manifest`)
    }
    const dest = `0:/sys/${name}`
    await uploadDwcFile(dest, content)
    written.push(dest)
  }
  return written
}
