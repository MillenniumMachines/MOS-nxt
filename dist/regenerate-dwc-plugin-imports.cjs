#!/usr/bin/env node
/**
 * Regenerate DuetWebControl/src/plugins/imports.ts from directories under src/plugins/.
 * Run after build-plugin.sh so orphaned built-in entries (e.g. NeXT) are removed when
 * src/plugins/NeXT was only staged temporarily for the ZIP build.
 *
 * Usage: node dist/regenerate-dwc-plugin-imports.cjs [path-to-DuetWebControl]
 */
'use strict'

const fs = require('fs')
const path = require('path')
const assert = require('assert')

const dwcRoot = path.resolve(process.argv[2] || path.join(__dirname, '..', '..', 'DuetWebControl'))
const pluginsDir = path.join(dwcRoot, 'src', 'plugins')
const packageJsonPath = path.join(dwcRoot, 'package.json')

if (!fs.existsSync(pluginsDir)) {
  console.error(`error: missing ${pluginsDir}`)
  process.exit(1)
}

const packageInfo = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'))

let importsFile =
  '/**\n' +
  ' * DO NOT MODIFY THIS FILE! IT IS AUTO-GENERATED ON COMPILATION!\n' +
  '*/\n' +
  'import { initCollection } from "@duet3d/objectmodel";\n' +
  'import DwcPlugin from "./DwcPlugin";\n' +
  '\n' +
  'export default initCollection(DwcPlugin, [\n'

for (const dirent of fs.readdirSync(pluginsDir, { withFileTypes: true })) {
  if (!dirent.isDirectory()) {
    continue
  }
  const name = dirent.name
  if (fs.existsSync(path.join(pluginsDir, name, 'blacklist'))) {
    continue
  }

  let manifest
  try {
    manifest = JSON.parse(fs.readFileSync(path.join(pluginsDir, name, 'plugin.json'), 'utf8'))
  } catch (e) {
    throw new Error(`Failed to read plugin.json for plugin ${name}: ${e}`)
  }
  assert(name === manifest.id, `Plugin directory name ${name} must match manifest id ${manifest.id}`)

  let entryFile = null
  if (
    fs.existsSync(path.join(pluginsDir, name, 'index.js')) ||
    fs.existsSync(path.join(pluginsDir, name, 'index.ts'))
  ) {
    entryFile = `./${name}/index`
  } else if (process.env.NODE_ENV === 'production') {
    continue
  } else if (
    fs.existsSync(path.join(pluginsDir, name, 'dwc-src', 'index.js')) ||
    fs.existsSync(path.join(pluginsDir, name, 'dwc-src', 'index.ts'))
  ) {
    entryFile = `./${name}/dwc-src/index`
  } else if (
    fs.existsSync(path.join(pluginsDir, name, 'src', 'index.js')) ||
    fs.existsSync(path.join(pluginsDir, name, 'src', 'index.ts'))
  ) {
    entryFile = `./${name}/src/index`
  }
  assert(entryFile !== null, `Missing entry point in plugin ${name}`)

  const version =
    manifest.version === 'auto' ? packageInfo.version : manifest.version

  importsFile += '\t{\n'
  importsFile += `        id: "${manifest.id}",\n`
  importsFile += `        name: "${manifest.name}",\n`
  importsFile += `        author: "${manifest.author}",\n`
  importsFile += `        version: "${version}",\n`
  importsFile += '        loadDwcResources: () => import(\n'
  importsFile += `            /* webpackChunkName: "${name}" */\n`
  importsFile += `            "${entryFile}"\n`
  importsFile += '        )\n'
  importsFile += '    },\n'
}

importsFile += ']);\n'

const outPath = path.join(pluginsDir, 'imports.ts')
fs.writeFileSync(outPath, importsFile)
console.log(`regenerate-dwc-plugin-imports: wrote ${outPath}`)
