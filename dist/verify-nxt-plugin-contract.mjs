#!/usr/bin/env node
/**
 * Verify nxt DWC plugin wiring is internally consistent (id, paths, build scripts).
 */
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..')
const PLUGIN_ID = 'nxt'
const errors = []

function fail(msg) {
  errors.push(msg)
}

function readJson(rel) {
  return JSON.parse(fs.readFileSync(path.join(root, rel), 'utf8'))
}

function readText(rel) {
  return fs.readFileSync(path.join(root, rel), 'utf8')
}

function assertIncludes(rel, needle, label) {
  const text = readText(rel)
  if (!text.includes(needle)) {
    fail(`${label}: ${rel} missing ${JSON.stringify(needle)}`)
  }
}

function assertNotIncludes(rel, needle, label) {
  const text = readText(rel)
  if (text.includes(needle)) {
    fail(`${label}: ${rel} still contains ${JSON.stringify(needle)}`)
  }
}

// plugin.json
const manifest = readJson('ui/plugin.json')
if (manifest.id !== PLUGIN_ID) fail(`ui/plugin.json id must be ${PLUGIN_ID}`)
if (manifest.dwcWebpackChunk !== PLUGIN_ID) {
  fail(`ui/plugin.json dwcWebpackChunk must be ${PLUGIN_ID}`)
}

// catalog
const catalog = readJson('dist/plugins.catalog.json')
const core = catalog.plugins?.find((p) => p.repoPath === '.')
if (!core || core.id !== PLUGIN_ID) {
  fail('dist/plugins.catalog.json must list id "nxt" for repoPath "."')
}

// UI entry
if (!fs.existsSync(path.join(root, 'ui/src/nxt.vue'))) {
  fail('ui/src/nxt.vue must exist')
}
if (fs.existsSync(path.join(root, 'ui/src/NeXT.vue'))) {
  fail('ui/src/NeXT.vue must not exist')
}

assertIncludes('ui/src/index.ts', "registerPluginLocalization('nxt'", 'index.ts i18n')
assertIncludes('ui/src/index.ts', "registerPluginData('nxt'", 'index.ts plugin data')
assertIncludes('ui/src/index.ts', "caption: 'plugins.nxt.name'", 'index.ts route caption')
assertIncludes('ui/src/index.ts', "const NXT_ROUTE_PATH = '/nxt'", 'index.ts route')
assertIncludes('ui/src/index.ts', "import nxt from './nxt.vue'", 'index.ts import')
assertNotIncludes('ui/src/index.ts', '/NeXT', 'index.ts routes')
assertNotIncludes('ui/src/index.ts', 'plugins.next', 'index.ts i18n keys')

assertIncludes('ui/src/components/panels/RgbLightControl.vue', "const PLUGIN = 'nxt'", 'RgbLightControl')

// Build / release scripts
for (const rel of [
  'dist/build-plugin.sh',
  'dist/release.sh',
  'dist/inject-plugin-dwcfiles.cjs',
  'dist/trace-plugin-404.mjs',
  'dist/fix-plugin-dwc-zip-layout.cjs',
  'dist/setup-dwc-dev-symlink.sh',
]) {
  assertIncludes(rel, PLUGIN_ID, rel)
}

assertIncludes('dist/release.sh', '--arg id "nxt"', 'release dwc-plugins.json id')
assertIncludes('dist/build-plugin.sh', 'dwc/js/nxt', 'build-plugin zip layout')
assertIncludes('dist/verify-plugin-zip.mjs', 'dwc/js/nxt', 'verify-plugin-zip')

// No stale id in UI tree
const uiSrc = path.join(root, 'ui/src')
function walkUi(dir) {
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, ent.name)
    if (ent.isDirectory()) walkUi(p)
    else if (/\.(ts|vue)$/.test(ent.name)) {
      const t = fs.readFileSync(p, 'utf8')
      if (t.includes('NeXT') || t.includes('/NeXT')) {
        fail(`stale NeXT reference in ${path.relative(root, p)}`)
      }
      if (t.includes('plugins.next')) {
        fail(`stale plugins.next i18n key in ${path.relative(root, p)}`)
      }
    }
  }
}
walkUi(uiSrc)

if (errors.length) {
  console.error('verify-nxt-plugin-contract: FAILED\n')
  for (const e of errors) console.error(`  - ${e}`)
  process.exit(1)
}

console.log('verify-nxt-plugin-contract: OK')
