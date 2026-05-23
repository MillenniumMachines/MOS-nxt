#!/usr/bin/env node
/**
 * Write resolved dwcFiles into plugin.json inside the built ZIP (paths without dwc/ prefix).
 * Matches PollConnector / DSF: dwc/NeXT/js/file.js → dwcFiles "NeXT/js/file.js"
 *
 * Usage: DWC_REPO_PATH=<dwc> node dist/inject-plugin-dwcfiles.mjs <NeXT.zip>
 */
'use strict'

const fs = require('fs')
const path = require('path')

const dwcRoot = process.env.DWC_REPO_PATH || path.join(__dirname, '..', '..', 'DuetWebControl')
const zipPath = process.argv[2]

if (!zipPath || !fs.existsSync(zipPath)) {
  console.error('usage: DWC_REPO_PATH=<dwc> node dist/inject-plugin-dwcfiles.mjs <NeXT.zip>')
  process.exit(1)
}

const JSZip = require(path.join(dwcRoot, 'node_modules', 'jszip'))

;(async () => {
  const zip = await JSZip.loadAsync(fs.readFileSync(zipPath))
  const dwcFiles = []

  for (const name of Object.keys(zip.files)) {
    if (name.endsWith('/') || !name.startsWith('dwc/')) continue
    const rel = name.substring(4)
    if (/\.(js|css)$/.test(rel) && rel.includes('NeXT')) {
      dwcFiles.push(rel)
    }
  }
  dwcFiles.sort()

  const js = dwcFiles.filter((f) => /\.js$/.test(f) && f.includes('NeXT'))
  const css = dwcFiles.filter((f) => /\.css$/.test(f) && f.includes('NeXT'))
  if (js.length !== 1 || css.length !== 1) {
    console.error(`inject-plugin-dwcfiles: expected 1 js + 1 css, got js=${js.length} css=${css.length}`)
    dwcFiles.forEach((f) => console.error(`  ${f}`))
    process.exit(1)
  }

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
  console.log(`inject-plugin-dwcfiles: ${path.basename(zipPath)}`)
  console.log(`  dwcFiles: ${JSON.stringify(dwcFiles)}`)
})().catch((e) => {
  console.error(e)
  process.exit(1)
})
