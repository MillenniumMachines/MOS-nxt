/**
 * Run: node --test ui/scripts/run-user-vars-persistence-tests.mjs
 */
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'
import test from 'node:test'
import assert from 'node:assert/strict'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const src = readFileSync(join(root, 'src/utils/nxtUserVarsPersistence.ts'), 'utf8')

test('nxt-user-vars.g does not persist probe repeatability', () => {
  assert.ok(!src.includes('nxtProbeInnerSampleCount = ${'))
  assert.ok(src.includes('nxt-user-overrides.g'))
})

test('buildInitialConfigDraft orchestrates MOS + singleton defaults', () => {
  assert.ok(src.includes('mapMosGlobalsToConfig'))
  assert.ok(src.includes('applySingletonDefaults'))
})

test('selfTest rejects repeatability in user-vars gcode', () => {
  const fnBody = src.slice(src.indexOf('export function runNxtUserVarsPersistenceSelfTest'))
  assert.ok(fnBody.includes('nxtProbeInnerSampleCount'))
  assert.ok(fnBody.includes('nxt-user-overrides.g'))
})
