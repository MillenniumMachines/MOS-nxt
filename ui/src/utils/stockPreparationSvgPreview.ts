/**
 * 2D SVG plan-view preview for Stock Preparation toolpaths.
 * Maps toolpath coordinates to SVG with +Y upward on screen (matches typical CNC plan view).
 */

import type { ToolpathGenerationParams, ToolpathPoint } from './toolpath'
import { calculateOriginOffset } from './toolpath'

export interface StockPreparationSvgPreview {
  viewBox: string
  /** Stroke width in viewBox (mm) units — scales with zoom */
  strokeStock: number
  strokeRapid: number
  strokeCut: number
  stockPathD: string
  rapidPathD: string
  cutPathD: string
  hasToolpath: boolean
}

function bump(
  minX: number,
  minY: number,
  maxX: number,
  maxY: number,
  x: number,
  y: number
): { minX: number; minY: number; maxX: number; maxY: number } {
  return {
    minX: Math.min(minX, x),
    minY: Math.min(minY, y),
    maxX: Math.max(maxX, x),
    maxY: Math.max(maxY, y)
  }
}

/**
 * Build paths for a top-down SVG preview of stock outline and toolpath.
 */
export function buildStockPreparationSvgPreview(
  toolpathLevels: ToolpathPoint[][],
  params: ToolpathGenerationParams
): StockPreparationSvgPreview {
  const { stock } = params
  let minX = Infinity
  let minY = Infinity
  let maxX = -Infinity
  let maxY = -Infinity

  if (stock.shape === 'rectangular') {
    const sx = stock.x || 0
    const sy = stock.y || 0
    const o = calculateOriginOffset(sx, sy, stock.originPosition)
    ;({ minX, minY, maxX, maxY } = bump(minX, minY, maxX, maxY, o.x, o.y))
    ;({ minX, minY, maxX, maxY } = bump(minX, minY, maxX, maxY, o.x + sx, o.y))
    ;({ minX, minY, maxX, maxY } = bump(minX, minY, maxX, maxY, o.x + sx, o.y + sy))
    ;({ minX, minY, maxX, maxY } = bump(minX, minY, maxX, maxY, o.x, o.y + sy))
  } else {
    const r = (stock.diameter || 0) / 2
    ;({ minX, minY, maxX, maxY } = bump(minX, minY, maxX, maxY, -r, -r))
    ;({ minX, minY, maxX, maxY } = bump(minX, minY, maxX, maxY, r, r))
  }

  let hasToolpath = false
  for (const level of toolpathLevels) {
    for (const p of level) {
      ;({ minX, minY, maxX, maxY } = bump(minX, minY, maxX, maxY, p.x, p.y))
      hasToolpath = true
    }
  }

  if (!Number.isFinite(minX) || minX === Infinity) {
    return {
      viewBox: '0 0 100 100',
      strokeStock: 0.5,
      strokeRapid: 0.35,
      strokeCut: 0.5,
      stockPathD: '',
      rapidPathD: '',
      cutPathD: '',
      hasToolpath: false
    }
  }

  const span = Math.max(maxX - minX, maxY - minY, 1)
  const pad = span * 0.08
  const vbMinX = minX - pad
  const vbMinY = minY - pad
  const vbW = maxX - minX + 2 * pad
  const vbH = maxY - minY + 2 * pad
  const vbMaxY = maxY + pad

  const xy = (x: number, y: number) =>
    `${(x - vbMinX).toFixed(4)},${(vbMaxY - y).toFixed(4)}`

  let stockPathD = ''
  if (stock.shape === 'rectangular') {
    const sx = stock.x || 0
    const sy = stock.y || 0
    const o = calculateOriginOffset(sx, sy, stock.originPosition)
    const x0 = o.x
    const y0 = o.y
    stockPathD = `M ${xy(x0, y0)} L ${xy(x0 + sx, y0)} L ${xy(x0 + sx, y0 + sy)} L ${xy(x0, y0 + sy)} Z`
  } else {
    const r = (stock.diameter || 0) / 2
    const n = 64
    const pts: string[] = []
    for (let i = 0; i <= n; i++) {
      const a = (i / n) * Math.PI * 2
      const x = Math.cos(a) * r
      const y = Math.sin(a) * r
      pts.push(`${i === 0 ? 'M' : 'L'} ${xy(x, y)}`)
    }
    stockPathD = `${pts.join(' ')} Z`
  }

  const rapidSegs: string[] = []
  const cutSegs: string[] = []

  for (const level of toolpathLevels) {
    if (level.length < 2) {
      continue
    }
    for (let i = 0; i < level.length - 1; i++) {
      const a = level[i]
      const b = level[i + 1]
      const seg = `M ${xy(a.x, a.y)} L ${xy(b.x, b.y)}`
      if (b.type === 'rapid') {
        rapidSegs.push(seg)
      } else {
        cutSegs.push(seg)
      }
    }
  }

  const strokeBase = Math.max(vbW, vbH) * 0.004

  return {
    viewBox: `0 0 ${vbW.toFixed(4)} ${vbH.toFixed(4)}`,
    strokeStock: Math.max(strokeBase, 0.12),
    strokeRapid: Math.max(strokeBase * 0.85, 0.1),
    strokeCut: Math.max(strokeBase * 1.1, 0.14),
    stockPathD,
    rapidPathD: rapidSegs.join(' '),
    cutPathD: cutSegs.join(' '),
    hasToolpath
  }
}
