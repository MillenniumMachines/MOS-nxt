/**
 * WCS Z / tool-offset math (RRF: tipMachineZ = wcsOffsetZ + toolOffsetZ + userZ).
 * Mirrors tpost.g L1 and nxt-wcs-z-from-hit.g (legacy MOS used raw mosMI; see DETAILS.md).
 */

/** G10 L2 Z from tip hit and active tool L1 at probe time. */
export function wcsOffsetFromTipHit(tipMachineZ: number, toolOffsetZ: number): number {
  return tipMachineZ - toolOffsetZ
}

/** Work user Z at tip machine coordinate. */
export function userZAtTip(
  tipMachineZ: number,
  wcsOffsetZ: number,
  toolOffsetZ: number
): number {
  return tipMachineZ - wcsOffsetZ - toolOffsetZ
}

/** nxt-workzero.g: machine Z for work Z0 (user=0). */
export function workzeroMachineZ(wcsOffsetZ: number, toolOffsetZ: number): number {
  return wcsOffsetZ + toolOffsetZ
}

/** tpost.g / G37: L1 = 0 − (Z_act_setter − virtualTsZ). Shorter tool → negative L1. */
export function toolOffsetFromSetterActivation(
  zActSetter: number,
  virtualTsZ: number
): number {
  return 0 - (zActSetter - virtualTsZ)
}

function assertNear(label: string, actual: number, expected: number, eps = 1e-9): void {
  if (Math.abs(actual - expected) > eps) {
    throw new Error(`${label}: got ${actual}, expected ${expected}`)
  }
}

/** Self-test for dist/check-wcs-z-math.mjs */
export function runNxtWcsZMathSelfTest(): void {
  const tip = -120
  const l2Probe = wcsOffsetFromTipHit(tip, 0)
  assertNear('probe L2', l2Probe, -120)
  assertNear('probe user', userZAtTip(tip, l2Probe, 0), 0)

  const l2Shorter = wcsOffsetFromTipHit(tip, -50)
  assertNear('shorter mill L2', l2Shorter, -70)
  assertNear('shorter mill user at touch', userZAtTip(tip, l2Shorter, -50), 0)

  const l2EvenShorter = wcsOffsetFromTipHit(tip, -75)
  assertNear('even shorter L2', l2EvenShorter, -45)

  const l2Longer = wcsOffsetFromTipHit(tip, 40)
  assertNear('longer mill L2', l2Longer, -160)
  assertNear('longer mill user at touch', userZAtTip(tip, l2Longer, 40), 0)

  const l2ProbeSet = -120
  assertNear('cross shorter user', userZAtTip(tip, l2ProbeSet, -50), 50)
  assertNear('cross longer user', userZAtTip(tip, l2ProbeSet, 40), -40)

  assertNear('workzero shorter', workzeroMachineZ(-120, -50), -170)
  assertNear('workzero longer', workzeroMachineZ(-120, 40), -80)

  const virtual = -50
  assertNear('tpost shorter L1', toolOffsetFromSetterActivation(-45, virtual), -5)
  assertNear('tpost longer L1', toolOffsetFromSetterActivation(-55, virtual), 5)
}
