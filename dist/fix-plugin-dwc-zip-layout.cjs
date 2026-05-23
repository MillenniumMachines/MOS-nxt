#!/usr/bin/env node
/**
 * Fix ZIP layout for DSF www install:
 *   dwc/NeXT/js/...  →  dwc/js/...   (wrong double-NeXT folder)
 *   dwc/js/...       →  unchanged    (correct)
 * Then re-inject plugin.json dwcFiles as NeXT/js/...
 *
 * Usage: DWC_REPO_PATH=<dwc> node dist/fix-plugin-dwc-zip-layout.cjs <NeXT.zip>
 */
'use strict'

const fs = require('fs')
const path = require('path')

const PLUGIN_ID = 'NeXT'
const dwcRoot = process.env.DWC_REPO_PATH || path.join(__dirname, '..', '..', 'DuetWebControl')
const zipPath = process.argv[2]

if (!zipPath || !fs.existsSync(zipPath)) {
  console.error('usage: DWC_REPO_PATH=<dwc> node dist/fix-plugin-dwc-zip-layout.cjs <NeXT.zip>')
  process.exit(1)
}

const JSZip = require(path.join(dwcRoot, 'node_modules', 'jszip'))

;(async () => {
  const zip = await JSZip.loadAsync(fs.readFileSync(zipPath))
  const fixed = []

  for (const name of Object.keys(zip.files)) {
    if (zip.files[name].dir) continue
    const nested = name.match(/^dwc\/NeXT\/(js|css)\/(NeXT\.[a-f0-9]+\.(js|css))$/)
    if (!nested) continue
    const flatName = `dwc/${nested[1]}/${nested[2]}`
    if (zip.files[flatName]) {
      zip.remove(name)
      fixed.push(`removed duplicate ${name} (already have ${flatName})`)
      continue
    }
    const data = await zip.file(name).async('nodebuffer')
    zip.file(flatName, data)
    zip.remove(name)
    fixed.push(`${name} → ${flatName}`)
  }

  if (fixed.length === 0) {
    console.log('fix-plugin-dwc-zip-layout: no dwc/NeXT/js|css entries (layout OK or empty)')
  } else {
    fixed.forEach((line) => console.log(`  ${line}`))
  }

  require('child_process').execFileSync(
    process.execPath,
    [path.join(__dirname, 'inject-plugin-dwcfiles.cjs'), zipPath],
    { env: { ...process.env, DWC_REPO_PATH: dwcRoot }, stdio: 'inherit' }
  )
})().catch((e) => {
  console.error(e)
  process.exit(1)
})
