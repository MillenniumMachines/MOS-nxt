/**
 * Standalone (no SBC) DWC 3.7 hangs after the first M291 when MessageBoxDialog
 * awaits M292 replies. PollConnector waits on reply-seq, but RRF does not return
 * per-request replies yet (RRF #925). DWC 3.6 fixed this with noWait for M292;
 * that was not ported to 3.7+.
 *
 * Wrap Pinia machineStore.sendCode so every M292 is fire-and-forget (noWait +
 * quiet log). Stock MessageBoxDialog stays the sole ack UI — do not remount a
 * second Action Confirmation widget.
 */

import { useMachineStore } from '@/stores/machine'

const PATCH_FLAG = '__nxtM292NoWaitPatched'

function isM292(code: unknown): boolean {
  return typeof code === 'string' && /^\s*M292\b/i.test(code)
}

/**
 * Idempotent: safe if the plugin chunk evaluates more than once.
 * Call once at plugin load (after Pinia is available via window.DWC).
 */
export function installNxtM292NoWaitPatch(): boolean {
  try {
    const store = useMachineStore() as ReturnType<typeof useMachineStore> & {
      [PATCH_FLAG]?: boolean
    }

    if (store[PATCH_FLAG]) {
      return true
    }

    const original = store.sendCode.bind(store)

    // Replace action: M292 must not await reply-seq on PollConnector (standalone).
    // Cast avoids fighting Pinia's generic noWait return type.
    ;(store as { sendCode: typeof store.sendCode }).sendCode = ((
      code: string,
      fromInput: boolean = false,
      logReply: boolean = true,
      noWait?: boolean
    ) => {
      if (isM292(code)) {
        // Match DWC 3.6 MessageBoxDialog: noWait + do not log deferred replies
        return original(code, fromInput, false, true)
      }
      return original(code, fromInput, logReply, noWait)
    }) as typeof store.sendCode

    store[PATCH_FLAG] = true
    return true
  } catch (err) {
    console.warn('[nxt] M292 noWait patch failed (standalone multi-prompt may hang):', err)
    return false
  }
}
