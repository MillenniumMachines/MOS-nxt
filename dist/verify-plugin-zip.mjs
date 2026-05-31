#!/usr/bin/env node
/**
 * Verify a NeXT plugin ZIP has the dwc layout needed to avoid 404 / empty dwcFiles issues.
 *
 * Usage: node dist/verify-plugin-zip.mjs [path-to-NeXT.zip]
 */
import fs from 'node:fs'
import { execSync } from 'node:child_process'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

function main() {
  const zipPath = process.argv[2] || path.join(__dirname, '..', 'dist', 'nxt-v0.6.0-565d193-dirty.zip')
  if (!fs.existsSync(zipPath)) {
    console.error(`error: zip not found: ${zipPath}`)
    process.exit(1)
  }

  const listing = execSync(`unzip -Z1 "${zipPath}"`, { encoding: 'utf8' })
    .split(/\r?\n/)
    .filter(Boolean)

  const dwcJs = listing.filter((n) => /^dwc\/js\/NeXT\.[a-f0-9]+\.js$/.test(n))
  const dwcCss = listing.filter((n) => /^dwc\/css\/NeXT\.[a-f0-9]+\.css$/.test(n))
  const badNested = listing.filter((n) => /^dwc\/NeXT\/(js|css)\/NeXT\.[a-f0-9]+\.(js|css)$/.test(n))
  const dwcExtra = listing.filter(
    (n) =>
      /^dwc\//.test(n) &&
      !/^dwc\/js\/NeXT\.[a-f0-9]+\.js$/.test(n) &&
      !/^dwc\/css\/NeXT\.[a-f0-9]+\.css$/.test(n)
  )
  if (badNested.length > 0) {
    console.error('\nFAIL: dwc/NeXT/js nested layout — DSF installs to www/NeXT/NeXT/js (404 at /NeXT/js/)')
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

  console.log('\n=== NeXT plugin ZIP verification ===\n')
  console.log(`ZIP: ${zipPath}`)
  console.log(`plugin.json id: ${pluginJson.id}`)
  console.log(`plugin.json dwcVersion: ${pluginJson.dwcVersion}`)
  console.log(`plugin.json version: ${pluginJson.version}`)

  let ok = true

  if (dwcJs.length !== 1) {
    console.error(
      `\nFAIL: expected exactly one dwc/js/NeXT.<hash>.js, got: ${dwcJs.join(', ') || '(none)'}`
    )
    ok = false
  } else {
    console.log(`\nOK runtime JS: ${dwcJs[0]}`)
  }

  if (dwcCss.length !== 1) {
    console.error(
      `\nFAIL: expected exactly one dwc/css/NeXT.<hash>.css, got: ${dwcCss.join(', ') || '(none)'}`
    )
    ok = false
  } else {
    console.log(`OK runtime CSS: ${dwcCss[0]}`)
  }

  if (dwcExtra.length > 0) {
    console.warn(`\nWARN: extra dwc/ entries (should not be uploaded after zip patch):`)
    dwcExtra.forEach((n) => console.warn(`  ${n}`))
  }

  const jsRel = dwcJs[0]?.replace(/^dwc\//, '')
  const cssRel = dwcCss[0]?.replace(/^dwc\//, '')

  const httpJs = jsRel ? `NeXT/${jsRel}` : 'NeXT/js/NeXT.<hash>.js'
  const httpCss = cssRel ? `NeXT/${cssRel}` : 'NeXT/css/NeXT.<hash>.css'

  console.log('\n=== After install on SBC (DSF → 0:/www/NeXT/) ===\n')
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
  console.log('  0:/sys/dwc-plugins.json  →  plugins.NeXT.dwcFiles[]')

  console.log('\n=== Version skew (exact DWC match) ===\n')
  const pinPath = path.join(__dirname, '..', 'ci', 'dwc-build-ref')
  let pin = 'v3.6.2'
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
