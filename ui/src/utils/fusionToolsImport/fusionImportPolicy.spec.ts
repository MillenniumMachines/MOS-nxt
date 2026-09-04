/**
 * Unit tests for fusion import policy (run via ui/scripts/run-fusion-import-policy-tests.mjs).
 */
import {
  buildFusionImportPreview,
  maxUserToolIndex
} from './fusionImportPolicy'

export function runAllFusionImportPolicyTests(): void {
  if (maxUserToolIndex(50, 49) !== 49) {
    throw new Error('maxUserToolIndex(50, 49) should be 49 (firmware last index)')
  }
  if (maxUserToolIndex(50, null) !== 49) {
    throw new Error('maxUserToolIndex(50, null) should be 49')
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
        description: 'Near end',
        unit: 'millimeters',
        geometry: { DC: 4, NOF: 2, LCF: 10 },
        'post-process': { number: 48 }
      },
      {
        description: 'Inch tool',
        unit: 'inches',
        geometry: { DC: 0.25 },
        'post-process': { number: 2 }
      },
      {
        description: 'High cutter',
        unit: 'millimeters',
        geometry: { DC: 10, NOF: 2, LCF: 20 },
        'post-process': { number: 18 }
      }
    ],
    { limitsTools: 50, probeIndex: 49 }
  )

  if (preview.rows.length !== 4) {
    throw new Error(`expected 4 import rows (skip only T49), got ${preview.rows.length}`)
  }
  if (preview.rows[0].index !== 1 || preview.rows[0].radius !== 3) {
    throw new Error('row 1 radius mismatch')
  }
  if (preview.rows[1].index !== 2 || preview.rows[1].radius !== 3.175) {
    throw new Error('inch conversion failed')
  }
  if (!preview.rows.some((r) => r.index === 18)) {
    throw new Error('T18 must import (not a reserved datum pocket)')
  }
  if (!preview.rows.some((r) => r.index === 48)) {
    throw new Error('T48 must import (limits.tools-2 is a user pocket)')
  }
  if (!preview.warnings.some((w) => w.includes('reserved for the touch probe'))) {
    throw new Error('expected probe skip warning')
  }
  if (!preview.warnings.some((w) => w.includes('inches'))) {
    throw new Error('expected inch conversion warning')
  }
}
