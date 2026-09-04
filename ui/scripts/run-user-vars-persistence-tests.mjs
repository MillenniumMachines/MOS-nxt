/**
 * Run: node --test ui/scripts/run-user-vars-persistence-tests.mjs
 *
 * Source-shape checks always run. Behavioral tests run when tsx is available
 * (npx tsx) so TypeScript can be imported without a separate build step.
 */
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'
import { spawnSync } from 'node:child_process'
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

test('probe role IDs are not factory sentinels; tip radius 0 remains', () => {
  const sentinelBlock = src.slice(
    src.indexOf('const NXT_VARS_FACTORY_SENTINELS'),
    src.indexOf('function clearNxtVarsFactoryDefaults')
  )
  assert.ok(!sentinelBlock.includes('nxtTouchProbeID'))
  assert.ok(!sentinelBlock.includes('nxtToolSetterID'))
  assert.ok(sentinelBlock.includes('nxtProbeTipRadius: 0'))
})

test('buildNxtUserVarsGcode omits null probe role IDs', () => {
  assert.ok(src.includes('Omit null probe role IDs'))
  assert.ok(src.includes('config.nxtTouchProbeID !== null'))
  assert.ok(src.includes('config.nxtToolSetterID !== null'))
})

test('behavioral persistence tests via tsx', () => {
  const runner = join(root, 'scripts/run-user-vars-persistence-behavioral.mjs')
  const r = spawnSync('npx', ['--yes', 'tsx', runner], {
    cwd: root,
    encoding: 'utf8',
    timeout: 120000
  })
  if (r.status !== 0) {
    assert.fail(
      `behavioral tests failed (status ${r.status}):\n${r.stdout || ''}\n${r.stderr || ''}`
    )
  }
})
