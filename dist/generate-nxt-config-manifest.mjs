#!/usr/bin/env node
/**
 * Scan macros/nxt-config/ and emit ui/src/generated/nxtConfigManifest.json
 * Usage: node dist/generate-nxt-config-manifest.mjs [repo-root]
 */
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const root = process.argv[2] ? path.resolve(process.argv[2]) : path.join(__dirname, '..')
const configRoot = path.join(root, 'macros', 'nxt-config')
const outPath = path.join(root, 'ui', 'src', 'generated', 'nxtConfigManifest.json')

const BOARD_TITLE_OVERRIDE = {
  cdy3_f4: 'Fly CDYv3',
  scylla1_0_h723: 'Scylla v1.0'
}

function readOverviewTitle(platformDir) {
  const p = path.join(platformDir, 'OVERVIEW.txt')
  if (!fs.existsSync(p)) {
    return null
  }
  const line = fs.readFileSync(p, 'utf8').split(/\r?\n/).find((l) => l.trim().length > 0)
  return line ? line.trim() : null
}

function readSysDeploy(platformDir) {
  const manifestPath = path.join(platformDir, 'common', 'sys-deploy-manifest.txt')
  if (!fs.existsSync(manifestPath)) {
    return { files: [], contents: {} }
  }
  const files = fs
    .readFileSync(manifestPath, 'utf8')
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l.length > 0 && !l.startsWith(';'))
  const contents = {}
  for (const name of files) {
    const fp = path.join(platformDir, 'common', name)
    if (fs.existsSync(fp)) {
      contents[name] = fs.readFileSync(fp, 'utf8')
    }
  }
  return { files, contents }
}

function findBoardEntries(platformDir) {
  const boardsDir = path.join(platformDir, 'boards')
  if (!fs.existsSync(boardsDir)) {
    return []
  }
  const entries = []
  function walk(relDir) {
    const abs = path.join(boardsDir, relDir)
    for (const name of fs.readdirSync(abs)) {
      const rel = relDir ? `${relDir}/${name}` : name
      const full = path.join(abs, name)
      if (fs.statSync(full).isDirectory()) {
        walk(rel)
      } else if (name === 'entry.g') {
        const relPath = rel.replace(/\/entry\.g$/, '').replace(/\\/g, '/')
        const parts = relPath.split('/')
        const shortName = parts[0]
        const variant =
          parts.length >= 2 && parts[1].startsWith('motor-') ? parts[1].replace('motor-', '') : null
        const titleBase = BOARD_TITLE_OVERRIDE[shortName] ?? shortName
        const title = variant ? `${titleBase} (${variant} V motor)` : titleBase
        entries.push({
          relPath,
          shortName,
          variant,
          title,
          entryPath: `nxt/config/${path.basename(platformDir)}/boards/${relPath}/entry.g`
        })
      }
    }
  }
  walk('')
  return entries
}

function scanPlatform(platformId) {
  const platformDir = path.join(configRoot, platformId)
  if (!fs.statSync(platformDir).isDirectory()) {
    return null
  }
  const deploy = readSysDeploy(platformDir)
  const boards = findBoardEntries(platformDir)
  const hasCommonDeploy = deploy.files.length > 0
  if (!hasCommonDeploy && boards.length === 0) {
    return null
  }
  return {
    id: platformId,
    title: readOverviewTitle(platformDir) ?? platformId,
    hasCommonDeploy,
    sysDeployFiles: deploy.files,
    sysDeployContents: deploy.contents,
    boards
  }
}

if (!fs.existsSync(configRoot)) {
  console.error('missing', configRoot)
  process.exit(1)
}

const platforms = []
for (const name of fs.readdirSync(configRoot)) {
  const full = path.join(configRoot, name)
  if (!fs.statSync(full).isDirectory()) {
    continue
  }
  const p = scanPlatform(name)
  if (p) {
    platforms.push(p)
  }
}

platforms.sort((a, b) => a.id.localeCompare(b.id))

for (const plat of platforms) {
  for (const b of plat.boards) {
    const rel = path.join(configRoot, plat.id, 'boards', b.relPath, 'entry.g')
    if (!fs.existsSync(rel)) {
      console.error(`error: manifest entry missing on disk: ${b.entryPath} (${rel})`)
      process.exit(1)
    }
  }
  for (const name of plat.sysDeployFiles) {
    const rel = path.join(configRoot, plat.id, 'common', name)
    if (!fs.existsSync(rel)) {
      console.error(`error: sys deploy file missing: ${plat.id}/common/${name}`)
      process.exit(1)
    }
  }
}

const indexLines = ['# platform\tshortName\tmotorVoltage\tentryPath']
for (const plat of platforms) {
  for (const b of plat.boards) {
    const volt = b.variant ? b.variant.replace(/v$/, '') : ''
    indexLines.push(`${plat.id}\t${b.shortName}\t${volt}\t${b.entryPath}`)
  }
}
const indexPath = path.join(configRoot, 'board-pack-index.txt')
fs.writeFileSync(indexPath, indexLines.join('\n') + '\n')

const out = {
  generatedAt: new Date().toISOString(),
  platforms
}

fs.mkdirSync(path.dirname(outPath), { recursive: true })
fs.writeFileSync(outPath, JSON.stringify(out, null, 2) + '\n')
console.log(`Wrote ${outPath} (${platforms.length} platforms)`)
console.log(`Wrote ${indexPath}`)
