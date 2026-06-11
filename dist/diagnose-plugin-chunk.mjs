#!/usr/bin/env node
/**
 * Deep analysis of nxt dwc/js/*.js vs host app.*.js — explains
 *   can't access property "call", v[ee] is undefined
 *
 * Usage:
 *   node dist/diagnose-plugin-chunk.mjs <nxt.js|zip> [host-app.js]
 */
import fs from 'node:fs'
import path from 'node:path'
import { execSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

function readChunkFromZip(zipPath) {
  let member = ''
  try {
    member = execSync(`unzip -Z1 "${zipPath}" 'dwc/nxt/js/nxt*.js' | head -1`, {
      encoding: 'utf8'
    }).trim()
  } catch {
    /* legacy layout */
  }
  if (!member) {
    member = execSync(`unzip -Z1 "${zipPath}" 'dwc/js/nxt*.js' | head -1`, {
      encoding: 'utf8'
    }).trim()
  }
  if (!member) {
    throw new Error(`no dwc/nxt/js/nxt*.js (or legacy dwc/js) in ${zipPath}`)
  }
  let css = ''
  try {
    css = execSync(`unzip -Z1 "${zipPath}" 'dwc/nxt/css/nxt*.css' | head -1`, {
      encoding: 'utf8'
    }).trim()
  } catch {
    /* legacy */
  }
  if (!css) {
    css = execSync(`unzip -Z1 "${zipPath}" 'dwc/css/nxt*.css' | head -1`, {
      encoding: 'utf8'
    }).trim()
  }
  console.log(`ZIP JS:  ${member}`)
  console.log(`ZIP CSS: ${css || '(missing — styles may not load)'}`)
  return { js: execSync(`unzip -p "${zipPath}" "${member}"`, { maxBuffer: 50 * 1024 * 1024 }), member }
}

function resolveAppJs(appPath) {
  if (fs.existsSync(appPath) && fs.statSync(appPath).isFile()) {
    return appPath
  }
  const dir = fs.existsSync(appPath) ? appPath : path.dirname(appPath)
  if (!fs.existsSync(dir)) {
    return null
  }
  const candidates = fs.readdirSync(dir).filter((f) => /^app\.[a-f0-9]+\.js$/.test(f))
  return candidates.length ? path.join(dir, candidates.sort().pop()) : null
}

function analyzeHostApp(appJs) {
  const hasPluginPatch = appJs.includes('pluginBeingLoaded')
  const hasNextInMap = /nxt:"[a-f0-9]+"/.test(appJs)
  const mapMatch = appJs.match(
    /GCodeViewer:"[^"]+",HeightMap:"[^"]+",InputShaping:"[^"]+"([^}]+)\}/
  )
  return { hasPluginPatch, hasNextInMap, mapSnippet: mapMatch ? mapMatch[1] : '' }
}

function simulateChunkUrl(appJs, pluginId, dwcFiles) {
  const hasPatch = appJs.includes('pluginBeingLoaded.dwcFiles.find')
  if (!hasPatch) {
    return { mode: 'no-patch', url: null, risk: 'CRITICAL — host DWC too old for third-party plugin chunks' }
  }
  if (dwcFiles && dwcFiles.length > 0) {
    const jsFile = dwcFiles.find((f) => f.includes(pluginId) && /\.js$/.test(f))
    if (jsFile) {
      return { mode: 'dwcFiles', url: jsFile, risk: null }
    }
    const mapHit = appJs.match(new RegExp(`${pluginId}:"([a-f0-9]+)"`))
    const fallback = mapHit ? `js/${pluginId}.${mapHit[1]}.js` : `js/${pluginId}.undefined.js`
    return {
      mode: 'dwcFiles-miss',
      url: fallback,
      risk: `CRITICAL — plugin dwcFiles has no .js containing "${pluginId}"; webpack may request "${fallback}"`
    }
  }
  const mapHit = appJs.match(new RegExp(`${pluginId}:"([a-f0-9]+)"`))
  if (mapHit) {
    return { mode: 'baked-map', url: `js/${pluginId}.${mapHit[1]}.js`, risk: null }
  }
  return {
    mode: 'undefined-map',
    url: `js/${pluginId}.undefined.js`,
    risk: `CRITICAL — stock DWC has no "${pluginId}" chunk hash; load only works via plugin.dwcFiles on the plugin object`
  }
}

function main() {
  const chunkPath = process.argv[2]
  const appArg = process.argv[3] || path.join(__dirname, '../../DuetWebControl/dist/js/app.js')

  if (!chunkPath) {
    console.error('usage: node dist/diagnose-plugin-chunk.mjs <nxt.js|zip> [host-app.js]')
    process.exit(1)
  }

  let chunkJs
  let zipJsName = null
  let pluginDwcVersion = null
  if (chunkPath.endsWith('.zip')) {
    try {
      pluginDwcVersion = JSON.parse(
        execSync(`unzip -p "${chunkPath}" plugin.json`, { encoding: 'utf8' })
      ).dwcVersion
      console.log(`plugin.json dwcVersion: ${pluginDwcVersion}`)
      if (pluginDwcVersion && /^\d+\.\d+$/.test(pluginDwcVersion)) {
        console.log('WARN: major.minor only (old auto-major ZIP) — rebuild with dwcVersion "auto"')
      } else if (pluginDwcVersion && /^\d+\.\d+\.\d+/.test(pluginDwcVersion)) {
        console.log('Host DWC must match this exact version (DWC rejects load before chunk runs).')
      }
    } catch {
      /* plugin.json optional for raw .js input */
    }
    const z = readChunkFromZip(chunkPath)
    chunkJs = z.js.toString('utf8')
    zipJsName = z.member.replace(/^dwc\//, '')
  } else {
    chunkJs = fs.readFileSync(chunkPath, 'utf8')
  }

  const keys = new Set([...chunkJs.matchAll(/"(\.\/[^"]+)":function/g)].map((m) => m[1]))
  const allReqs = [...chunkJs.matchAll(/[a-z]\("(\.\/[^"]+)"\)/g)].map((m) => m[1])
  const hostOnly = [...new Set(allReqs.filter((r) => !keys.has(r) && !r.includes('core-js')))].sort()

  const dwcApi = ['./src/store/index.ts', './src/routes/index.ts', './src/i18n/index.ts']
  const vueVuetify = hostOnly.filter((p) => p.includes('node_modules'))

  console.log('\n=== 1) Chunk shape ===\n')
  console.log(`Modules inside nxt chunk: ${keys.size}`)
  console.log(`Modules expected from HOST app.js: ${hostOnly.length}`)
  console.log(`  DWC APIs: ${dwcApi.filter((p) => hostOnly.includes(p)).length}/3`)
  console.log(`  Vue/Vuetify/loader: ${vueVuetify.length}`)
  console.log(`Entry: ${keys.has('./src/plugins/nxt/index.js') ? 'index.js → index-ts.ts' : 'MISSING index.js'}`)

  const appFile = resolveAppJs(appArg)
  let exitCode = 0

  if (appFile) {
    const appJs = fs.readFileSync(appFile, 'utf8')
    const hostInfo = analyzeHostApp(appJs)
    const missing = hostOnly.filter((p) => !appJs.includes(`"${p}":`))

    console.log('\n=== 2) Host app.js compatibility ===\n')
    console.log(`File: ${appFile}`)
    console.log(`pluginBeingLoaded patch: ${hostInfo.hasPluginPatch ? 'yes' : 'NO'}`)
    console.log(`nxt baked into app chunk map: ${hostInfo.hasNextInMap ? 'yes (from a combined plugin+DWC build)' : 'no (stock DWC)'}`)
    console.log(`Host provides all ${hostOnly.length} required modules: ${missing.length === 0 ? 'yes' : 'NO'}`)

    if (missing.length > 0) {
      console.log('\nMissing modules (chunk will throw .call when requiring these):')
      missing.forEach((p) => console.log(`  ${p}`))
      exitCode = 2
    }

    const dwcFiles = zipJsName ? [zipJsName] : ['js/nxt.<hash>.js']
    const urlSim = simulateChunkUrl(appJs, 'nxt', dwcFiles)
    console.log('\n=== 3) How DWC resolves the nxt script URL ===\n')
    console.log(`Mode: ${urlSim.mode}`)
    console.log(`Resolved URL: ${urlSim.url ?? '(none)'}`)
    if (urlSim.risk) {
      console.log(`Risk: ${urlSim.risk}`)
      exitCode = 2
    }

    const badUrl = simulateChunkUrl(appJs, 'nxt', [])
    if (badUrl.url && badUrl.url.includes('undefined')) {
      console.log('\nIf plugin.dwcFiles is empty when loading:')
      console.log(`  webpack would request: ${badUrl.url}`)
      console.log('  → script fails → often reported as .call undefined')
    }
  } else {
    console.log(`\n=== 2) Host check skipped ===\n(no file at ${appArg})`)
    console.log('Save the printer\'s dwc/js/app.*.js from DevTools → Network and re-run.')
  }

  console.log('\n=== 4) Load sequence (what actually runs) ===\n')
  console.log(`1. Settings → Start sets window.pluginBeingLoaded = plugin manifest`)
  console.log(`2. __webpack_require__.e("nxt") fetches JS (must match dwcFiles, not a stale hash)`)
  console.log(`3. Chunk runs; first host requires: ${hostOnly.slice(0, 3).join(', ')}…`)
  console.log(`4. __webpack_require__("./src/plugins/nxt/index.js") must find module in chunk`)

  console.log('\n=== 5) Common causes of .call undefined ===\n')
  if (pluginDwcVersion) {
    console.log(`ZIP dwcVersion: ${pluginDwcVersion} — host must match exactly (not just same major.minor)`)
  }
  console.log('A) Host app.js mismatch — ZIP built on one DWC patch, printer serves another (e.g. 3.6.2 vs 3.7.x)')
  console.log('B) dwcFiles empty / wrong — plugin object missing js/nxt.*.js → js/nxt.undefined.js')
  console.log('C) nxt.*.js 404 — hash in dwcFiles does not exist under www (reinstall ZIP)')
  console.log('D) Stale browser cache — old app.*.js + new nxt.*.js')
  console.log('E) npm run dev — external ZIP cannot load; use ./dist/setup-dwc-dev-symlink.sh')
  console.log('F) Start before install — enabling nxt without machine plugin entry (different error usually)')

  console.log('\n--- All host dependencies ---')
  hostOnly.forEach((p) => console.log(`  ${p}`))

  process.exit(exitCode)
}

main()
