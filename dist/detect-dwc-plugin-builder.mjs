#!/usr/bin/env node
/**
 * Detect whether a DuetWebControl tree uses the Vite external-plugin builder (3.7+)
 * or the legacy webpack/vue-cli builder (3.6.x).
 *
 * Usage: node dist/detect-dwc-plugin-builder.mjs <path-to-DuetWebControl>
 * Prints: vite | webpack
 * Exit 0 always when the tree is readable; exit 1 if build-plugin.js is missing.
 */
import fs from 'node:fs'
import path from 'node:path'

const dwcRoot = process.argv[2]
if (!dwcRoot) {
  console.error('usage: node dist/detect-dwc-plugin-builder.mjs <path-to-DuetWebControl>')
  process.exit(1)
}

const buildPluginJs = path.join(dwcRoot, 'scripts', 'build-plugin.js')
if (!fs.existsSync(buildPluginJs)) {
  console.error(`error: missing ${buildPluginJs}`)
  process.exit(1)
}

const src = fs.readFileSync(buildPluginJs, 'utf8')
// DWC 3.7+ Vite IIFE builder imports vite and writes ZIP next to the plugin dir.
const isVite =
  /\bfrom\s+["']vite["']/.test(src) ||
  /entryFileNames:\s*`\$\{manifest\.id\}-\[hash\]\.js`/.test(src) ||
  /createZip\(assembleDir,\s*zipPath\)/.test(src)

process.stdout.write(isVite ? 'vite\n' : 'webpack\n')
