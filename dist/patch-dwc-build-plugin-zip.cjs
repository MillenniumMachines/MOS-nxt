#!/usr/bin/env node
/**
 * Patch DWC build-plugin.js for NeXT plugin ZIP:
 * - Include split chunks (vendors~NeXT.*) and only .js/.css (not .map/.gz)
 * - Keep official flat dwc/js + dwc/css layout (DSF installs dwc/* under 0:/www/NeXT/)
 *
 * Usage: node patch-dwc-build-plugin-zip.cjs <path-to-DWC>/scripts/build-plugin.js
 */
'use strict'

const fs = require('fs')
const path = process.argv[2]
if (!path || !fs.existsSync(path)) {
  console.error('usage: node patch-dwc-build-plugin-zip.cjs <build-plugin.js>')
  process.exit(1)
}

let s = fs.readFileSync(path, 'utf8')

const filterNeedle = 'if (file.indexOf(pluginManifest.id + ".") === 0) {'
const filterReplacement =
  'if ((file.indexOf(pluginManifest.id + ".") === 0 || file.includes("~" + pluginManifest.id) || file.indexOf("." + pluginManifest.id + ".") > 0) && (/\\.js$/.test(file) || /\\.css$/.test(file))) {'

const filterCount = s.split(filterNeedle).length - 1
if (filterCount !== 2) {
  console.error(
    `patch-dwc-build-plugin-zip: expected 2 filter matches, found ${filterCount} (DWC script changed?)`
  )
  process.exit(1)
}
s = s.split(filterNeedle).join(filterReplacement)

// Undo mistaken dwc/NeXT/js subdir patch if present from an older NeXT build
const cssSub = 'archive.file(distDir + "/css/" + file, { name: "dwc/" + pluginManifest.id + "/css/" + file });'
const cssFlat = 'archive.file(distDir + "/css/" + file, { name: "dwc/css/" + file });'
const jsSub = 'archive.file(distDir + "/js/" + file, { name: "dwc/" + pluginManifest.id + "/js/" + file });'
const jsFlat = 'archive.file(distDir + "/js/" + file, { name: "dwc/js/" + file });'
if (s.includes(cssSub)) {
  s = s.replace(cssSub, cssFlat)
}
if (s.includes(jsSub)) {
  s = s.replace(jsSub, jsFlat)
}

fs.writeFileSync(path, s)
console.log('patch-dwc-build-plugin-zip: updated', path)
