#!/usr/bin/env node
/**
 * Write dwcFiles into plugin.json for release dwc-plugins.json sync.
 *
 * DSF installs the contents of dwc/ under 0:/www/nxt/ (see DSF PLUGINS.md).
 *   ZIP dwc/js/nxt.<hash>.js or nxt-<hash>.js  →  0:/www/nxt/js/...
 *   Browser URL                                 →  /nxt/js/...
 *
 * Do NOT use dwc/nxt/js/ in the ZIP (that becomes www/nxt/nxt/js/ → 404).
 * DWC 3.7 Vite emits nxt-<hash>.*; webpack 3.6 emitted nxt.<hash>.*.
 *
 * Usage: DWC_REPO_PATH=<dwc> node dist/inject-plugin-dwcfiles.cjs <nxt.zip>
 */
'use strict'

const fs = require('fs')
const path = require('path')

const PLUGIN_ID = 'nxt'
const dwcRoot = process.env.DWC_REPO_PATH || path.join(__dirname, '..', '..', 'DuetWebControl')
const zipPath = process.argv[2]

if (!zipPath || !fs.existsSync(zipPath)) {
  console.error('usage: DWC_REPO_PATH=<dwc> node dist/inject-plugin-dwcfiles.cjs <nxt.zip>')
  process.exit(1)
}

const JSZip = require(path.join(dwcRoot, 'node_modules', 'jszip'))

function dwcRelToServedUrl(zipEntry) {
  const rel = zipEntry.substring(4)
  if (/^nxt\/(js|css)\//.test(rel)) {
    console.error(
      `inject-plugin-dwcfiles: wrong ZIP layout ${zipEntry} — use dwc/js/ not dwc/nxt/js/ (run dist/fix-plugin-dwc-zip-layout.cjs)`
    )
    process.exit(1)
  }
  return `${PLUGIN_ID}/${rel}`
}

;(async () => {
  const zip = await JSZip.loadAsync(fs.readFileSync(zipPath))
  const dwcFiles = []

  for (const name of Object.keys(zip.files)) {
    if (name.endsWith('/') || !name.startsWith('dwc/')) continue
    const rel = name.substring(4)
    if (/\.(js|css)$/.test(rel) && rel.includes(PLUGIN_ID)) {
      dwcFiles.push(dwcRelToServedUrl(name))
    }
  }
  dwcFiles.sort()

  // Prefer runtime bundles; ignore source maps if present in the ZIP.
  const js = dwcFiles.filter((f) => /\.js$/.test(f) && !/\.js\.map$/.test(f))
  const css = dwcFiles.filter((f) => /\.css$/.test(f) && !/\.css\.map$/.test(f))
  if (js.length < 1 || css.length < 1) {
    console.error(`inject-plugin-dwcfiles: expected ≥1 js + ≥1 css, got js=${js.length} css=${css.length}`)
    dwcFiles.forEach((f) => console.error(`  ${f}`))
    process.exit(1)
  }
  if (js.length !== 1 || css.length !== 1) {
    console.warn(
      `inject-plugin-dwcfiles: expected 1 js + 1 css, got js=${js.length} css=${css.length} — using first of each`
    )
    dwcFiles.forEach((f) => console.warn(`  ${f}`))
  }
  const dwcFilesFinal = [js[0], css[0]].sort()

  const pluginJson = JSON.parse(await zip.file('plugin.json').async('string'))
  pluginJson.dwcFiles = dwcFilesFinal
  zip.file('plugin.json', JSON.stringify(pluginJson, null, 2))

  fs.writeFileSync(
    zipPath,
    await zip.generateAsync({
      type: 'nodebuffer',
      compression: 'DEFLATE',
      compressionOptions: { level: 6 }
    })
  )
  console.log(`inject-plugin-dwcfiles: ${path.basename(zipPath)}`)
  console.log(`  ZIP: dwc/js|css (flat)`)
  console.log(`  dwcFiles (HTTP paths): ${JSON.stringify(dwcFilesFinal)}`)
})().catch((e) => {
  console.error(e)
  process.exit(1)
})
