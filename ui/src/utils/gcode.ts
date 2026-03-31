/**
 * G-code Generation Utilities
 *
 * Generates G-code from toolpath data for stock preparation operations.
 * Includes safety features and proper header/footer structure.
 */

import { ToolpathPoint, ToolpathGenerationParams, calculateZLevels, calculateOriginOffset } from './toolpath'

/**
 * Generate stock metadata M-codes
 * These M-codes store stock dimensions in the object model for the G-code viewer
 * Format: M7500 K"key" V{values} - stores key-value pair in global.nxtMetadata
 * Values are passed as vectors for RRF compatibility
 */
function generateStockMetadata(params: ToolpathGenerationParams): string {
  const { stock, cutting } = params
  const lines: string[] = []

  lines.push('; Stock metadata for G-code viewer')

  if (stock.shape === 'rectangular') {
    // Cuboid stock: X, Y, Z dimensions as 3-element vector
    const x = formatNumber(stock.x || 0)
    const y = formatNumber(stock.y || 0)
    const z = formatNumber(stock.z || 20)
    lines.push(`M7500 K"stock_cuboid" V{${x},${y},${z}}`)
    // Provide origin offset so the viewer can position the stock correctly relative to WCS
    const off = calculateOriginOffset(stock.x || 0, stock.y || 0, stock.originPosition)
    const ox = formatNumber(off.x)
    const oy = formatNumber(off.y)
    lines.push(`M7500 K"stock_origin" V{${ox},${oy}}`)
  } else {
    // Cylindrical stock: Diameter, Z height as 2-element vector
    const d = formatNumber(stock.diameter || 0)
    const z = formatNumber(stock.z || 20)
    lines.push(`M7500 K"stock_cylinder" V{${d},${z}}`)
    // Provide origin offset (center) for consistency (circular stock is centered at origin)
    const ox = formatNumber(0)
    const oy = formatNumber(0)
    lines.push(`M7500 K"stock_origin" V{${ox},${oy}}`)
  }

  lines.push('')
  return lines.join('\n')
}

/**
 * Format a number for G-code output
 */
function formatNumber(value: number, decimals: number = 4): string {
  return value.toFixed(decimals)
}

/**
 * Generate G-code header
 */
function generateHeader(params: ToolpathGenerationParams, currentTool: number): string {
  const { stock, cutting, pattern, feeds } = params

  const lines: string[] = []

  lines.push('; NeXT Stock Preparation - Generated Facing Operation')

  if (stock.shape === 'rectangular') {
    lines.push(`; Stock: Rectangular ${formatNumber(stock.x || 0)}x${formatNumber(stock.y || 0)}mm`)
  } else {
    lines.push(`; Stock: Circular D${formatNumber(stock.diameter || 0)}mm`)
  }

  lines.push(`; Pattern: ${pattern.type} at ${pattern.angle}°`)
  lines.push(`; Tool: T${currentTool} R${formatNumber(cutting.toolRadius)}mm`)
  lines.push(`; Feed: XY=${formatNumber(feeds.xy, 0)} Z=${formatNumber(feeds.z, 0)} mm/min`)
  lines.push(`; Spindle: ${formatNumber(feeds.spindleSpeed, 0)} RPM`)
  lines.push('')
  lines.push('G21 ; Metric units')
  lines.push('G90 ; Absolute positioning')
  lines.push('G94 ; Feed rate per minute')
  lines.push('')

  return lines.join('\n')
}

/**
 * Generate G-code setup section
 */
function generateSetup(
  currentTool: number,
  spindleSpeed: number,
  workplace: number
): string {
  const lines: string[] = []

  lines.push('; Setup')
  lines.push(`G${53 + workplace} ; Use WCS ${workplace}`)
  lines.push(`T${currentTool} ; Confirm tool selection`)
  lines.push(`M3.9 S${formatNumber(spindleSpeed, 0)} ; Start spindle with safety wrapper`)
  lines.push('')

  return lines.join('\n')
}

/**
 * Generate positioning section
 */
function generatePositioning(
  firstPoint: ToolpathPoint,
  safeZ: number
): string {
  const lines: string[] = []

  lines.push('; Position to start')
  lines.push(`G0 Z${formatNumber(safeZ)} ; Move to safe height above stock top`)
  lines.push(`G0 X${formatNumber(firstPoint.x)} Y${formatNumber(firstPoint.y)} ; Rapid to start position`)
  lines.push('')

  return lines.join('\n')
}

/**
 * Generate cutting moves for a single Z level
 */
function generateCuttingMoves(
  points: ToolpathPoint[],
  levelIndex: number,
  isFinishing: boolean,
  safeZ: number,
  finishingOffset: number = 0
): string {
  if (points.length === 0) {
    return ''
  }

  const lines: string[] = []
  const firstPoint = points[0]

  const passType = isFinishing ? 'Finishing Pass' : `Roughing Z Level ${levelIndex + 1}`
  lines.push(`; ${passType}: ${formatNumber(firstPoint.z)}mm (Safe Z: ${formatNumber(safeZ)}mm)`)

  if (isFinishing && finishingOffset !== 0) {
    lines.push(`; Offset: ${formatNumber(finishingOffset)}mm`)
  }

  let lastCommandType: string | null = null
  let lastFeedRate: number | null = null

  let lastPrintedComment: string | null = null
  for (const point of points) {
    if (point.comment && point.comment !== lastPrintedComment) {
      lines.push(`; ${point.comment}`)
      lastPrintedComment = point.comment
    }
    let x = point.x
    let y = point.y

    // Apply finishing pass offset if applicable
    if (isFinishing && finishingOffset !== 0) {
      // Offset is applied radially from center - simplified for now
      x += finishingOffset
      y += finishingOffset
    }

    let currentCommand = ''
    let needsFeedRate = false

    if (point.type === 'rapid') {
      currentCommand = 'G0'
      // G0 doesn't use feed rate, but track command type change
      if (lastCommandType !== 'G0') {
        lastCommandType = 'G0'
        lastFeedRate = null  // Reset feed rate tracking on command type change
      }
      lines.push(`G0 X${formatNumber(x)} Y${formatNumber(y)} Z${formatNumber(point.z)}`)
    } else if (point.type === 'arc') {
      // Arc interpolation (G2 for CW, G3 for CCW)
      currentCommand = point.clockwise ? 'G2' : 'G3'
      const iParam = point.i !== undefined ? ` I${formatNumber(point.i)}` : ''
      const jParam = point.j !== undefined ? ` J${formatNumber(point.j)}` : ''

      // Only output feed rate if command type changed or feed rate changed
      let feedPart = ''
      if (lastCommandType !== currentCommand || lastFeedRate !== point.feedRate) {
        if (point.feedRate > 0) {
          feedPart = ` F${formatNumber(point.feedRate, 0)}`
          lastFeedRate = point.feedRate
        }
      }
      lastCommandType = currentCommand

      lines.push(`${currentCommand} X${formatNumber(x)} Y${formatNumber(y)} Z${formatNumber(point.z)}${iParam}${jParam}${feedPart}`)
    } else {
      // Linear interpolation (G1)
      currentCommand = 'G1'

      // Only output feed rate if command type changed or feed rate changed
      let feedPart = ''
      if (lastCommandType !== currentCommand || lastFeedRate !== point.feedRate) {
        if (point.feedRate > 0) {
          feedPart = ` F${formatNumber(point.feedRate, 0)}`
          lastFeedRate = point.feedRate
        }
      }
      lastCommandType = currentCommand

      lines.push(`G1 X${formatNumber(x)} Y${formatNumber(y)} Z${formatNumber(point.z)}${feedPart}`)
    }
  }

  lines.push('')

  return lines.join('\n')
}

/**
 * Generate cleanup section
 */
function generateCleanup(zOffset: number, safeZHeight: number): string {
  const lines: string[] = []

  lines.push('; Cleanup')
  lines.push(`G0 Z${formatNumber(zOffset + safeZHeight)} ; Final retract to safe height above stock top`)
  lines.push('M5.9 ; Stop spindle with safety wrapper')
  lines.push('G27 Z1 ; Park machine')
  lines.push('; Program ends automatically at end of file')

  return lines.join('\n')
}

/**
 * Generate complete G-code program
 */
export function generateGCode(
  toolpath: ToolpathPoint[][],
  params: ToolpathGenerationParams,
  currentTool: number = 0,
  workplace: number = 1
): string {
  const { cutting, feeds } = params
  const sections: string[] = []

  // Header
  sections.push(generateHeader(params, currentTool))

  // Stock metadata M-codes
  sections.push(generateStockMetadata(params))

  // Setup
  sections.push(generateSetup(currentTool, feeds.spindleSpeed, workplace))

  // Positioning (if we have toolpath)
  if (toolpath.length > 0 && toolpath[0].length > 0) {
    const firstPoint = toolpath[0][0]
    sections.push(generatePositioning(firstPoint, cutting.zOffset + cutting.safeZHeight))
  }

  // Cutting moves for each Z level
  const zLevels = calculateZLevels(cutting)

  for (let i = 0; i < toolpath.length; i++) {
    const levelPoints = toolpath[i]
    const zLevel = zLevels[i]

    if (levelPoints.length > 0) {
      const safeZ = zLevel.depth + cutting.safeZHeight
      const finishingOffset = zLevel.isFinishing ? cutting.finishingPassOffset : 0

      sections.push(
        generateCuttingMoves(
          levelPoints,
          i,
          zLevel.isFinishing,
          safeZ,
          finishingOffset
        )
      )
    }
  }

  // Cleanup
  sections.push(generateCleanup(cutting.zOffset, cutting.safeZHeight))

  return sections.join('\n')
}

/**
 * Validate G-code parameters
 */
export function validateGCodeParameters(params: ToolpathGenerationParams): string[] {
  const errors: string[] = []
  const { stock, cutting, feeds } = params

  // Tool radius validation
  if (cutting.toolRadius <= 0) {
    errors.push('Tool radius must be positive')
  }

  // Stock dimensions validation
  if (stock.shape === 'rectangular') {
    if (!stock.x || stock.x <= 0) {
      errors.push('Stock X dimension must be positive')
    }
    if (!stock.y || stock.y <= 0) {
      errors.push('Stock Y dimension must be positive')
    }
    if (stock.x && cutting.toolRadius >= stock.x / 2) {
      errors.push('Tool radius exceeds half of stock X dimension')
    }
    if (stock.y && cutting.toolRadius >= stock.y / 2) {
      errors.push('Tool radius exceeds half of stock Y dimension')
    }
  } else {
    if (!stock.diameter || stock.diameter <= 0) {
      errors.push('Stock diameter must be positive')
    }
    if (stock.diameter && cutting.toolRadius >= stock.diameter / 2) {
      errors.push('Tool radius exceeds stock radius')
    }
  }

  // Cutting parameters validation
  if (cutting.stepover <= 0 || cutting.stepover > 100) {
    errors.push('Stepover must be between 0 and 100%')
  }

  if (cutting.stepdown <= 0) {
    errors.push('Stepdown must be positive')
  }

  if (cutting.totalDepth <= 0) {
    errors.push('Total depth must be positive')
  }

  if (cutting.safeZHeight <= 0) {
    errors.push('Safe Z height must be positive')
  }

  // Finishing pass validation
  if (cutting.finishingPass) {
    if (cutting.finishingPassHeight <= 0) {
      errors.push('Finishing pass height must be positive')
    }
    if (cutting.finishingPassHeight >= cutting.totalDepth) {
      errors.push('Finishing pass height must be less than total depth')
    }
    if (cutting.finishingPassHeight >= cutting.stepdown) {
      errors.push('Finishing pass height should be less than stepdown value')
    }
  }

  // Feed rate validation
  if (feeds.xy <= 0) {
    errors.push('Horizontal feed rate must be positive')
  }

  if (feeds.z <= 0) {
    errors.push('Vertical feed rate must be positive')
  }

  if (feeds.spindleSpeed <= 0) {
    errors.push('Spindle speed must be positive')
  }

  return errors
}
