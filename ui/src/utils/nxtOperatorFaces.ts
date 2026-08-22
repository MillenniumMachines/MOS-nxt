/**
 * Operator-relative face names for nxt machines.
 *
 * Locked convention (G6510, probing UI): operator at front of mill;
 * −Y toward operator, +X to the operator's right.
 *
 * V2 toolsetter ref pad uses axis-encoded nxtToolSetterRefDir (0..3):
 *   0 = +X = Left, 1 = −X = Right, 2 = +Y = Back, 3 = −Y = Front
 *
 * This is not the G6510 face index (Y sides swap: G6510 Front=2, Back=3).
 */

import { normalizeNxtToolSetterRefDir } from './nxtUserVarsPersistence'

export type NxtOperatorSide = 'left' | 'right' | 'front' | 'back'

export const NXT_V2_REF_PAD_XY_OFFSET_MM = 13
export const NXT_V2_REF_PAD_Z_OFFSET_MM = -6

const REF_DIR_TO_SIDE: Record<number, NxtOperatorSide> = {
  0: 'left',
  1: 'right',
  2: 'back',
  3: 'front'
}

const SIDE_TO_REF_DIR: Record<NxtOperatorSide, number> = {
  left: 0,
  right: 1,
  back: 2,
  front: 3
}

const REF_DIR_AXIS_SUFFIX: Record<number, string> = {
  0: '(+X)',
  1: '(−X)',
  2: '(+Y)',
  3: '(−Y)'
}

/** Side labels for i18n-backed display (e.g. plugins.nxt.panels.operatorFaces.*). */
export type NxtOperatorFaceLabels = Record<NxtOperatorSide, string>

export function refDirToOperatorSide(refDir: number | null | undefined): NxtOperatorSide {
  const d = normalizeNxtToolSetterRefDir(refDir ?? 0)
  return REF_DIR_TO_SIDE[d] ?? 'left'
}

export function operatorSideToRefDir(side: NxtOperatorSide): number {
  return SIDE_TO_REF_DIR[side]
}

export function refDirAxisSuffix(refDir: number | null | undefined): string {
  const d = normalizeNxtToolSetterRefDir(refDir ?? 0)
  return REF_DIR_AXIS_SUFFIX[d] ?? '(+X)'
}

export function formatRefDirLabel(
  refDir: number | null | undefined,
  labels?: NxtOperatorFaceLabels
): string {
  const side = refDirToOperatorSide(refDir)
  const name = labels?.[side] ?? side.charAt(0).toUpperCase() + side.slice(1)
  return `${name} ${refDirAxisSuffix(refDir)}`
}

export function computeV2RefPadXY(
  tsX: number,
  tsY: number,
  refDir: number | null | undefined
): { x: number; y: number } {
  const d = normalizeNxtToolSetterRefDir(refDir ?? 0)
  const off = NXT_V2_REF_PAD_XY_OFFSET_MM
  if (d === 0) {
    return { x: tsX + off, y: tsY }
  }
  if (d === 1) {
    return { x: tsX - off, y: tsY }
  }
  if (d === 2) {
    return { x: tsX, y: tsY + off }
  }
  return { x: tsX, y: tsY - off }
}

export function computeV2RefPadZ(tsZ: number): number {
  return tsZ + NXT_V2_REF_PAD_Z_OFFSET_MM
}

export function runNxtOperatorFacesSelfTest(): void {
  const sides: NxtOperatorSide[] = ['left', 'right', 'front', 'back']
  for (const side of sides) {
    const refDir = operatorSideToRefDir(side)
    if (refDirToOperatorSide(refDir) !== side) {
      throw new Error(`refDir round-trip failed for ${side}`)
    }
  }

  const xy = computeV2RefPadXY(100, 200, 0)
  if (xy.x !== 113 || xy.y !== 200) {
    throw new Error('computeV2RefPadXY +X failed')
  }
  if (computeV2RefPadXY(100, 200, 1).x !== 87) {
    throw new Error('computeV2RefPadXY -X failed')
  }
  if (computeV2RefPadXY(100, 200, 2).y !== 213) {
    throw new Error('computeV2RefPadXY +Y failed')
  }
  if (computeV2RefPadXY(100, 200, 3).y !== 187) {
    throw new Error('computeV2RefPadXY -Y failed')
  }

  if (computeV2RefPadZ(10) !== 4) {
    throw new Error('computeV2RefPadZ failed')
  }

  if (formatRefDirLabel(2) !== 'Back (+Y)') {
    throw new Error('formatRefDirLabel default failed')
  }
}
