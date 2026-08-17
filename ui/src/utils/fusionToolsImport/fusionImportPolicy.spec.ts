/**
 * Unit tests for fusion import policy (run via ui/scripts/run-fusion-import-policy-tests.mjs).
 */
import {
  buildFusionImportPreview,
  maxUserToolIndex
} from './fusionImportPolicy'

export function runAllFusionImportPolicyTests(): void {
  if (maxUserToolIndex(50, 49) !== 48) {
    throw new Error('maxUserToolIndex(50, 49) should be 48')
  }
  if (maxUserToolIndex(50, null) !== 48) {
    throw new Error('maxUserToolIndex(50, null) should be 48')
  }

  const preview = buildFusionImportPreview(
    [
      {
        description: 'Endmill',
        unit: 'millimeters',
        geometry: { DC: 6, NOF: 3, LCF: 18 },
        'post-process': { number: 1 }
      },
      {
        description: 'Probe',
        geometry: { DC: 2 },
        'post-process': { number: 49 }
      },
      {
        description: 'Inch tool',
        unit: 'inches',
        geometry: { DC: 0.25 },
        'post-process': { number: 2 }
      }
    ],
    { maxIndex: 48, probeIndex: 49 }
  )

  if (preview.rows.length !== 2) {
    throw new Error(`expected 2 import rows, got ${preview.rows.length}`)
  }
  if (preview.rows[0].index !== 1 || preview.rows[0].radius !== 3) {
    throw new Error('row 1 radius mismatch')
  }
  if (preview.rows[1].index !== 2 || preview.rows[1].radius !== 3.175) {
    throw new Error('inch conversion failed')
  }
  if (!preview.warnings.some((w) => w.includes('reserved for the probe'))) {
    throw new Error('expected probe skip warning')
  }
  if (!preview.warnings.some((w) => w.includes('inches'))) {
    throw new Error('expected inch conversion warning')
  }
}
