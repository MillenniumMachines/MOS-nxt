/**
 * Shared persist path for Configuration Save, Calibration Save, and Custom Apply.
 * Keeps nxt-user-vars.g, bootstrap/custom sentinels, and Custom pack deploy consistent.
 */
import type { NxtUserConfigDraft } from './nxtUserVarsPersistence'
import { buildNxtUserVarsGcode } from './nxtUserVarsPersistence'
import { buildCustomPackFiles } from './nxtCustomPackGenerate'
import { deployPlatformSysFiles } from './nxtBoardSysDeploy'
import { syncBoardBootstrapSentinels } from './nxtBoardBootstrapSync'
import {
  NXT_CUSTOM_REQUESTED_PATH,
  NXT_USER_VARS_DWC_PATH,
  deleteDwcFile,
  dwcFileExists,
  uploadDwcFile
} from './nxtFileUpload'
import store from '../compat/dwcStore'

let _customGlobalsEnsured = false
let _customGlobalsConnGen = -1

function connectionGeneration(): number {
  try {
    return store.getters?.isConnected ? 1 : 0
  } catch {
    return 0
  }
}

/** Reset in-session Custom globals cache (tests / soft reload). */
export function resetCustomGlobalsEnsureCache(): void {
  _customGlobalsEnsured = false
  _customGlobalsConnGen = -1
}

export function splitCustomPackFiles(packFiles: Record<string, string>): {
  generatedHomes: Record<string, string>
  overlays: Record<string, string>
} {
  const homeNames = new Set(['homex.g', 'homey.g', 'homez.g', 'homeall.g', 'homea.g'])
  const generatedHomes: Record<string, string> = {}
  const overlays: Record<string, string> = {}
  for (const [name, body] of Object.entries(packFiles)) {
    if (homeNames.has(name)) {
      generatedHomes[name] = body
    } else {
      overlays[name] = body
    }
  }
  return { generatedHomes, overlays }
}

/**
 * Ensure Custom-platform globals exist (same path as nxt.g: nxt-custom-globals.g).
 * Cached until disconnect/reload so keystroke edits do not re-M98 every time.
 */
export async function ensureCustomGlobals(
  sendCode: (code: string) => Promise<unknown>
): Promise<void> {
  const gen = connectionGeneration()
  if (gen === 0) {
    _customGlobalsEnsured = false
    _customGlobalsConnGen = 0
    return
  }
  if (_customGlobalsEnsured && _customGlobalsConnGen === gen) {
    return
  }
  try {
    await sendCode('M98 P"nxt-custom-globals.g"')
    _customGlobalsEnsured = true
    _customGlobalsConnGen = gen
  } catch (e) {
    console.warn('nxt: ensureCustomGlobals', e)
  }
}

/** Idempotent Custom sentinel: upload only when needed; delete only when present. */
export async function syncCustomRequestedSentinel(wantCustom: boolean): Promise<void> {
  const exists = await dwcFileExists(NXT_CUSTOM_REQUESTED_PATH)
  if (wantCustom) {
    if (!exists) {
      await uploadDwcFile(
        NXT_CUSTOM_REQUESTED_PATH,
        '; Platform=Custom — declare nxtCustom* before user-vars\n'
      )
    }
    return
  }
  if (exists) {
    try {
      await deleteDwcFile(NXT_CUSTOM_REQUESTED_PATH)
    } catch {
      /* absent is fine */
    }
  }
}

export type PersistNxtUserConfigOpts = {
  /** Upload nxt-user-vars.g (default true). */
  uploadUserVars?: boolean
  /** Sync bootstrap .requested / .skip from draft.nxtBoardBootstrapMode (default true when connected). */
  syncBootstrap?: boolean
  /** Sync nxt-custom.requested from platform (default true when connected). */
  syncCustomRequested?: boolean
  /** M98 nxt-custom-globals.g once when Custom (default true when connected + custom). */
  ensureCustomGlobals?: boolean
  /** Deploy Custom pack homes + overlays (default true when custom). */
  deployCustomPack?: boolean
  /** Set nxtBoardSysDeployPlatform after custom deploy (default true). */
  setBoardSysDeployPlatform?: boolean
  /** Live OM updates — required for ensureCustomGlobals / setBoardSysDeployPlatform. */
  sendCode?: (code: string) => Promise<unknown>
  /** Treat as connected (default: store getter). */
  isConnected?: boolean
}

export type PersistNxtUserConfigResult = {
  userVarsPath: string
  bootMode: 'auto' | 'off'
  customDeployed: string[]
}

function isCustomDraft(draft: NxtUserConfigDraft): boolean {
  return draft.nxtPlatformProfile === 'custom'
}

/**
 * Persist operator config draft to SD (+ optional Custom pack / sentinels).
 */
export async function persistNxtUserConfig(
  draft: NxtUserConfigDraft,
  opts: PersistNxtUserConfigOpts = {}
): Promise<PersistNxtUserConfigResult> {
  const connected =
    opts.isConnected ??
    (() => {
      try {
        return !!store.getters?.isConnected
      } catch {
        return false
      }
    })()

  const uploadUserVars = opts.uploadUserVars !== false
  const syncBootstrap = opts.syncBootstrap !== false && connected
  const syncCustom = opts.syncCustomRequested !== false && connected
  const doEnsure = opts.ensureCustomGlobals !== false && connected
  const deployCustom = opts.deployCustomPack !== false && isCustomDraft(draft)
  const setDeployPlat = opts.setBoardSysDeployPlatform !== false

  const bootMode = draft.nxtBoardBootstrapMode === 'auto' ? 'auto' : 'off'
  const custom = isCustomDraft(draft)

  if (uploadUserVars) {
    const content = buildNxtUserVarsGcode(draft)
    await uploadDwcFile(NXT_USER_VARS_DWC_PATH, content)
  }

  if (syncBootstrap) {
    await syncBoardBootstrapSentinels(bootMode)
  }

  if (syncCustom) {
    await syncCustomRequestedSentinel(custom)
  }

  if (doEnsure && custom && opts.sendCode) {
    await ensureCustomGlobals(opts.sendCode)
  }

  let customDeployed: string[] = []
  if (deployCustom) {
    const packFiles = buildCustomPackFiles(draft)
    const { generatedHomes, overlays } = splitCustomPackFiles(packFiles)
    customDeployed = await deployPlatformSysFiles('custom', {
      generatedContents: generatedHomes,
      packOverlayContents: overlays
    })
    if (setDeployPlat && opts.sendCode && connected) {
      draft.nxtBoardSysDeployPlatform = 'custom'
      await opts.sendCode('set global.nxtBoardSysDeployPlatform = "custom"')
    }
  }

  return {
    userVarsPath: NXT_USER_VARS_DWC_PATH,
    bootMode,
    customDeployed
  }
}
