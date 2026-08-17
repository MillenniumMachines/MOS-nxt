/**
 * Run: node --test ui/scripts/run-toolpath-split-tests.mjs
 * Requires: npx tsx (downloads on first use if needed)
 */
import { spawnSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'
import test from 'node:test'

const scriptDir = dirname(fileURLToPath(import.meta.url))
const tsScript = join(scriptDir, 'toolpath-split-tests.ts')

function runToolpathTests(extraArgs = []) {
  const result = spawnSync('npx', ['--yes', 'tsx', tsScript, ...extraArgs], {
    cwd: join(scriptDir, '..'),
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe']
  })
  return result
}

test('toolpath golden snapshots match committed baseline', () => {
  const result = runToolpathTests()
  if (result.status !== 0) {
    throw new Error(
      (result.stdout || '') + (result.stderr || '') || `tsx exited ${result.status}`
    )
  }
})
