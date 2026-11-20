/**
 * WCS Z / tool-offset math. RRF: machineZ = userZ + wcsOffsetZ - toolOffsetZ, so
 * userZ = machineZ - wcsOffsetZ + toolOffsetZ (checked on RRF 3.7.0, see #76).
 * machineZ is the position G53 moves use (M5000 / nxtAbsPos).
 * Mirrors tpost.g L1, nxt-wcs-z-from-hit.g and nxt-workzero.g (legacy MOS used raw mosMI; see DETAILS.md).
 * tpost sets L1 against the probe: a longer tool gets a negative L1, a shorter one a positive L1.
 */

/** G10 L2 Z that makes user Z 0 at a touch at machineZ, with the active tool's L1. */
export function wcsOffsetFromHit(hitMachineZ: number, toolOffsetZ: number): number {
  return hitMachineZ + toolOffsetZ
}

/** Work user Z at a machine Z. */
export function userZAtMachine(
  machineZ: number,
  wcsOffsetZ: number,
  toolOffsetZ: number
): number {
  return machineZ - wcsOffsetZ + toolOffsetZ
}

/** nxt-workzero.g: machine Z for work Z0 (user = 0). */
export function workzeroMachineZ(wcsOffsetZ: number, toolOffsetZ: number): number {
  return wcsOffsetZ - toolOffsetZ
}

/** tpost.g: L1 = 0 − (Z_act_setter − virtualTsZ). A longer tool triggers higher → negative L1. */
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
  // One surface. The probe (L1 0) touches it at machine Z -120. A tool 40 mm longer
  // (L1 -40) touches it 40 mm higher, at -80; a tool 50 mm shorter (L1 +50) at -170.
  const surfaceProbe = -120
  const longer = { l1: -40, touch: -80 }
  const shorter = { l1: 50, touch: -170 }

  // Setting the WCS from a touch with any of them gives the same G10 L2 Z
  assertNear('probe L2', wcsOffsetFromHit(surfaceProbe, 0), -120)
  assertNear('longer tool L2', wcsOffsetFromHit(longer.touch, longer.l1), -120)
  assertNear('shorter tool L2', wcsOffsetFromHit(shorter.touch, shorter.l1), -120)

  // ...and every tool reads user Z 0 where it touches the surface
  assertNear('probe user at touch', userZAtMachine(surfaceProbe, -120, 0), 0)
  assertNear('longer user at touch', userZAtMachine(longer.touch, -120, longer.l1), 0)
  assertNear('shorter user at touch', userZAtMachine(shorter.touch, -120, shorter.l1), 0)

  // At the probe's touch height the longer tool's tip is 40 below the surface, the shorter one's 50 above
  assertNear('longer user at probe height', userZAtMachine(surfaceProbe, -120, longer.l1), -40)
  assertNear('shorter user at probe height', userZAtMachine(surfaceProbe, -120, shorter.l1), 50)

  // Work Z0 is where each tool touches the surface
  assertNear('workzero probe', workzeroMachineZ(-120, 0), -120)
  assertNear('workzero longer', workzeroMachineZ(-120, longer.l1), longer.touch)
  assertNear('workzero shorter', workzeroMachineZ(-120, shorter.l1), shorter.touch)

  // tpost: the longer tool triggers the setter higher than the probe datum
  const virtual = -50
  assertNear('tpost longer L1', toolOffsetFromSetterActivation(-45, virtual), -5)
  assertNear('tpost shorter L1', toolOffsetFromSetterActivation(-55, virtual), 5)

  // Bench, RRF 3.7.0 (2026-11-20, #76): T5 measured Z_act -81.342 against virtual -54.83 → L1 26.512.
  // With L1 26.506 and a WCS at Z -55.856, RRF showed user Z 10.0 at machine Z -72.363.
  assertNear('bench T5 L1', toolOffsetFromSetterActivation(-81.342, -54.83), 26.512, 1e-6)
  assertNear('bench T5 user Z', userZAtMachine(-72.363, -55.856, 26.506), 9.999, 1e-6)
}
