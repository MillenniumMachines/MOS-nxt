/**
 * Compare bundled nxt-config manifest with on-SD tree under 0:/sys/nxt-config/.
 */
import { boardEntriesList, machinesList, nxtMachineFromManifest } from './nxtConfigManifestData'
import { nxtBoardPackRelPath } from './nxtBoardManifest'
import { dwcFileExists, listDwcDirectory } from './nxtFileUpload'

export type NxtConfigSdScanResult = {
  installedMachineIds: string[]
  missingMachines: string[]
  missingEntryPaths: string[]
  extraMachineIds: string[]
  scanError: string | null
}

const NXT_CONFIG_SD_ROOT = '0:/sys/nxt-config'

export function expectedSdPathsForMachine(
  machineId: string | null | undefined,
  boardShortName: string | null | undefined,
  motorVoltage: number | null | undefined
): string[] {
  const paths: string[] = []
  const machine = nxtMachineFromManifest(machineId)
  if (!machine) {
    return paths
  }
  paths.push(`${NXT_CONFIG_SD_ROOT}/machine/${machine.id}/OVERVIEW.txt`)
  if (machine.machineEntryPath) {
    paths.push(`0:/sys/${machine.machineEntryPath}`)
  }
  const entry = nxtBoardPackRelPath(machineId, boardShortName, motorVoltage)
  if (entry) {
    paths.push(`0:/sys/${entry}`)
  }
  for (const b of boardEntriesList()) {
    paths.push(`0:/sys/${b.entryPath}`)
  }
  return [...new Set(paths)]
}

export async function scanNxtConfigOnSd(
  selectedMachineId: string | null | undefined,
  boardShortName: string | null | undefined,
  motorVoltage: number | null | undefined
): Promise<NxtConfigSdScanResult> {
  const bundledMachineIds = machinesList().map((m) => m.id)
  const machineRoot = `${NXT_CONFIG_SD_ROOT}/machine`
  const boardRoot = `${NXT_CONFIG_SD_ROOT}/board`
  const machineNames = await listDwcDirectory(machineRoot, { directoriesOnly: true })
  const boardNames = await listDwcDirectory(boardRoot, { directoriesOnly: true })
  if (machineNames == null && boardNames == null) {
    return {
      installedMachineIds: [],
      missingMachines: bundledMachineIds,
      missingEntryPaths: [],
      extraMachineIds: [],
      scanError: `Could not read ${machineRoot} or ${boardRoot} (reinstall nxt plugin)`
    }
  }
  const installedMachineIds = machineNames ?? []
  const missingMachines = bundledMachineIds.filter((id) => !installedMachineIds.includes(id))
  const extraMachineIds = installedMachineIds.filter((id) => !bundledMachineIds.includes(id))

  const missingEntryPaths: string[] = []
  if (selectedMachineId) {
    const overview = `${machineRoot}/${selectedMachineId}/OVERVIEW.txt`
    if (!installedMachineIds.includes(selectedMachineId)) {
      missingEntryPaths.push(overview)
    } else if (!(await dwcFileExists(overview))) {
      missingEntryPaths.push(overview)
    }
    const entry = nxtBoardPackRelPath(selectedMachineId, boardShortName, motorVoltage)
    if (entry) {
      const full = `0:/sys/${entry}`
      if (!(await dwcFileExists(full))) {
        missingEntryPaths.push(full)
      }
    }
  }

  return {
    installedMachineIds,
    missingMachines,
    missingEntryPaths,
    extraMachineIds,
    scanError: null
  }
}

export function formatSdScanWarnings(result: NxtConfigSdScanResult): string[] {
  const messages: string[] = []
  if (result.scanError) {
    return [result.scanError]
  }
  if (result.missingMachines.length > 0) {
    messages.push(
      `Missing on SD (reinstall nxt plugin): ${result.missingMachines.map((id) => `${NXT_CONFIG_SD_ROOT}/machine/${id}`).join(', ')}`
    )
  }
  if (result.missingEntryPaths.length > 0) {
    messages.push(`Missing pack files: ${result.missingEntryPaths.join('; ')}`)
  }
  if (result.extraMachineIds.length > 0) {
    messages.push(`SD has extra machine folders (not in this plugin build): ${result.extraMachineIds.join(', ')}`)
  }
  return messages
}
