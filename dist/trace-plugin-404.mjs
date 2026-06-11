#!/usr/bin/env node
/**
 * Trace nxt plugin install → browser URL (404 / timeout investigation).
 *
 * DSF (SBC): contents of dwc/ install under 0:/www/nxt/
 *   ZIP dwc/js/nxt.<hash>.js  →  disk 0:/www/nxt/js/nxt.<hash>.js  →  GET /nxt/js/nxt.<hash>.js
 *
 * Wrong ZIP dwc/nxt/js/...  →  disk 0:/www/nxt/nxt/js/...  →  GET /nxt/js/... is 404
 *
 * Usage:
 *   node dist/trace-plugin-404.mjs <nxt.zip> [dwc-plugins.json]
 */
import fs from 'node:fs'
import { execSync } from 'node:child_process'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const PLUGIN_ID = 'nxt'

function readZipListing(zipPath) {
  return execSync(`unzip -Z1 "${zipPath}"`, { encoding: 'utf8' })
    .split(/\r?\n/)
    .filter(Boolean)
}

function zipToHttpPath(zipEntry) {
  const rel = zipEntry.substring(4)
  if (/^nxt\//.test(rel)) {
    return null
  }
  return `${PLUGIN_ID}/${rel}`
}

function loadPluginsJson(filePath) {
  const raw = fs.readFileSync(filePath, 'utf8')
  const data = JSON.parse(raw)
  if (data?.nxt) return data.nxt
  if (data?.plugins?.nxt) return data.plugins.nxt
  return Object.values(data).find((v) => v && typeof v === 'object' && v.id === 'nxt') ?? null
}

function hashFromJsPath(p) {
  const m = String(p).match(/nxt\.([a-f0-9]+)\.js$/i)
  return m ? m[1] : null
}

function main() {
  const zipPath = process.argv[2]
  const pluginsPath = process.argv[3]

  if (!zipPath || !fs.existsSync(zipPath)) {
    console.error('usage: node dist/trace-plugin-404.mjs <nxt.zip> [dwc-plugins.json]')
    process.exit(1)
  }

  const listing = readZipListing(zipPath)
  const flatJs = listing.filter((n) => /^dwc\/js\/nxt\.[a-f0-9]+\.js$/.test(n))
  const flatCss = listing.filter((n) => /^dwc\/css\/nxt\.[a-f0-9]+\.css$/.test(n))
  const badJs = listing.filter((n) => /^dwc\/nxt\/js\/nxt\.[a-f0-9]+\.js$/.test(n))

  const httpJs = flatJs[0] ? zipToHttpPath(flatJs[0]) : null
  const httpCss = flatCss[0] ? zipToHttpPath(flatCss[0]) : null
  const zipHash = httpJs ? hashFromJsPath(httpJs) : null

  console.log('\n=== nxt plugin 404 trace ===\n')
  console.log(`ZIP: ${zipPath}`)

  let exitCode = 0

  console.log('\n--- ZIP layout (DSF www mapping) ---\n')
  if (badJs.length > 0) {
    console.log('FAIL: nested dwc/nxt/js/ in ZIP')
    badJs.forEach((n) => console.log(`  ${n} → www/nxt/nxt/js/ (browser /nxt/js/ 404)`))
    console.log('Fix: node dist/fix-plugin-dwc-zip-layout.cjs', zipPath)
    exitCode = 2
  }
  if (flatJs.length === 1) {
    console.log(`OK ZIP:   ${flatJs[0]}`)
    console.log(`On SBC:  0:/www/${httpJs}`)
    console.log(`Browser: GET /${httpJs}`)
  } else {
    console.log(`FAIL: expected dwc/js/nxt.<hash>.js, got ${flatJs.length}`)
    exitCode = 2
  }
  if (flatCss.length === 1) {
    console.log(`OK CSS:  ${flatCss[0]} → /${httpCss}`)
  }

  if (pluginsPath) {
    if (!fs.existsSync(pluginsPath)) {
      console.error(`\nerror: ${pluginsPath} not found`)
      process.exit(1)
    }
    const plugin = loadPluginsJson(pluginsPath)
    console.log('\n--- Printer dwc-plugins.json ---\n')
    if (!plugin) {
      console.log('  No nxt entry')
      exitCode = 2
    } else {
      const omFiles = plugin.dwcFiles ?? []
      const omJs = omFiles.find((f) => /\.js$/.test(f) && f.includes('nxt'))
      const omHash = omJs ? hashFromJsPath(omJs) : null
      console.log(`  dwcFiles: ${JSON.stringify(omFiles)}`)
      if (!omJs) {
        console.log('  FAIL: no js path in dwcFiles')
        exitCode = 2
      } else if (httpJs && omJs !== httpJs) {
        console.log(`  FAIL: OM path "${omJs}" ≠ expected "${httpJs}"`)
        exitCode = 2
      } else if (zipHash && omHash && zipHash !== omHash) {
        console.log(`  FAIL: hash mismatch ZIP ${zipHash} vs OM ${omHash} — reinstall ZIP`)
        exitCode = 2
      } else {
        console.log('  OK: dwcFiles matches flat dwc/ → /nxt/js/ URL')
      }
    }
  }

  console.log('\n--- Timeout during install ---\n')
  console.log('  nxt ZIP includes many sd/sys macros — install can take several minutes.')
  console.log('  If upload times out, dwc www files may never land → 404 on /nxt/js/*.js')
  console.log('  Retry on stable network; confirm 0:/www/nxt/js/nxt.<hash>.js exists in Files → System.')

  console.log('\n--- Common causes ---\n')
  console.log('  A) Wrong ZIP dwc/nxt/js/ layout (double folder on www)')
  console.log('  B) Install timed out before dwc/ uploaded')
  console.log('  C) dwcFiles hash ≠ file on www (partial upgrade)')
  console.log('  D) Only copied sd/sys macros — must install nxt-*.zip via Settings → Plugins')

  process.exit(exitCode)
}

main()
