/**
 * Golden regression tests for toolpath module split.
 * Run: npx tsx ui/scripts/toolpath-split-tests.ts
 * Update golden: npx tsx ui/scripts/toolpath-split-tests.ts --update
 */
import assert from 'node:assert/strict'
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

import type { ToolpathGenerationParams } from '../src/utils/toolpathTypes'
import {
  calculateOriginOffset,
  calculateZLevels,
  generateRectilinearPattern,
  generateSpiralPattern,
  generateZigzagPattern
} from '../src/utils/toolpathPatterns'
import {
  calculateToolpathStatistics,
  generateToolpath
} from '../src/utils/toolpath'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const goldenPath = join(root, 'scripts/fixtures/toolpath-golden.json')

const baseCutting = {
  toolRadius: 3,
  stepover: 50,
  stepdown: 1,
  zOffset: 0,
  totalDepth: 2,
  safeZHeight: 5,
  clearStockExit: false,
  finishingPass: false,
  finishingPassHeight: 0.2,
  finishingPassOffset: 0
}

const baseFeeds = { xy: 1200, z: 300, spindleSpeed: 12000 }

export const fixtures: Array<{ id: string; params: ToolpathGenerationParams }> = [
  {
    id: 'rect_rectilinear',
    params: {
      stock: { shape: 'rectangular', x: 80, y: 60, z: 10, originPosition: 'front-left' },
      cutting: baseCutting,
      pattern: { type: 'rectilinear', angle: 0, millingDirection: 'climb' },
      feeds: baseFeeds
    }
  },
  {
    id: 'rect_zigzag_finish',
    params: {
      stock: { shape: 'rectangular', x: 50, y: 40, z: 8, originPosition: 'center' },
      cutting: { ...baseCutting, finishingPass: true, clearStockExit: true },
      pattern: { type: 'zigzag', angle: 45, millingDirection: 'conventional' },
      feeds: baseFeeds
    }
  },
  {
    id: 'circle_spiral',
    params: {
      stock: { shape: 'circular', diameter: 70, z: 12, originPosition: 'front-left' },
      cutting: { ...baseCutting, stepover: 40 },
      pattern: {
        type: 'spiral',
        angle: 0,
        millingDirection: 'climb',
        spiralSegmentsPerRevolution: 36,
        spiralDirection: 'outside-in'
      },
      feeds: baseFeeds
    }
  }
]

function round4(n: number): number {
  return Math.round(n * 10000) / 10000
}

function summarizePoint(p: { x: number; y: number; z: number; type: string }) {
  return { x: round4(p.x), y: round4(p.y), z: round4(p.z), type: p.type }
}

export function buildSnapshot(id: string, params: ToolpathGenerationParams) {
  const stockX = params.stock.shape === 'rectangular' ? params.stock.x! : params.stock.diameter!
  const stockY = params.stock.shape === 'rectangular' ? params.stock.y! : params.stock.diameter!
  const origin = calculateOriginOffset(stockX, stockY, params.stock.originPosition)
  const zLevels = calculateZLevels(params.cutting).map((l) => ({
    depth: round4(l.depth),
    isFinishing: l.isFinishing
  }))
  const toolpath = generateToolpath(params)
  const stats = calculateToolpathStatistics(toolpath, params.cutting)
  const levelCounts = toolpath.map((level) => level.length)
  const firstLast = toolpath.map((level) => {
    if (!level.length) {
      return { first: null, last: null }
    }
    return {
      first: summarizePoint(level[0]),
      last: summarizePoint(level[level.length - 1])
    }
  })
  return {
    id,
    origin,
    zLevels,
    levelCounts,
    firstLast,
    stats: {
      totalDistance: stats.totalDistance,
      estimatedTime: stats.estimatedTime,
      roughingPasses: stats.roughingPasses,
      finishingPass: stats.finishingPass
    }
  }
}

export function buildAllSnapshots() {
  return fixtures.map((f) => buildSnapshot(f.id, f.params))
}

/** Direct pattern imports must match generateToolpath for each fixture. */
export function assertPatternParity() {
  for (const { params } of fixtures) {
    let direct: ReturnType<typeof generateRectilinearPattern>
    switch (params.pattern.type) {
      case 'rectilinear':
        direct = generateRectilinearPattern(params)
        break
      case 'zigzag':
        direct = generateZigzagPattern(params)
        break
      case 'spiral':
        direct = generateSpiralPattern(params)
        break
      default:
        throw new Error(`unknown pattern ${params.pattern.type}`)
    }
    const viaRouter = generateToolpath(params)
    assert.equal(direct.length, viaRouter.length)
    for (let i = 0; i < direct.length; i++) {
      assert.equal(direct[i].length, viaRouter[i].length)
    }
  }
}

function main() {
  const update = process.argv.includes('--update')
  const snapshots = buildAllSnapshots()
  assertPatternParity()

  if (update) {
    mkdirSync(dirname(goldenPath), { recursive: true })
    writeFileSync(goldenPath, `${JSON.stringify(snapshots, null, 2)}\n`, 'utf8')
    console.log(`Wrote ${goldenPath}`)
    return
  }

  const golden = JSON.parse(readGolden())
  assert.equal(snapshots.length, golden.length)
  for (let i = 0; i < snapshots.length; i++) {
    assert.deepEqual(snapshots[i], golden[i], `fixture ${snapshots[i].id}`)
  }
  console.log(`toolpath-split-tests: OK (${snapshots.length} fixtures)`)
}

function readGolden(): string {
  try {
    return readFileSync(goldenPath, 'utf8')
  } catch {
    throw new Error(`Missing ${goldenPath} — run: npx tsx ui/scripts/toolpath-split-tests.ts --update`)
  }
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  main()
}
