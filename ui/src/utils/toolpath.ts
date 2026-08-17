/**
 * Toolpath generation (public entry).
 * Types and pattern algorithms: toolpathTypes.ts, toolpathPatterns.ts
 */

export * from './toolpathTypes'
export * from './toolpathPatterns'

import {
  generateRectilinearPattern,
  generateSpiralPattern,
  generateZigzagPattern,
  calculateZLevels
} from './toolpathPatterns'
import type { CuttingParameters, ToolpathGenerationParams, ToolpathPoint } from './toolpathTypes'

/**
 * Generate complete toolpath based on parameters
 */
export function generateToolpath(
  params: ToolpathGenerationParams
): ToolpathPoint[][] {
  switch (params.pattern.type) {
    case 'rectilinear':
      return generateRectilinearPattern(params)
    case 'zigzag':
      return generateZigzagPattern(params)
    case 'spiral':
      return generateSpiralPattern(params)
    default:
      throw new Error(`Unknown pattern type: ${(params.pattern as { type: string }).type}`)
  }
}

/**
 * Calculate toolpath statistics
 */
export function calculateToolpathStatistics(
  toolpath: ToolpathPoint[][],
  cutting: CuttingParameters
): {
  totalDistance: number
  estimatedTime: number
  materialRemoved: number
  roughingPasses: number
  finishingPass: boolean
} {
  let totalDistance = 0
  let estimatedTimeSeconds = 0

  for (const level of toolpath) {
    for (let i = 1; i < level.length; i++) {
      const prev = level[i - 1]
      const curr = level[i]

      const dx = curr.x - prev.x
      const dy = curr.y - prev.y
      const dz = curr.z - prev.z
      const distance = Math.sqrt(dx * dx + dy * dy + dz * dz)

      totalDistance += distance

      if (curr.feedRate > 0) {
        estimatedTimeSeconds += (distance / curr.feedRate) * 60
      }
    }
  }

  const zLevels = calculateZLevels(cutting)
  const roughingPasses = zLevels.filter((l) => !l.isFinishing).length
  const finishingPass = zLevels.some((l) => l.isFinishing)

  const materialRemoved = 0

  return {
    totalDistance: Math.round(totalDistance * 10) / 10,
    estimatedTime: Math.round(estimatedTimeSeconds),
    materialRemoved,
    roughingPasses,
    finishingPass
  }
}
