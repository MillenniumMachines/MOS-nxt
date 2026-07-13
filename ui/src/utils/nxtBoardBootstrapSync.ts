/**
 * Sync nxt-board-bootstrap SD sentinel files with nxtBoardBootstrapMode from nxt-user-vars.g.
 * Uploads/deletes are idempotent (skip when SD already matches).
 */
import {
  NXT_BOARD_BOOTSTRAP_REQUESTED,
  NXT_BOARD_BOOTSTRAP_SKIP,
  deleteDwcFile,
  dwcFileExists,
  uploadDwcFile
} from './nxtFileUpload'

export async function syncBoardBootstrapSentinels(mode: 'auto' | 'off'): Promise<void> {
  if (mode === 'auto') {
    if (!(await dwcFileExists(NXT_BOARD_BOOTSTRAP_REQUESTED))) {
      await uploadDwcFile(NXT_BOARD_BOOTSTRAP_REQUESTED, '')
    }
    if (await dwcFileExists(NXT_BOARD_BOOTSTRAP_SKIP)) {
      try {
        await deleteDwcFile(NXT_BOARD_BOOTSTRAP_SKIP)
      } catch (e) {
        console.warn('nxt: could not remove nxt-board-bootstrap.skip', e)
      }
    }
    return
  }
  if (await dwcFileExists(NXT_BOARD_BOOTSTRAP_REQUESTED)) {
    try {
      await deleteDwcFile(NXT_BOARD_BOOTSTRAP_REQUESTED)
    } catch (e) {
      console.warn('nxt: could not remove nxt-board-bootstrap.requested', e)
    }
  }
}

export async function readBootstrapSentinelState(): Promise<{
  requestedExists: boolean
  skipExists: boolean
}> {
  const [requestedExists, skipExists] = await Promise.all([
    dwcFileExists(NXT_BOARD_BOOTSTRAP_REQUESTED),
    dwcFileExists(NXT_BOARD_BOOTSTRAP_SKIP)
  ])
  return { requestedExists, skipExists }
}
