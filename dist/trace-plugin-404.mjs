#!/usr/bin/env node
/**
 * Trace NeXT plugin install → browser URL (404 investigation).
 *
 * PollConnector maps ZIP dwc/js/NeXT.<hash>.js → <directories.web>/js/NeXT.<hash>.js
 * and records plugin.dwcFiles as "js/NeXT.<hash>.js" (no "dwc/" prefix).
 *
 * Usage:
 *   node dist/trace-plugin-404.mjs <NeXT.zip> [0:/sys/dwc-plugins.json]
 *
 * With dwc-plugins.json (download from printer or paste path), compares hashes.
 */
import fs from 'node:fs'
import { execSync } from 'node:child_process'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

function readZipListing(zipPath) {
  return execSync(`unzip -Z1 "${zipPath}"`, { encoding: 'utf8' })
    .split(/\r?\n/)
    .filter(Boolean)
}

function dwcRelFromZipEntry(entry) {
  if (!entry.startsWith('dwc/')) return null
  return entry.substring(4)
}

function loadPluginsJson(filePath) {
  const raw = fs.readFileSync(filePath, 'utf8')
  const data = JSON.parse(raw)
  if (data?.NeXT) return data.NeXT
  if (data?.plugins?.NeXT) return data.plugins.NeXT
  const first = Object.values(data).find((v) => v && typeof v === 'object' && v.id === 'NeXT')
  return first ?? null
}

function hashFromJsPath(p) {
  const m = String(p).match(/NeXT\.([a-f0-9]+)\.js$/i)
  return m ? m[1] : null
}

function main() {
  const zipPath = process.argv[2]
  const pluginsPath = process.argv[3]

  if (!zipPath || !fs.existsSync(zipPath)) {
    console.error('usage: node dist/trace-plugin-404.mjs <NeXT.zip> [dwc-plugins.json]')
    process.exit(1)
  }

  const listing = readZipListing(zipPath)
  const dwcEntries = listing.filter((n) => n.startsWith('dwc/'))
  const jsEntries = dwcEntries.filter((n) => /^dwc\/NeXT\/js\/NeXT\.[a-f0-9]+\.js$/.test(n))
  const cssEntries = dwcEntries.filter((n) => /^dwc\/NeXT\/css\/NeXT\.[a-f0-9]+\.css$/.test(n))
  const legacyJs = dwcEntries.filter((n) => /^dwc\/js\/NeXT\.[a-f0-9]+\.js$/.test(n))
  const extraDwc = dwcEntries.filter(
    (n) =>
      !n.endsWith('/') &&
      !/^dwc\/NeXT\/js\/NeXT\.[a-f0-9]+\.js$/.test(n) &&
      !/^dwc\/NeXT\/css\/NeXT\.[a-f0-9]+\.css$/.test(n)
  )

  const zipJsRel = jsEntries[0] ? dwcRelFromZipEntry(jsEntries[0]) : null
  const zipCssRel = cssEntries[0] ? dwcRelFromZipEntry(cssEntries[0]) : null
  const zipJsHash = zipJsRel ? hashFromJsPath(zipJsRel) : null

  console.log('\n=== NeXT plugin 404 trace ===\n')
  console.log(`ZIP: ${zipPath}`)

  console.log('\n--- ZIP dwc/ layout (what DWC install uploads) ---\n')
  if (legacyJs.length > 0) {
    console.log('\n  WARN: flat dwc/js/ layout — on SBC, files often land at 0:/www/NeXT/js/ but dwcFiles may say js/ → 404')
    console.log('        Rebuild or: node dist/repack-plugin-dwc-subdir.mjs <zip>')
  }
  if (jsEntries.length === 1) {
    console.log(`  ZIP entry:     ${jsEntries[0]}`)
    console.log(`  Upload target: <directories.web>/${zipJsRel}`)
    console.log(`  dwcFiles[]:    ${zipJsRel}`)
    console.log(`  Browser GET:   /<dwc-host>/${zipJsRel}`)
  } else if (legacyJs.length === 1) {
    const rel = legacyJs[0].replace(/^dwc\//, '')
    console.log(`  ZIP entry (legacy): ${legacyJs[0]}`)
    console.log(`  dwcFiles (legacy):  ${rel}`)
    console.log(`  SBC likely needs:   NeXT/js/<same filename> — repack ZIP or reinstall after rebuild`)
  } else {
    console.log(`  FAIL: expected one dwc/NeXT/js/NeXT.<hash>.js, got ${jsEntries.length}`)
  }
  if (cssEntries.length === 1) {
    console.log(`  CSS: ${cssEntries[0]} → ${zipCssRel}`)
  }
  if (extraDwc.length) {
    console.log('\n  WARN: extra dwc/ entries (not uploaded by PollConnector unless in zip):')
    extraDwc.forEach((n) => console.log(`    ${n}`))
  }

  console.log('\n--- Install path (PollConnector) ---\n')
  console.log('  1. For each zip path starting with "dwc/", strip prefix → push to plugin.dwcFiles')
  console.log('  2. upload(combinePath(directories.web, filename)) — typically SBC /opt/dsf/www/')
  console.log('  3. Write 0:/sys/dwc-plugins.json with same dwcFiles[]')
  console.log('  4. loadDwcPlugin → __webpack_require__.e("NeXT") → GET dwcFiles js path')
  console.log('\n  plugin.json in the ZIP is NOT uploaded; only dwc/* and sd/* are.')

  let exitCode = 0

  if (pluginsPath) {
    if (!fs.existsSync(pluginsPath)) {
      console.error(`\nerror: dwc-plugins not found: ${pluginsPath}`)
      process.exit(1)
    }
    const plugin = loadPluginsJson(pluginsPath)
    console.log('\n--- Printer dwc-plugins.json vs this ZIP ---\n')
    if (!plugin) {
      console.log('  No NeXT entry in file')
      exitCode = 2
    } else {
      const omFiles = plugin.dwcFiles ?? []
      const omJs = omFiles.find((f) => /\.js$/.test(f) && f.includes('NeXT'))
      const omHash = omJs ? hashFromJsPath(omJs) : null
      console.log(`  dwcFiles: ${JSON.stringify(omFiles)}`)
      if (!omJs) {
        console.log('\n  FAIL: no js/NeXT.*.js in dwcFiles → browser may request js/NeXT.undefined.js')
        exitCode = 2
      } else if (omJs.startsWith('dwc/')) {
        console.log('\n  FAIL: dwcFiles must be "js/NeXT.<hash>.js", not "dwc/js/..." (double path → 404)')
        exitCode = 2
      } else if (zipJsHash && omHash && zipJsHash !== omHash) {
        console.log(`\n  FAIL: hash mismatch — manifest ${omHash}, this ZIP ${zipJsHash}`)
        console.log('  → 404 unless you reinstall this ZIP or copy www files to match manifest')
        exitCode = 2
      } else if (zipJsRel && omJs && omJs !== zipJsRel) {
        console.log(`\n  FAIL: path mismatch manifest "${omJs}" vs ZIP "${zipJsRel}"`)
        exitCode = 2
      } else {
        console.log('\n  OK: dwc-plugins.js paths match this ZIP')
        console.log(`  Direct test: http://<printer>/${omJs}`)
      }
    }
  } else {
    console.log('\n--- Optional: compare printer manifest ---\n')
    console.log('  Download 0:/sys/dwc-plugins.json and re-run:')
    console.log(`  node dist/trace-plugin-404.mjs "${zipPath}" dwc-plugins.json`)
  }

  console.log('\n--- Common 404 causes (same .call symptom) ---\n')
  console.log('  A) Plugin never installed via DWC → Settings → upload ZIP (files not on www)')
  console.log('  B) SD full release only: dwc/ copied to 0:/dwc/ on SD — NOT the HTTP www root')
  console.log('     (release.sh embeds dwc under sd/dwc/; use plugin ZIP install or copy to www)')
  console.log('  C) Stale dwc-plugins.json / browser cache: old hash in manifest, new ZIP (or reverse)')
  console.log('  D) dwcFiles empty or wrong → js/NeXT.undefined.js')
  console.log('  E) Install interrupted — sd/ macros present but dwc/js missing on www')

  console.log('\n--- Browser checks ---\n')
  if (zipJsRel) {
    console.log(`  DevTools → Network → ${zipJsRel} must be 200 (not 404)`)
    console.log(`  Open: http://<printer-host>/${zipJsRel}`)
  }
  console.log('  If 404: uninstall NeXT, re-upload ZIP, wait for install, hard refresh (Ctrl+Shift+R)\n')

  process.exit(exitCode)
}

main()
