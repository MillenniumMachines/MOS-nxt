/**
 * Run: node --import tsx ui/scripts/run-fusion-import-policy-tests.mjs
 * Or: node --experimental-strip-types ui/scripts/run-fusion-import-policy-tests.mjs
 */
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'
import test from 'node:test'
import assert from 'node:assert/strict'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const policySrc = readFileSync(join(root, 'src/utils/fusionToolsImport/fusionImportPolicy.ts'), 'utf8')

test('fusionImportPolicy source exports maxUserToolIndex', () => {
  assert.ok(policySrc.includes('export function maxUserToolIndex'))
  assert.ok(policySrc.includes('reservedFrom - 1'))
})

test('fusionImportPolicy source skips probe pocket', () => {
  assert.ok(policySrc.includes('probeIndex'))
  assert.ok(policySrc.includes('25.4'))
})

// Inline policy checks (no TS compile step required in CI)
test('max user index math', () => {
  const maxUserToolIndex = (limitsTools, reservedFrom) => {
    if (typeof reservedFrom === 'number' && Number.isFinite(reservedFrom) && reservedFrom > 0) {
      return reservedFrom - 1
    }
    if (typeof limitsTools === 'number' && Number.isFinite(limitsTools) && limitsTools > 1) {
      return limitsTools - 2
    }
    return 48
  }
  assert.equal(maxUserToolIndex(50, 49), 48)
  assert.equal(maxUserToolIndex(50, null), 48)
})
