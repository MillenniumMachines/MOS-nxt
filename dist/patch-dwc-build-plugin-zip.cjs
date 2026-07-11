#!/usr/bin/env node
/**
 * Patch DWC build-plugin.js for nxt plugin ZIP builds.
 *
 * Webpack / DWC 3.6.x:
 * - Include split chunks (vendors~nxt.*) and only .js/.css (not .map/.gz)
 * - Keep official flat dwc/js + dwc/css layout
 *
 * Vite / DWC 3.7+:
 * - Flat dwc/js|css with nxt-<hash>.* is already correct — no chunk filter patch.
 * - Always externalise legacy Vue 2 host paths (@/routes, @/store) so Vite can
 *   emit an IIFE while the UI is still mid-port (runtime still needs Vue 3 API).
 * - Optional: NXT_SKIP_DWC_TYPECHECK=1 softens the vue-tsc gate for packaging smoke.
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
let changed = false

const isVite =
  /\bfrom\s+["']vite["']/.test(s) ||
  /entryFileNames:\s*`\$\{manifest\.id\}-\[hash\]\.js`/.test(s) ||
  /createZip\(assembleDir,\s*zipPath\)/.test(s)

if (isVite) {
  // Externalise DWC 3.6-era plugin host paths that Vite does not know about.
  // Map them onto the flat window.DWC surface (same as @/plugins / @/stores).
  const extBefore =
    '/^@\\/\\(composables\\|i18n\\|plugins\\|stores\\)\\(\\/\\.\\*\\)\\?\\$/'
  const extAfter =
    '/^@\\/\\(composables\\|i18n\\|plugins\\|stores\\|routes\\|store\\)\\(\\/\\.\\*\\)\\?\\$/'
  // Source uses: /^@\/(composables|i18n|plugins|stores)(\/.*)?$/
  const extRe =
    /\/\^@\\\/\(composables\|i18n\|plugins\|stores\)\(\\\/\.\*\)\?\$\//g
  const extRePatched =
    /\/\^@\\\/\(composables\|i18n\|plugins\|stores\|routes\|store\)\(\\\/\.\*\)\?\$\//g

  if (extRe.test(s)) {
    s = s.replace(
      extRe,
      '/^@\\/(composables|i18n|plugins|stores|routes|store)(\\/.*)?$/'
    )
    changed = true
  } else if (!extRePatched.test(s)) {
    console.error(
      'patch-dwc-build-plugin-zip: Vite external() regex not found (DWC script changed?)'
    )
    process.exit(1)
  }

  // globals() callback uses a slightly different set (no i18n — that is in PLUGIN_GLOBALS).
  const globRe =
    /\/\^@\\\/\(composables\|plugins\|stores\)\(\\\/\.\*\)\?\$\//g
  const globRePatched =
    /\/\^@\\\/\(composables\|plugins\|stores\|routes\|store\)\(\\\/\.\*\)\?\$\//g
  if (globRe.test(s)) {
    s = s.replace(
      globRe,
      '/^@\\/(composables|plugins|stores|routes|store)(\\/.*)?$/'
    )
    changed = true
  } else if (!globRePatched.test(s)) {
    console.error(
      'patch-dwc-build-plugin-zip: Vite globals() regex not found (DWC script changed?)'
    )
    process.exit(1)
  }

  if (process.env.NXT_SKIP_DWC_TYPECHECK === '1') {
    const re =
      /if\s*\(\s*!typeCheckPlugin\(\s*resolvedPluginDir\s*\)\s*\)\s*\{\s*process\.exit\(\s*1\s*\);\s*\}/
    if (!re.test(s)) {
      console.error(
        'patch-dwc-build-plugin-zip: NXT_SKIP_DWC_TYPECHECK=1 but typeCheckPlugin gate not found (DWC script changed?)'
      )
      process.exit(1)
    }
    s = s.replace(
      re,
      'if (!typeCheckPlugin(resolvedPluginDir)) {\n' +
        '\t\tconsole.warn("[nxt] NXT_SKIP_DWC_TYPECHECK=1 — continuing despite vue-tsc failures");\n' +
        '\t}'
    )
    changed = true
    console.log(
      'patch-dwc-build-plugin-zip: DWC Vite — typecheck gate softened (NXT_SKIP_DWC_TYPECHECK=1)'
    )
  }

  if (changed) {
    fs.writeFileSync(path, s)
    console.log(
      'patch-dwc-build-plugin-zip: DWC Vite — externalised legacy @/routes + @/store'
    )
  } else {
    console.log(
      'patch-dwc-build-plugin-zip: DWC Vite builder — already patched / no further changes'
    )
  }
  process.exit(0)
}

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

// Undo mistaken dwc/nxt/js subdir patch if present from an older nxt build
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
