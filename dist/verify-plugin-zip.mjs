#!/usr/bin/env node
/**
 * Verify a nxt plugin ZIP has the dwc layout needed to avoid 404 / empty dwcFiles issues.
 *
 * Accepts both webpack-era names (nxt.<hash>.js) and DWC 3.7 Vite names (nxt-<hash>.js).
 *
 * Usage: node dist/verify-plugin-zip.mjs [path-to-nxt.zip]
 */
import fs from 'node:fs'
import { execSync } from 'node:child_process'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

/** Webpack: nxt.<hash>.js | Vite 3.7: nxt-<hash>.js (hash may include letters) */
const NXT_JS = /^dwc\/js\/nxt[.-][A-Za-z0-9_-]+\.js$/
const NXT_CSS = /^dwc\/css\/nxt[.-][A-Za-z0-9_-]+\.css$/
const NXT_NESTED = /^dwc\/nxt\/(js|css)\/nxt[.-][A-Za-z0-9_-]+\.(js|css)$/

function main() {
  const zipPath = process.argv[2] || path.join(__dirname, '..', 'dist', 'nxt-v0.7.0.zip')
  if (!fs.existsSync(zipPath)) {
    console.error(`error: zip not found: ${zipPath}`)
    process.exit(1)
  }

  const listing = execSync(`unzip -Z1 "${zipPath}"`, { encoding: 'utf8' })
    .split(/\r?\n/)
    .filter(Boolean)

  const dwcJs = listing.filter((n) => NXT_JS.test(n))
  const dwcCss = listing.filter((n) => NXT_CSS.test(n))
  const badNested = listing.filter((n) => NXT_NESTED.test(n))
  const dwcExtra = listing.filter(
    (n) =>
      /^dwc\//.test(n) &&
      !NXT_JS.test(n) &&
      !NXT_CSS.test(n) &&
      !n.endsWith('/') &&
      !/\.map$/.test(n)
  )

  let ok = true

  if (badNested.length > 0) {
    console.error('\nFAIL: dwc/nxt/js nested layout — DSF installs to www/nxt/nxt/js (404 at /nxt/js/)')
    console.error('  Run: node dist/fix-plugin-dwc-zip-layout.cjs', zipPath)
    ok = false
  }

  let pluginJson = null
  try {
    pluginJson = JSON.parse(execSync(`unzip -p "${zipPath}" plugin.json`, { encoding: 'utf8' }))
  } catch (e) {
    console.error('error: plugin.json missing or invalid', e)
    process.exit(1)
  }

  console.log('\n=== nxt plugin ZIP verification ===\n')
  console.log(`ZIP: ${zipPath}`)
  console.log(`plugin.json id: ${pluginJson.id}`)
  console.log(`plugin.json dwcVersion: ${pluginJson.dwcVersion}`)
  console.log(`plugin.json version: ${pluginJson.version}`)

  if (dwcJs.length !== 1) {
    console.error(
      `\nFAIL: expected exactly one dwc/js/nxt.<hash>.js or dwc/js/nxt-<hash>.js, got: ${dwcJs.join(', ') || '(none)'}`
    )
    ok = false
  } else {
    console.log(`\nOK runtime JS: ${dwcJs[0]}`)
  }

  if (dwcCss.length !== 1) {
    console.error(
      `\nFAIL: expected exactly one dwc/css/nxt.<hash>.css or dwc/css/nxt-<hash>.css, got: ${dwcCss.join(', ') || '(none)'}`
    )
    ok = false
  } else {
    console.log(`OK runtime CSS: ${dwcCss[0]}`)
  }

  if (dwcExtra.length > 0) {
    console.warn(`\nWARN: extra dwc/ entries:`)
    dwcExtra.forEach((n) => console.warn(`  ${n}`))
  }

  const jsRel = dwcJs[0]?.replace(/^dwc\//, '')
  const cssRel = dwcCss[0]?.replace(/^dwc\//, '')

  const httpJs = jsRel ? `nxt/${jsRel}` : 'nxt/js/nxt-<hash>.js'
  const httpCss = cssRel ? `nxt/${cssRel}` : 'nxt/css/nxt-<hash>.css'

  console.log('\n=== After install on SBC (DSF → 0:/www/nxt/) ===\n')
  console.log('ZIP entries (flat dwc/):')
  console.log(`  ${dwcJs[0] || '(missing js)'}`)
  console.log(`  ${dwcCss[0] || '(missing css)'}`)
  console.log('On SD / www (via virtual 0:/www/):')
  console.log(`  0:/www/${httpJs}`)
  console.log(`  0:/www/${httpCss}`)
  console.log('plugin.dwcFiles + browser URL:')
  console.log(`  ${httpJs}`)
  console.log(`  ${httpCss}`)
  console.log('\nBrowser should request:')
  console.log(`  GET /${httpJs}`)
  console.log(`  GET /${httpCss}`)
  console.log('\nObject model persistence:')
  console.log('  0:/sys/dwc-plugins.json  →  plugins.nxt.dwcFiles[]')

  console.log('\n=== Version skew (exact DWC match) ===\n')
  const pinPath = path.join(__dirname, '..', 'ci', 'dwc-build-ref')
  let pin = 'v3.7.0-beta.1'
  try {
    pin = fs.readFileSync(pinPath, 'utf8').trim()
  } catch {
    /* ignore */
  }
  console.log(`Build pin (ci/dwc-build-ref): ${pin}`)
  console.log(`plugin.json dwcVersion after build: ${pluginJson.dwcVersion}`)
  console.log('Host DWC must match dwcVersion EXACTLY (DWC rejects load before the chunk runs).')
  const pinVer = pin.replace(/^v/, '')
  if (pluginJson.dwcVersion && pluginJson.dwcVersion !== pinVer && /^\d+\.\d+\.\d+/.test(pluginJson.dwcVersion)) {
    console.warn(`WARN: ZIP dwcVersion ${pluginJson.dwcVersion} differs from pin ${pinVer} (rebuild with aligned DWC tree)`)
  }
  if (pluginJson.dwcVersion && /^\d+\.\d+$/.test(pluginJson.dwcVersion)) {
    console.warn('WARN: dwcVersion is major.minor only (old auto-major build) — rebuild with dwcVersion "auto" in ui/plugin.json')
  }

  if (!ok) {
    process.exit(1)
  }
  console.log('\nZIP layout OK for install.\n')
}

main()
