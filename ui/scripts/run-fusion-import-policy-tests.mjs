/**
 * Lightweight checks for fusionToolsImport policy (no full Vue build).
 */
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import test from 'node:test'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const policySrc = readFileSync(join(root, 'src/utils/fusionToolsImport/fusionImportPolicy.ts'), 'utf8')

test('fusionImportPolicy source exports maxUserToolIndex', () => {
  assert.ok(policySrc.includes('export function maxUserToolIndex'))
  assert.ok(policySrc.includes('limitsTools - 1'))
})

test('fusionImportPolicy source skips probe pocket only', () => {
  assert.ok(policySrc.includes('opts.probeIndex'))
  assert.ok(policySrc.includes('reserved for the touch probe'))
})

test('max user index is firmware last slot', () => {
  const maxUserToolIndex = (limitsTools, _reservedFrom) => {
    if (typeof limitsTools === 'number' && Number.isFinite(limitsTools) && limitsTools > 0) {
      return limitsTools - 1
    }
    return 49
  }
  assert.equal(maxUserToolIndex(50, 49), 49)
  assert.equal(maxUserToolIndex(50, null), 49)
})
