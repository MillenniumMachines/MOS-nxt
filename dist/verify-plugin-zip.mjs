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
  const zipPath = process.argv[2] || path.join(__dirname, '..', 'dist', 'NeXT-v0.6.0-565d193-dirty.zip')
  if (!fs.existsSync(zipPath)) {
    console.error(`error: zip not found: ${zipPath}`)
    process.exit(1)
  }

  const listing = execSync(`unzip -Z1 "${zipPath}"`, { encoding: 'utf8' })
    .split(/\r?\n/)
    .filter(Boolean)

  const dwcJs = listing.filter((n) => /^dwc\/NeXT\/js\/NeXT\.[a-f0-9]+\.js$/.test(n))
  const dwcCss = listing.filter((n) => /^dwc\/NeXT\/css\/NeXT\.[a-f0-9]+\.css$/.test(n))
  const legacyFlat = listing.filter((n) => /^dwc\/js\/NeXT\.[a-f0-9]+\.js$/.test(n))
  const dwcExtra = listing.filter(
    (n) =>
      /^dwc\//.test(n) &&
      !/^dwc\/NeXT\/js\/NeXT\.[a-f0-9]+\.js$/.test(n) &&
      !/^dwc\/NeXT\/css\/NeXT\.[a-f0-9]+\.css$/.test(n)
  )
  if (legacyFlat.length > 0) {
    console.warn('\nWARN: flat dwc/js/ layout (old ZIP) — SBC installs often 404; rebuild with current build-plugin.sh')
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
      `\nFAIL: expected exactly one dwc/NeXT/js/NeXT.<hash>.js, got: ${dwcJs.join(', ') || '(none)'}`
    )
    ok = false
  } else {
    console.log(`\nOK runtime JS: ${dwcJs[0]}`)
  }

  if (dwcCss.length !== 1) {
    console.error(
      `\nFAIL: expected exactly one dwc/NeXT/css/NeXT.<hash>.css, got: ${dwcCss.join(', ') || '(none)'}`
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

  console.log('\n=== After install on printer (PollConnector) ===\n')
  console.log('plugin.dwcFiles should include at least:')
  console.log(`  ${jsRel}`)
  console.log(`  ${cssRel}`)
  console.log('\nFiles on DWC www root (same paths):')
  console.log(`  ${jsRel}`)
  console.log(`  ${cssRel}`)
  console.log('\nBrowser should request (relative to DWC URL):')
  console.log(`  GET ${jsRel}`)
  console.log(`  GET ${cssRel}`)
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
