#!/usr/bin/env node
/**
 * Patch DWC build-plugin.js for NeXT plugin ZIP layout:
 * 1) Include split chunks (vendors~NeXT.*) and only .js/.css (not .map/.gz)
 * 2) Place dwc assets under dwc/<pluginId>/js|css/ so SBC install lands at
 *    0:/www/NeXT/js/... (DSF) and dwcFiles is NeXT/js/NeXT.<hash>.js — not flat js/
 *    which 404s when the server only exposes the plugin subdirectory.
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

const cssNeedle = 'archive.file(distDir + "/css/" + file, { name: "dwc/css/" + file });'
const cssReplacement =
  'archive.file(distDir + "/css/" + file, { name: "dwc/" + pluginManifest.id + "/css/" + file });'
const jsNeedle = 'archive.file(distDir + "/js/" + file, { name: "dwc/js/" + file });'
const jsReplacement =
  'archive.file(distDir + "/js/" + file, { name: "dwc/" + pluginManifest.id + "/js/" + file });'

if (!s.includes(cssNeedle) || !s.includes(jsNeedle)) {
  console.error('patch-dwc-build-plugin-zip: dwc archive path needles missing (already patched or DWC changed?)')
  process.exit(1)
}
s = s.replace(cssNeedle, cssReplacement).replace(jsNeedle, jsReplacement)

fs.writeFileSync(path, s)
console.log('patch-dwc-build-plugin-zip: updated', path)
