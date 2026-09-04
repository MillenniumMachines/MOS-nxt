/**
 * Select the configured touch-probe tool (typically T49).
 *
 * SAFETY: raise to machine Z **maximum** (up) before T…. Never G0 to WCS Z0 —
 * that is workpiece height and rapids will not stop on probe trigger.
 * Every T{probe} runs tpost G6511 R1 S0 at nxtTouchProbeRefPos. Do not send G6511 here.
 */

import { NXT_PROBE_TOOL_ID } from './nxtProbeToolId'
import { readFirmwareGlobal } from './nxtToolChangerOm'

export function resolveNxtProbeToolId(firmwareGlobals: unknown): number {
  const v = readFirmwareGlobal(firmwareGlobals, 'nxtProbeToolID')
  if (typeof v === 'number' && Number.isFinite(v) && v >= 0) {
    return v
  }
  const legacy = readFirmwareGlobal(firmwareGlobals, 'mosPTID')
  if (typeof legacy === 'number' && Number.isFinite(legacy) && legacy >= 0) {
    return legacy
  }
  return NXT_PROBE_TOOL_ID
}

export function isNxtFeatureTouchProbe(firmwareGlobals: unknown): boolean {
  const v = readFirmwareGlobal(firmwareGlobals, 'nxtFeatureTouchProbe')
  return v === true || v === 1
}

/**
 * Probe is loaded if the current tool index or tool.number matches nxtProbeToolID.
 */
export function isNxtProbeToolLoaded(
  currentToolIndex: number | null | undefined,
  probeToolId: number | null,
  toolNumber?: number | null
): boolean {
  if (probeToolId == null) return false
  if (
    currentToolIndex != null &&
    Number.isFinite(currentToolIndex) &&
    currentToolIndex >= 0 &&
    currentToolIndex === probeToolId
  ) {
    return true
  }
  if (
    toolNumber != null &&
    Number.isFinite(toolNumber) &&
    toolNumber >= 0 &&
    toolNumber === probeToolId
  ) {
    return true
  }
  return false
}

/**
 * Raise to machine Z max (safe up), then T{probeToolId}.
 * tpost runs G6511 R1 S0 at nxtTouchProbeRefPos. Do not send G6511 here.
 * Does not use WCS Z0. Caller shows success/error toasts.
 */
export async function enableNxtProbeTool(
  sendCode: (code: string) => Promise<unknown>,
  probeToolId: number
): Promise<void> {
  await sendCode('G90')
  // Ensure M4000 probe row exists before T (idempotent when tip radius + feature match).
  await sendCode('M98 P"nxt-probe-tool-sync.g"')
  // RRF evaluates {move.axes[2].max} on the controller — always "up" / safe
  await sendCode('G53 G0 Z{move.axes[2].max}')
  await sendCode(`T${probeToolId}`)
}
