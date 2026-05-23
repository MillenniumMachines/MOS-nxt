#!/usr/bin/env node
/**
 * Scan macros/nxt-config/board/ and macros/nxt-config/machine/
 * Emit ui/src/generated/nxtConfigManifest.json and board-pack-index.txt
 * Usage: node dist/generate-nxt-config-manifest.mjs [repo-root]
 */
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const root = process.argv[2] ? path.resolve(process.argv[2]) : path.join(__dirname, '..')
const configRoot = path.join(root, 'macros', 'nxt-config')
const boardRoot = path.join(configRoot, 'board')
const machineRoot = path.join(configRoot, 'machine')
const outPath = path.join(root, 'ui', 'src', 'generated', 'nxtConfigManifest.json')

const BOARD_TITLE_OVERRIDE = {
  cdy3_f4: 'Fly CDYv3',
  scylla1_0_h723: 'Scylla v1.0'
}

function readOverviewTitle(dir) {
  const p = path.join(dir, 'OVERVIEW.txt')
  if (!fs.existsSync(p)) {
    return null
  }
  const line = fs.readFileSync(p, 'utf8').split(/\r?\n/).find((l) => l.trim().length > 0)
  return line ? line.trim() : null
}

function readSysDeploy(machineDir) {
  const manifestPath = path.join(machineDir, 'sys-deploy-manifest.txt')
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
    const fp = path.join(machineDir, name)
    if (fs.existsSync(fp)) {
      contents[name] = fs.readFileSync(fp, 'utf8')
    }
  }
  return { files, contents }
}

function readPinmap(boardDir) {
  const p = path.join(boardDir, 'pinmap.json')
  if (!fs.existsSync(p)) {
    return null
  }
  return JSON.parse(fs.readFileSync(p, 'utf8'))
}

function findBoardEntries(boardDir, shortName) {
  const entries = []
  function walk(sub) {
    const dir = sub ? path.join(boardDir, sub) : boardDir
    for (const name of fs.readdirSync(dir)) {
      const full = path.join(dir, name)
      if (fs.statSync(full).isDirectory()) {
        walk(sub ? `${sub}/${name}` : name)
      } else if (name === 'entry.g') {
        const entryRel = sub ? `${sub}/entry.g` : 'entry.g'
        const variant =
          sub === 'motor-24v' ? '24v' : sub === 'motor-48v' ? '48v' : null
        const titleBase = BOARD_TITLE_OVERRIDE[shortName] ?? shortName
        const title = variant ? `${titleBase} (${variant} V motor)` : titleBase
        entries.push({
          shortName,
          variant,
          title,
          entryPath: `nxt-config/board/${shortName}/${entryRel}`.replace(/\\/g, '/')
        })
      }
    }
  }
  walk('')
  return entries
}

function scanBoard(shortName) {
  const boardDir = path.join(boardRoot, shortName)
  if (!fs.statSync(boardDir).isDirectory()) {
    return null
  }
  const entries = findBoardEntries(boardDir, shortName)
  if (entries.length === 0) {
    return null
  }
  const hasMotorVariant = entries.some((e) => e.variant != null)
  return {
    shortName,
    title: BOARD_TITLE_OVERRIDE[shortName] ?? shortName,
    variant: hasMotorVariant ? 'motor-24v-48v' : 'single',
    entries,
    pinmap: readPinmap(boardDir)
  }
}

function scanMachine(machineId) {
  const machineDir = path.join(machineRoot, machineId)
  if (!fs.statSync(machineDir).isDirectory()) {
    return null
  }
  const deploy = readSysDeploy(machineDir)
  const hasEntry = fs.existsSync(path.join(machineDir, 'entry.g'))
  const overview = readOverviewTitle(machineDir)
  if (!hasEntry && deploy.files.length === 0 && !overview) {
    return null
  }
  return {
    id: machineId,
    title: overview ?? machineId,
    hasCommonDeploy: deploy.files.length > 0,
    sysDeployFiles: deploy.files,
    sysDeployContents: deploy.contents,
    machineEntryPath: hasEntry ? `nxt-config/machine/${machineId}/entry.g` : null
  }
}

if (!fs.existsSync(configRoot)) {
  console.error('missing', configRoot)
  process.exit(1)
}

const boards = []
if (fs.existsSync(boardRoot)) {
  for (const name of fs.readdirSync(boardRoot)) {
    const full = path.join(boardRoot, name)
    if (!fs.statSync(full).isDirectory()) {
      continue
    }
    const b = scanBoard(name)
    if (b) {
      boards.push(b)
    }
  }
}
boards.sort((a, b) => a.shortName.localeCompare(b.shortName))

const machines = []
if (fs.existsSync(machineRoot)) {
  for (const name of fs.readdirSync(machineRoot)) {
    const full = path.join(machineRoot, name)
    if (!fs.statSync(full).isDirectory()) {
      continue
    }
    const m = scanMachine(name)
    if (m) {
      machines.push(m)
    }
  }
}
machines.sort((a, b) => a.id.localeCompare(b.id))

/** Flat board entry list for UI/firmware path helpers (replaces per-platform boards). */
const boardEntries = []
for (const b of boards) {
  for (const e of b.entries) {
    boardEntries.push({
      shortName: e.shortName,
      variant: e.variant,
      title: e.title,
      entryPath: e.entryPath.replace(/\/\/+/, '/')
    })
  }
}

function sdPathToRepoRel(sdPath) {
  return sdPath.replace(/^nxt-config\//, '').replace(/^nxt\/config\//, '')
}

for (const e of boardEntries) {
  const rel = path.join(configRoot, ...sdPathToRepoRel(e.entryPath).split('/'))
  if (!fs.existsSync(rel)) {
    console.error(`error: board entry missing on disk: ${e.entryPath} (${rel})`)
    process.exit(1)
  }
}

for (const m of machines) {
  for (const name of m.sysDeployFiles) {
    const rel = path.join(machineRoot, m.id, name)
    if (!fs.existsSync(rel)) {
      console.error(`error: sys deploy file missing: machine/${m.id}/${name}`)
      process.exit(1)
    }
  }
  if (m.machineEntryPath) {
    const rel = path.join(configRoot, ...sdPathToRepoRel(m.machineEntryPath).split('/'))
    if (!fs.existsSync(rel)) {
      console.error(`error: machine entry missing: ${m.machineEntryPath}`)
      process.exit(1)
    }
  }
}

const indexLines = ['# machineId\tboardShortName\tmotorVoltage\tboardEntryPath\tmachineEntryPath']
for (const m of machines) {
  const machineEntry = m.machineEntryPath ?? ''
  for (const e of boardEntries) {
    const volt = e.variant ? `${e.variant}` : ''
    indexLines.push(`${m.id}\t${e.shortName}\t${volt}\t${e.entryPath}\t${machineEntry}`)
  }
}
const indexPath = path.join(configRoot, 'board-pack-index.txt')
fs.writeFileSync(indexPath, indexLines.join('\n') + '\n')

const out = {
  generatedAt: new Date().toISOString(),
  boards,
  boardEntries,
  machines,
  /** @deprecated Use machines — full machine row + boardEntries for older imports */
  platforms: machines.map((m) => ({
    ...m,
    boards: boardEntries
  }))
}

fs.mkdirSync(path.dirname(outPath), { recursive: true })
fs.writeFileSync(outPath, JSON.stringify(out, null, 2) + '\n')
console.log(`Wrote ${outPath} (${boards.length} boards, ${machines.length} machines)`)
console.log(`Wrote ${indexPath}`)
