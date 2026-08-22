/**
 * Unit tests for nxtOperatorFaces (run via ui/scripts/run-user-vars-persistence-behavioral.mjs).
 */
import {
  computeV2RefPadXY,
  computeV2RefPadZ,
  formatRefDirLabel,
  operatorSideToRefDir,
  refDirAxisSuffix,
  refDirToOperatorSide,
  runNxtOperatorFacesSelfTest,
  type NxtOperatorSide
} from './nxtOperatorFaces'

export function runAllNxtOperatorFacesTests(): void {
  runNxtOperatorFacesSelfTest()

  const cases: Array<{ refDir: number; side: NxtOperatorSide; axis: string }> = [
    { refDir: 0, side: 'left', axis: '(+X)' },
    { refDir: 1, side: 'right', axis: '(−X)' },
    { refDir: 2, side: 'back', axis: '(+Y)' },
    { refDir: 3, side: 'front', axis: '(−Y)' }
  ]

  for (const c of cases) {
    if (refDirToOperatorSide(c.refDir) !== c.side) {
      throw new Error(`refDir ${c.refDir} should map to ${c.side}`)
    }
    if (operatorSideToRefDir(c.side) !== c.refDir) {
      throw new Error(`${c.side} should map to refDir ${c.refDir}`)
    }
    if (refDirAxisSuffix(c.refDir) !== c.axis) {
      throw new Error(`refDir ${c.refDir} axis suffix expected ${c.axis}`)
    }
  }

  const labels = {
    left: 'Left',
    right: 'Right',
    front: 'Front',
    back: 'Back'
  }
  if (formatRefDirLabel(3, labels) !== 'Front (−Y)') {
    throw new Error('formatRefDirLabel with i18n labels failed')
  }

  const pad = computeV2RefPadXY(50, 60, 2)
  if (pad.x !== 50 || pad.y !== 73) {
    throw new Error('computeV2RefPadXY back side failed')
  }
  if (computeV2RefPadZ(20) !== 14) {
    throw new Error('computeV2RefPadZ offset failed')
  }
}
