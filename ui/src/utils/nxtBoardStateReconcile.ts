/**
 * Compare saved board pack intent (globals + SD sentinels) vs runtime state.
 */
import { readFirmwareGlobal } from './nxtToolChangerOm'
import { readConfigString } from './nxtUserVarsPersistence'
import type { NxtUserConfigDraft } from './nxtUserVarsPersistence'
import { readBootstrapSentinelState } from './nxtBoardBootstrapSync'

export type BoardStateReconcileResult = {
  bootstrapWarnings: string[]
  packEntryWarnings: string[]
}

export async function reconcileBoardState(
  draft: NxtUserConfigDraft,
  globalVal: unknown
): Promise<BoardStateReconcileResult> {
  const bootstrapWarnings: string[] = []
  const packEntryWarnings: string[] = []

  const sentinels = await readBootstrapSentinelState()
  const mode = draft.nxtBoardBootstrapMode === 'auto' ? 'auto' : 'off'

  if (mode === 'auto' && !sentinels.requestedExists) {
    bootstrapWarnings.push(
      'Bootstrap mode is Auto but 0:/sys/nxt-board-bootstrap.requested is missing — Save Configuration to sync.'
    )
  }
  if (mode === 'off' && sentinels.requestedExists) {
    bootstrapWarnings.push(
      'Bootstrap mode is Off but nxt-board-bootstrap.requested still exists — pack may load at next boot until you Save.'
    )
  }
  if (sentinels.skipExists) {
    bootstrapWarnings.push(
      '0:/sys/nxt-board-bootstrap.skip is present — pack load is disabled regardless of Auto mode.'
    )
  }

  const expected =
    draft.nxtBoardPackExpectedEntry ??
    readConfigString(readFirmwareGlobal(globalVal, 'nxtBoardPackExpectedEntry'))
  const loaded = readConfigString(readFirmwareGlobal(globalVal, 'nxtBoardPackEntry'))

  if (expected && loaded && expected !== loaded) {
    packEntryWarnings.push(
      `Boot loaded "${loaded}" but saved expectation is "${expected}" — reboot after Save or check nxt-user-board.g.`
    )
  }

  return { bootstrapWarnings, packEntryWarnings }
}
