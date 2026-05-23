#!/usr/bin/env node
/**
 * One-off fix: move flat dwc/js|css in an existing NeXT ZIP to dwc/NeXT/js|css
 * (SBC www path mismatch). Re-injects plugin.json dwcFiles.
 *
 * Usage: DWC_REPO_PATH=<dwc> node dist/repack-plugin-dwc-subdir.mjs <NeXT.zip>
 */
'use strict'

const fs = require('fs')
const path = require('path')

const PLUGIN_ID = 'NeXT'
const dwcRoot = process.env.DWC_REPO_PATH || path.join(__dirname, '..', '..', 'DuetWebControl')
const zipPath = process.argv[2]

if (!zipPath || !fs.existsSync(zipPath)) {
  console.error('usage: DWC_REPO_PATH=<dwc> node dist/repack-plugin-dwc-subdir.mjs <NeXT.zip>')
  process.exit(1)
}

const JSZip = require(path.join(dwcRoot, 'node_modules', 'jszip'))

;(async () => {
  const zip = await JSZip.loadAsync(fs.readFileSync(zipPath))
  const moved = []

  for (const name of Object.keys(zip.files)) {
    if (zip.files[name].dir) continue
    const m = name.match(/^dwc\/(js|css)\/(NeXT\.[a-f0-9]+\.(js|css))$/)
    if (!m) continue
    const newName = `dwc/${PLUGIN_ID}/${m[1]}/${m[2]}`
    const data = await zip.file(name).async('nodebuffer')
    zip.file(newName, data)
    zip.remove(name)
    moved.push(`${name} → ${newName}`)
  }

  if (moved.length === 0) {
    console.log('repack-plugin-dwc-subdir: no flat dwc/js|css entries to move (already subdir layout?)')
  } else {
    moved.forEach((line) => console.log(`  ${line}`))
  }

  const dwcFiles = []
  for (const name of Object.keys(zip.files)) {
    if (zip.files[name].dir || !name.startsWith('dwc/')) continue
    const rel = name.substring(4)
    if (/\.(js|css)$/.test(rel) && rel.includes(PLUGIN_ID)) dwcFiles.push(rel)
  }
  dwcFiles.sort()
  const pluginJson = JSON.parse(await zip.file('plugin.json').async('string'))
  pluginJson.dwcFiles = dwcFiles
  zip.file('plugin.json', JSON.stringify(pluginJson, null, 2))

  fs.writeFileSync(
    zipPath,
    await zip.generateAsync({
      type: 'nodebuffer',
      compression: 'DEFLATE',
      compressionOptions: { level: 6 }
    })
  )
  console.log(`repack-plugin-dwc-subdir: wrote ${zipPath}`)
  console.log(`  dwcFiles: ${JSON.stringify(dwcFiles)}`)
})().catch((e) => {
  console.error(e)
  process.exit(1)
})
