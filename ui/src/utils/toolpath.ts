/**
 * Toolpath Generation Utilities
 *
 * Implements algorithms for generating facing toolpaths for stock preparation.
 * Supports rectangular and circular stock with rectilinear, zigzag, and spiral patterns.
 */

// Types for toolpath generation

export interface ToolpathPoint {
  x: number
  y: number
  z: number
  feedRate: number
  type: 'rapid' | 'linear' | 'arc'
  // Optional text comment to include in generated G-code. Will be emitted as `; comment` line
  comment?: string
  // Arc parameters (only for type: 'arc')
  i?: number  // X offset to arc center
  j?: number  // Y offset to arc center
  clockwise?: boolean  // true for G2, false for G3
}

export interface StockGeometry {
  shape: 'rectangular' | 'circular'
  x?: number  // For rectangular
  y?: number  // For rectangular
  z?: number  // Height (used for both rectangular and circular in viewer)
  diameter?: number  // For circular
  originPosition: string
}

export interface CuttingParameters {
  toolRadius: number
  stepover: number  // Percentage or absolute mm
  stepdown: number
  zOffset: number
  totalDepth: number
  safeZHeight: number
  clearStockExit: boolean
  finishingPass: boolean
  finishingPassHeight: number
  finishingPassOffset: number
}

export interface FacingPattern {
  type: 'rectilinear' | 'zigzag' | 'spiral'
  angle: number
  millingDirection: 'climb' | 'conventional'
  spiralSegmentsPerRevolution?: number  // Number of line segments per full revolution for spiral patterns
  spiralDirection?: 'outside-in' | 'inside-out'
}

export interface FeedRates {
  xy: number
  z: number
  spindleSpeed: number
}

export interface ToolpathGenerationParams {
  stock: StockGeometry
  cutting: CuttingParameters
  pattern: FacingPattern
  feeds: FeedRates
}

/**
 * Calculate effective cutting width based on stepover
 * Stepover is expressed as a percentage of tool diameter.
 * For example, 25% stepover means tool centers are 25% of diameter apart.
 * Higher stepover = more distance between passes = faster but rougher cut.
 */
export function calculateEffectiveCuttingWidth(
  toolRadius: number,
  stepover: number
): number {
  const toolDiameter = toolRadius * 2
  return toolDiameter * (stepover / 100)
}

/**
 * Calculate number of passes needed
 */
export function calculateNumberOfPasses(
  stockDimension: number,
  effectiveCuttingWidth: number
): number {
  // Ensure we have at least one pass and handle edge cases
  if (effectiveCuttingWidth <= 0 || stockDimension <= 0) {
    return 1
  }
  // At 100% stepover (effectiveWidth = toolDiameter), we still need proper coverage
  const passes = Math.ceil(stockDimension / effectiveCuttingWidth)
  return Math.max(1, passes)
}

/**
 * Calculate tool-compensated boundaries
 */
export function calculateBoundaries(
  stockX: number,
  stockY: number,
  toolRadius: number,
  clearStockExit: boolean,
  originPosition: string = 'front-left'
): { xMin: number; xMax: number; yMin: number; yMax: number } {
  // Calculate origin offset from stock geometry
  const originOffset = calculateOriginOffset(stockX, stockY, originPosition)

  if (clearStockExit) {
    // Exit stock by full diameter + 1mm clearance
    const clearance = toolRadius * 2 + 1
    return {
      xMin: originOffset.x - clearance,
      xMax: originOffset.x + stockX + clearance,
      yMin: originOffset.y - clearance,
      yMax: originOffset.y + stockY + clearance
    }
  } else {
    // Standard tool center compensation
    return {
      xMin: originOffset.x + toolRadius,
      xMax: originOffset.x + stockX - toolRadius,
      yMin: originOffset.y + toolRadius,
      yMax: originOffset.y + stockY - toolRadius
    }
  }
}

/**
 * Calculate origin offset based on origin position
 * Returns the offset from the WCS origin (0,0) to the front-left corner of the stock
 */
export function calculateOriginOffset(
  stockX: number,
  stockY: number,
  originPosition: string
): { x: number; y: number } {
  // Parse origin position to determine X and Y position
  const [yPos, xPos] = originPosition.split('-')

  let xOffset = 0
  let yOffset = 0

  // Calculate X offset based on horizontal position
  switch (xPos) {
    case 'left':
      xOffset = 0
      break
    case 'center':
      xOffset = -stockX / 2
      break
    case 'right':
      xOffset = -stockX
      break
  }

  // Calculate Y offset based on vertical position
  switch (yPos) {
    case 'front':
      yOffset = 0
      break
    case 'center':
      yOffset = -stockY / 2
      break
    case 'back':
      yOffset = -stockY
      break
  }

  return { x: xOffset, y: yOffset }
}


/**
 * Apply pattern rotation around stock center
 */
export function rotatePoint(
  x: number,
  y: number,
  centerX: number,
  centerY: number,
  angleDegrees: number
): { x: number; y: number } {
  if (angleDegrees === 0) {
    return { x, y }
  }

  const angleRadians = (angleDegrees * Math.PI) / 180
  const cos = Math.cos(angleRadians)
  const sin = Math.sin(angleRadians)

  const translatedX = x - centerX
  const translatedY = y - centerY

  return {
    x: translatedX * cos - translatedY * sin + centerX,
    y: translatedX * sin + translatedY * cos + centerY
  }
}

/**
 * Clip point to circular boundary
 */
export function clipToCircle(
  x: number,
  y: number,
  centerX: number,
  centerY: number,
  radius: number
): { x: number; y: number } {
  const dx = x - centerX
  const dy = y - centerY
  const distance = Math.sqrt(dx * dx + dy * dy)

  if (distance <= radius) {
    return { x, y }
  }

  const angle = Math.atan2(dy, dx)
  return {
    x: centerX + radius * Math.cos(angle),
    y: centerY + radius * Math.sin(angle)
  }
}

/**
 * Clip line segment to circular boundary
 * Returns null if line is entirely outside circle
 * Returns clipped start and end points if line intersects circle
 */
export function clipLineToCircle(
  x1: number,
  y1: number,
  x2: number,
  y2: number,
  centerX: number,
  centerY: number,
  radius: number
): { x1: number; y1: number; x2: number; y2: number } | null {
  // Check if both points are inside
  const dx1 = x1 - centerX
  const dy1 = y1 - centerY
  const dist1 = Math.sqrt(dx1 * dx1 + dy1 * dy1)

  const dx2 = x2 - centerX
  const dy2 = y2 - centerY
  const dist2 = Math.sqrt(dx2 * dx2 + dy2 * dy2)

  const inside1 = dist1 <= radius
  const inside2 = dist2 <= radius

  // Both inside - no clipping needed
  if (inside1 && inside2) {
    return { x1, y1, x2, y2 }
  }

  // Both outside - check if line intersects circle
  // Line equation: P = P1 + t * (P2 - P1), where 0 <= t <= 1
  const dx = x2 - x1
  const dy = y2 - y1

  // Quadratic formula for circle-line intersection
  const a = dx * dx + dy * dy
  const b = 2 * (dx * dx1 + dy * dy1)
  const c = dx1 * dx1 + dy1 * dy1 - radius * radius

  const discriminant = b * b - 4 * a * c

  // No intersection
  if (discriminant < 0) {
    return null
  }

  // Calculate intersection points
  const sqrtDisc = Math.sqrt(discriminant)
  const t1 = (-b - sqrtDisc) / (2 * a)
  const t2 = (-b + sqrtDisc) / (2 * a)

  // Clip to line segment bounds [0, 1]
  const tMin = Math.max(0, Math.min(t1, t2))
  const tMax = Math.min(1, Math.max(t1, t2))

  // No intersection within segment
  if (tMin > tMax || tMax < 0 || tMin > 1) {
    return null
  }

  // Calculate clipped points
  let clippedX1 = x1
  let clippedY1 = y1
  let clippedX2 = x2
  let clippedY2 = y2

  if (!inside1) {
    clippedX1 = x1 + dx * tMin
    clippedY1 = y1 + dy * tMin
  }

  if (!inside2) {
    clippedX2 = x1 + dx * tMax
    clippedY2 = y1 + dy * tMax
  }

  return { x1: clippedX1, y1: clippedY1, x2: clippedX2, y2: clippedY2 }
}

/**
 * Clip a line segment to an axis-aligned rectangular boundary using Liang–Barsky algorithm.
 * Returns null if the line lies completely outside the rectangle.
 */
export function clipLineToRect(
  x1: number,
  y1: number,
  x2: number,
  y2: number,
  xMin: number,
  yMin: number,
  xMax: number,
  yMax: number
): { x1: number; y1: number; x2: number; y2: number } | null {
  let dx = x2 - x1
  let dy = y2 - y1
  let t0 = 0
  let t1 = 1
  const p = [-dx, dx, -dy, dy]
  const q = [x1 - xMin, xMax - x1, y1 - yMin, yMax - y1]
  for (let i = 0; i < 4; i++) {
    const pi = p[i]
    const qi = q[i]
    if (pi === 0) {
      if (qi < 0) return null // Parallel and outside
    } else {
      const r = qi / pi
      if (pi < 0) {
        if (r > t1) return null
        if (r > t0) t0 = r
      } else {
        if (r < t0) return null
        if (r < t1) t1 = r
      }
    }
  }
  const nx1 = x1 + t0 * dx
  const ny1 = y1 + t0 * dy
  const nx2 = x1 + t1 * dx
  const ny2 = y1 + t1 * dy
  return { x1: nx1, y1: ny1, x2: nx2, y2: ny2 }
}
export function computeSegmentIntersectionRect(
  x1: number,
  y1: number,
  x2: number,
  y2: number,
  xMin: number,
  yMin: number,
  xMax: number,
  yMax: number
): { x: number; y: number } | null {
  const clipped = clipLineToRect(x1, y1, x2, y2, xMin, yMin, xMax, yMax)
  if (!clipped) return null
  const dx = x2 - x1
  const dy = y2 - y1
  const eps = 1e-9
  const t1 = dx !== 0 ? (clipped.x1 - x1) / dx : (clipped.y1 - y1) / dy
  const t2 = dx !== 0 ? (clipped.x2 - x1) / dx : (clipped.y2 - y1) / dy
  let t: number | null = null
  if (t1 > eps && t1 < 1 - eps) t = t1
  if (t2 > eps && t2 < 1 - eps) t = t2
  if (t === null) {
    if (Math.abs(t1) > eps) t = t1
    else if (Math.abs(t2) > eps) t = t2
  }
  if (t === null) return null
  return { x: x1 + dx * t, y: y1 + dy * t }
}


/**
 * Compute an intersection point (x,y) where the line segment intersects the provided rect boundary.
 * Returns null if no intersection or if computation fails. This returns the first valid intersection point
 * lying between segment endpoints.
 */
// Second duplicate of computeSegmentIntersectionRect removed (use module-level declaration above)

/**
 * Compute an intersection point (x,y) where the line segment intersects the provided rect boundary.
 * Returns null if no intersection or if computation fails. This returns the first valid intersection point
 * lying between segment endpoints.
 */
// Second duplicate of computeSegmentIntersectionRect removed (use module-level declaration above)

// Duplicate computeSegmentIntersectionCircle removed; using module-level helper declared later

/**
 * Generate rectilinear pattern toolpath
 */
export function generateRectilinearPattern(
  params: ToolpathGenerationParams
): ToolpathPoint[][] {
  const { stock, cutting, pattern, feeds } = params

  // Handle circular stock differently
  const isCircular = stock.shape === 'circular'
  const stockX = isCircular ? stock.diameter || 0 : stock.x || 0
  const stockY = isCircular ? stock.diameter || 0 : stock.y || 0

  // Apply clearStockExit to circular stock
  let circularRadius = 0
  if (isCircular) {
    circularRadius = (stock.diameter || 0) / 2 - cutting.toolRadius
    if (cutting.clearStockExit) {
      circularRadius += cutting.toolRadius * 2 + 1  // Full diameter + 1mm clearance
    }
  }

  const effectiveWidth = calculateEffectiveCuttingWidth(cutting.toolRadius, cutting.stepover)

  // Local boundaries for spiral clipping
  const boundaries = calculateBoundaries(stockX, stockY, cutting.toolRadius, cutting.clearStockExit, stock.originPosition)

  // For circular stock, center is at origin (0,0).
  const centerX = 0
  const centerY = 0

  const zLevels = calculateZLevels(cutting)
  const allPasses: ToolpathPoint[][] = []

  for (const zLevel of zLevels) {
    const levelPasses: ToolpathPoint[] = []

    // Pre-compute passes
    const validPasses: Array<{ finalStart: { x: number; y: number }; finalEnd: { x: number; y: number }; passIndex: number }> = []
    // Boundaries (tool center compensated) - for rectangular stock this is used directly.
    if (isCircular) {
      // Circular: scan across diameter perpendicular to pattern angle
      const angleRad = (pattern.angle * Math.PI) / 180
      const dX = Math.cos(angleRad)
      const dY = Math.sin(angleRad)
      const scanDimension = stock.diameter || 0
      if (cutting.clearStockExit) {
        // For clear stock exit, extend scan to cover the enlarged radius
        const enlargedDiameter = scanDimension + 2 * (cutting.toolRadius * 2 + 1)
        const numPasses = calculateNumberOfPasses(enlargedDiameter, effectiveWidth)
        for (let i = 0; i < numPasses; i++) {
          const passOffset = (-(enlargedDiameter / 2) + i * effectiveWidth + effectiveWidth / 2)
          // Create line perpendicular to pattern angle at this offset
          const p0x = -dY * passOffset
          const p0y = dX * passOffset
          const x1 = p0x - dX * circularRadius
          const y1 = p0y - dY * circularRadius
          const x2 = p0x + dX * circularRadius
          const y2 = p0y + dY * circularRadius
          const clipped = clipLineToCircle(x1, y1, x2, y2, centerX, centerY, circularRadius)
          if (!clipped) continue
          validPasses.push({ finalStart: { x: clipped.x1, y: clipped.y1 }, finalEnd: { x: clipped.x2, y: clipped.y2 }, passIndex: i })
        }
      } else {
        const numPasses = calculateNumberOfPasses(scanDimension, effectiveWidth)
        for (let i = 0; i < numPasses; i++) {
          const passOffset = (-(scanDimension / 2) + i * effectiveWidth + effectiveWidth / 2)
          // Create line perpendicular to pattern angle at this offset
          const p0x = -dY * passOffset
          const p0y = dX * passOffset
          const x1 = p0x - dX * circularRadius
          const y1 = p0y - dY * circularRadius
          const x2 = p0x + dX * circularRadius
          const y2 = p0y + dY * circularRadius
          const clipped = clipLineToCircle(x1, y1, x2, y2, centerX, centerY, circularRadius)
          if (!clipped) continue
          validPasses.push({ finalStart: { x: clipped.x1, y: clipped.y1 }, finalEnd: { x: clipped.x2, y: clipped.y2 }, passIndex: i })
        }
      }
      // Respect milling direction for circular too
      if (pattern.millingDirection === 'conventional') {
        for (const vp of validPasses) {
          const sx = vp.finalStart.x, sy = vp.finalStart.y
          vp.finalStart = { x: vp.finalEnd.x, y: vp.finalEnd.y }
          vp.finalEnd = { x: sx, y: sy }
        }
      }
    } else {
      // Rectangular: compute scan lines perpendicular to angle across the axis-aligned boundary
      const angleRad = (pattern.angle * Math.PI) / 180
      const dX = Math.cos(angleRad)
      const dY = Math.sin(angleRad)
      const nX = -dY
      const nY = dX
      const corners = [
        { x: boundaries.xMin, y: boundaries.yMin },
        { x: boundaries.xMax, y: boundaries.yMin },
        { x: boundaries.xMax, y: boundaries.yMax },
        { x: boundaries.xMin, y: boundaries.yMax }
      ]
      let tMin = Infinity, tMax = -Infinity
      for (const c of corners) {
        const t = nX * c.x + nY * c.y
        if (t < tMin) tMin = t
        if (t > tMax) tMax = t
      }
      const span = tMax - tMin
      const numPasses = Math.max(1, Math.ceil(span / effectiveWidth))
      const diag = Math.hypot(boundaries.xMax - boundaries.xMin, boundaries.yMax - boundaries.yMin)
      for (let i = 0; i < numPasses; i++) {
        const t = tMin + (i + 0.5) * effectiveWidth
        // Point on line closest to rectangle center
        const cX = (boundaries.xMin + boundaries.xMax) / 2
        const cY = (boundaries.yMin + boundaries.yMax) / 2
        const cProj = nX * cX + nY * cY
        const delta = cProj - t
        const p0x = cX - delta * nX
        const p0y = cY - delta * nY
        // Long segment along direction d
        const p1x = p0x - dX * diag
        const p1y = p0y - dY * diag
        const p2x = p0x + dX * diag
        const p2y = p0y + dY * diag
        const clipped = clipLineToRect(p1x, p1y, p2x, p2y, boundaries.xMin, boundaries.yMin, boundaries.xMax, boundaries.yMax)
        if (!clipped) continue
        validPasses.push({ finalStart: { x: clipped.x1, y: clipped.y1 }, finalEnd: { x: clipped.x2, y: clipped.y2 }, passIndex: i })
      }
      // Respect milling direction: reverse segment ordering if conventional
      if (pattern.millingDirection === 'conventional') {
        for (const vp of validPasses) {
          const sx = vp.finalStart.x, sy = vp.finalStart.y
          vp.finalStart = { x: vp.finalEnd.x, y: vp.finalEnd.y }
          vp.finalEnd = { x: sx, y: sy }
        }
      }
    }

    // Now generate moves for valid passes
    for (let validIdx = 0; validIdx < validPasses.length; validIdx++) {
      const { finalStart, finalEnd, passIndex } = validPasses[validIdx]
      const isLastPass = validIdx === validPasses.length - 1

      // Rapid to start
      levelPasses.push({
        x: finalStart.x,
        y: finalStart.y,
        z: cutting.zOffset + cutting.safeZHeight,
        feedRate: 0,
        type: 'rapid'
      })
      // Plunge
      levelPasses.push({
        x: finalStart.x,
        y: finalStart.y,
        z: zLevel.depth,
        feedRate: feeds.z,
        type: 'linear'
      })
      // Cutting move
      levelPasses.push({
        x: finalEnd.x,
        y: finalEnd.y,
        z: zLevel.depth,
        feedRate: feeds.xy,
        type: 'linear'
      })
      // Retract
      levelPasses.push({
        x: finalEnd.x,
        y: finalEnd.y,
        z: cutting.zOffset + cutting.safeZHeight,
        feedRate: 0,
        type: 'rapid'
      })

      // Rapid back to start of next pass (only if not the last pass)
      if (!isLastPass) {
        const nextPass = validPasses[validIdx + 1]
        levelPasses.push({
          x: nextPass.finalStart.x,
          y: nextPass.finalStart.y,
          z: cutting.zOffset + cutting.safeZHeight,
          feedRate: 0,
          type: 'rapid'
        })
      }
    }

    allPasses.push(levelPasses)
  }

  return allPasses
}

export function computeSegmentIntersectionCircle(
  x1: number,
  y1: number,
  x2: number,
  y2: number,
  cx: number,
  cy: number,
  radius: number
): { x: number; y: number } | null {
  const clipped = clipLineToCircle(x1, y1, x2, y2, cx, cy, radius)
  if (!clipped) return null
  const dx = x2 - x1
  const dy = y2 - y1
  const eps = 1e-9
  const t1 = dx !== 0 ? (clipped.x1 - x1) / dx : (clipped.y1 - y1) / dy
  const t2 = dx !== 0 ? (clipped.x2 - x1) / dx : (clipped.y2 - y1) / dy
  let t: number | null = null
  if (t1 > eps && t1 < 1 - eps) t = t1
  if (t2 > eps && t2 < 1 - eps) t = t2
  if (t === null) {
    if (Math.abs(t1) > eps) t = t1
    else if (Math.abs(t2) > eps) t = t2
  }
  if (t === null) return null
  return { x: x1 + dx * t, y: y1 + dy * t }
}

/**
 * Generate zigzag pattern toolpath (continuous motion)
 */
export function generateZigzagPattern(
  params: ToolpathGenerationParams
): ToolpathPoint[][] {
  const { stock, cutting, pattern, feeds } = params

  // Handle circular stock differently
  const isCircular = stock.shape === 'circular'
  const stockX = isCircular ? stock.diameter || 0 : stock.x || 0
  const stockY = isCircular ? stock.diameter || 0 : stock.y || 0

  // Apply clearStockExit to circular stock
  let circularRadius = 0
  if (isCircular) {
    circularRadius = (stock.diameter || 0) / 2 - cutting.toolRadius
    if (cutting.clearStockExit) {
      circularRadius += cutting.toolRadius * 2 + 1  // Full diameter + 1mm clearance
    }
  }

  const effectiveWidth = calculateEffectiveCuttingWidth(cutting.toolRadius, cutting.stepover)
  const boundaries = calculateBoundaries(stockX, stockY, cutting.toolRadius, cutting.clearStockExit, stock.originPosition)

  // For circular stock, center is at origin (0,0).
  const centerX = 0
  const centerY = 0

  const zLevels = calculateZLevels(cutting)
  const allPasses: ToolpathPoint[][] = []

  for (const zLevel of zLevels) {
    const levelPasses: ToolpathPoint[] = []

    if (isCircular) {
      // Circular: compute scan segments perpendicular to pattern angle with direction based on millingDirection
      const angleRad = (pattern.angle * Math.PI) / 180
      const dX = Math.cos(angleRad)
      const dY = Math.sin(angleRad)
      const scanDimension = stock.diameter || 0
      const effectiveScanDimension = cutting.clearStockExit
        ? scanDimension + 2 * (cutting.toolRadius * 2 + 1)
        : scanDimension
      const numPasses = calculateNumberOfPasses(effectiveScanDimension, effectiveWidth)
      const baseForward = pattern.millingDirection === 'climb'
      const segments: Array<{ a: { x: number; y: number }; b: { x: number; y: number } }> = []
      for (let i = 0; i < numPasses; i++) {
        const passOffset = (-(effectiveScanDimension / 2) + (i * effectiveWidth) + effectiveWidth / 2)
        // Create line perpendicular to pattern angle at this offset
        const p0x = -dY * passOffset
        const p0y = dX * passOffset
        const x1 = p0x - dX * circularRadius
        const y1 = p0y - dY * circularRadius
        const x2 = p0x + dX * circularRadius
        const y2 = p0y + dY * circularRadius
        const seg = clipLineToCircle(x1, y1, x2, y2, centerX, centerY, circularRadius)
        if (!seg) continue
        const forward = baseForward ? (i % 2 === 0) : (i % 2 !== 0)
        const a = forward ? { x: seg.x1, y: seg.y1 } : { x: seg.x2, y: seg.y2 }
        const b = forward ? { x: seg.x2, y: seg.y2 } : { x: seg.x1, y: seg.y1 }
        segments.push({ a, b })
      }
      if (segments.length > 0) {
        const s0 = segments[0].a
        levelPasses.push({ x: s0.x, y: s0.y, z: cutting.zOffset + cutting.safeZHeight, feedRate: 0, type: 'rapid' })
        levelPasses.push({ x: s0.x, y: s0.y, z: zLevel.depth, feedRate: feeds.z, type: 'linear' })
        let current = s0
        for (let segIdx = 0; segIdx < segments.length; segIdx++) {
          const seg = segments[segIdx]
          // Connect to start of this segment using arc along circle boundary
          if (current.x !== seg.a.x || current.y !== seg.a.y) {
            // Both points should lie on circle; create shortest arc between them
            const a1 = Math.atan2(current.y - centerY, current.x - centerX)
            const a2 = Math.atan2(seg.a.y - centerY, seg.a.x - centerX)
            let delta = a2 - a1
            // Normalize to [-PI, PI] to get the shortest angular distance
            while (delta > Math.PI) delta -= 2 * Math.PI
            while (delta < -Math.PI) delta += 2 * Math.PI
            // For G-code arcs: G2 is clockwise (CW), G3 is counter-clockwise (CCW)
            // When delta is negative, we go clockwise; when positive, counter-clockwise
            // But if |delta| > PI, we want the other direction (the shorter arc)
            const clockwise = delta < 0
            // Center offsets relative to start point (I,J in G-code semantics)
            const iOff = centerX - current.x
            const jOff = centerY - current.y
            levelPasses.push({
              x: seg.a.x,
              y: seg.a.y,
              z: zLevel.depth,
              feedRate: feeds.xy,
              type: 'arc',
              i: iOff,
              j: jOff,
              clockwise
            })
          }
          // Cut to end of this segment
          levelPasses.push({ x: seg.b.x, y: seg.b.y, z: zLevel.depth, feedRate: feeds.xy, type: 'linear' })
          current = seg.b
        }
      }
    } else {
      // Rectangular: angle-true zigzag using projection lines
      const angleRad = (pattern.angle * Math.PI) / 180
      const dX = Math.cos(angleRad)
      const dY = Math.sin(angleRad)
      const nX = -dY
      const nY = dX
      const corners = [
        { x: boundaries.xMin, y: boundaries.yMin },
        { x: boundaries.xMax, y: boundaries.yMin },
        { x: boundaries.xMax, y: boundaries.yMax },
        { x: boundaries.xMin, y: boundaries.yMax }
      ]
      let tMin = Infinity, tMax = -Infinity
      for (const c of corners) {
        const t = nX * c.x + nY * c.y
        if (t < tMin) tMin = t
        if (t > tMax) tMax = t
      }
      const span = tMax - tMin
      const numPasses = Math.max(1, Math.ceil(span / effectiveWidth))
      const diag = Math.hypot(boundaries.xMax - boundaries.xMin, boundaries.yMax - boundaries.yMin)
      // Determine initial direction
      const baseForward = pattern.millingDirection === 'climb'
      // Build segments list first
      const segments: Array<{ a: { x: number; y: number }; b: { x: number; y: number } }> = []
      for (let i = 0; i < numPasses; i++) {
        const t = tMin + (i + 0.5) * effectiveWidth
        const cX = (boundaries.xMin + boundaries.xMax) / 2
        const cY = (boundaries.yMin + boundaries.yMax) / 2
        const cProj = nX * cX + nY * cY
        const delta = cProj - t
        const p0x = cX - delta * nX
        const p0y = cY - delta * nY
        const p1x = p0x - dX * diag
        const p1y = p0y - dY * diag
        const p2x = p0x + dX * diag
        const p2y = p0y + dY * diag
        const clipped = clipLineToRect(p1x, p1y, p2x, p2y, boundaries.xMin, boundaries.yMin, boundaries.xMax, boundaries.yMax)
        if (!clipped) continue
        // Order endpoints along +/-d depending on pass parity and baseForward
        const s1 = dX * clipped.x1 + dY * clipped.y1
        const s2 = dX * clipped.x2 + dY * clipped.y2
        const forward = baseForward ? (i % 2 === 0) : (i % 2 !== 0)
        const a = forward ? (s1 <= s2 ? { x: clipped.x1, y: clipped.y1 } : { x: clipped.x2, y: clipped.y2 })
          : (s1 > s2 ? { x: clipped.x1, y: clipped.y1 } : { x: clipped.x2, y: clipped.y2 })
        const b = (a.x === clipped.x1 && a.y === clipped.y1) ? { x: clipped.x2, y: clipped.y2 } : { x: clipped.x1, y: clipped.y1 }
        segments.push({ a, b })
      }
      if (segments.length > 0) {
        // Rapid and plunge to first segment start
        const s0 = segments[0].a
        levelPasses.push({ x: s0.x, y: s0.y, z: cutting.zOffset + cutting.safeZHeight, feedRate: 0, type: 'rapid' })
        levelPasses.push({ x: s0.x, y: s0.y, z: zLevel.depth, feedRate: feeds.z, type: 'linear' })
        // Traverse all segments, connecting endpoints
        let current = s0
        for (const seg of segments) {
          // Move to start if not already there
          if (current.x !== seg.a.x || current.y !== seg.a.y) {
            levelPasses.push({ x: seg.a.x, y: seg.a.y, z: zLevel.depth, feedRate: feeds.xy, type: 'linear' })
          }
          // Cut to end
          levelPasses.push({ x: seg.b.x, y: seg.b.y, z: zLevel.depth, feedRate: feeds.xy, type: 'linear' })
          current = seg.b
        }
      }
    }

    // Final retract for this Z level
    if (levelPasses.length > 0) {
      const lastPoint = levelPasses[levelPasses.length - 1]
      levelPasses.push({
        x: lastPoint.x,
        y: lastPoint.y,
        z: zLevel.depth + cutting.safeZHeight,
        feedRate: 0,
        type: 'rapid'
      })
    }

    allPasses.push(levelPasses)
  }

  return allPasses
}

/**
 * Generate spiral pattern toolpath
 */
export function generateSpiralPattern(
  params: ToolpathGenerationParams
): ToolpathPoint[][] {
  const { stock, cutting, pattern, feeds } = params

  // Handle both circular and rectangular stock
  const isCircular = stock.shape === 'circular'
  const stockX = isCircular ? stock.diameter || 0 : stock.x || 0
  const stockY = isCircular ? stock.diameter || 0 : stock.y || 0

  const effectiveWidth = calculateEffectiveCuttingWidth(cutting.toolRadius, cutting.stepover)

  // For circular stock, center is at origin (0,0)
  // For rectangular stock, calculate based on origin position
  const centerX = isCircular ? 0 : (calculateOriginOffset(stockX, stockY, stock.originPosition).x + stockX / 2)
  const centerY = isCircular ? 0 : (calculateOriginOffset(stockX, stockY, stock.originPosition).y + stockY / 2)

  const zLevels = calculateZLevels(cutting)
  const allPasses: ToolpathPoint[][] = []
  const exitTolerance = 1 // mm outside boundary to consider as exit
  // Precompute boundaries and allowed radii once per call (stock doesn't change per z-level)
  let boundaries = calculateBoundaries(stockX, stockY, cutting.toolRadius, cutting.clearStockExit, stock.originPosition)
  const allowedRadius = (stock.diameter || 0) / 2 - cutting.toolRadius
  const allowedRadiusTol = allowedRadius + exitTolerance

  for (const zLevel of zLevels) {
    const levelPasses: ToolpathPoint[] = []

    // Use higher resolution for finishing passes (1.5x segments, max 60 segments/rev)
    const segmentsMultiplier = zLevel.isFinishing ? 1.5 : 1

    // Determine spiral direction: climb = CCW (positive angle), conventional = CW (negative angle)
    const spiralDirectionMultiplier = pattern.millingDirection === 'climb' ? 1 : -1

    // Determine if we're going outside-in or inside-out
    const isOutsideIn = pattern.spiralDirection !== 'inside-out'

    // Calculate initial radius based on stock shape
    let outerRadius: number
    let innerRadius: number = cutting.toolRadius

    if (isCircular) {
      // For circular stock, outer edge is stock radius minus tool radius
      outerRadius = (stock.diameter || 0) / 2 - cutting.toolRadius

      // Add clearance if clear stock exit is enabled
      if (cutting.clearStockExit) {
        outerRadius += cutting.toolRadius * 2 + 1  // Full diameter + 1mm clearance
      }
    } else {
      // For rectangular stock, use diagonal to encompass entire stock
      boundaries = calculateBoundaries(stockX, stockY, cutting.toolRadius, cutting.clearStockExit, stock.originPosition)
      const halfWidth = (boundaries.xMax - boundaries.xMin) / 2
      const halfHeight = (boundaries.yMax - boundaries.yMin) / 2
      outerRadius = Math.sqrt(halfWidth * halfWidth + halfHeight * halfHeight)
    }
    // Ensure we have boundaries defined even for circular stock so later code can refer to it
    if (isCircular) {
      const allowedRadius = (stock.diameter || 0) / 2 - cutting.toolRadius
      boundaries = {
        xMin: centerX - allowedRadius,
        xMax: centerX + allowedRadius,
        yMin: centerY - allowedRadius,
        yMax: centerY + allowedRadius
      }
    }

    // Set starting radius based on spiral direction
    const initialRadius = isOutsideIn ? outerRadius : innerRadius
    const finalRadius = isOutsideIn ? innerRadius : outerRadius

    // Start at the appropriate edge of the spiral at the pattern angle
    const startAngle = pattern.angle * Math.PI / 180
    const startX = centerX + initialRadius * Math.cos(startAngle)
    const startY = centerY + initialRadius * Math.sin(startAngle)

    // We'll determine the starting point after we build the spiral points

    // Generate spiral as a series of line segments
    // Total segments per revolution controlled by spiralSegmentsPerRevolution parameter
    const baseSegments = pattern.spiralSegmentsPerRevolution || 30  // Default to 30 if not specified
    const segmentsPerRevolution = baseSegments * segmentsMultiplier  // 1.5x for finishing passes (max 60)
    const anglePerSegment = spiralDirectionMultiplier * (2 * Math.PI) / segmentsPerRevolution
    const radiusDecrementPerRevolution = effectiveWidth
    const radiusChangePerSegment = (isOutsideIn ? -1 : 1) * radiusDecrementPerRevolution / segmentsPerRevolution

    // Number of complete revolutions based on stepover
    const totalRadialDistance = Math.abs(outerRadius - innerRadius)
    const numRevolutions = totalRadialDistance / effectiveWidth
    const totalSegments = Math.floor(numRevolutions * segmentsPerRevolution)

    let currentRadius = initialRadius
    let currentAngle = startAngle
    // Build list of spiral points first
    const spiralPoints: Array<{ x: number; y: number }> = []
    spiralPoints.push({ x: startX, y: startY })
    for (let seg = 0; seg < totalSegments; seg++) {
      // Calculate next radius
      const nextRadius = currentRadius + radiusChangePerSegment

      // Stop if we've reached the final radius (with small tolerance)
      if (isOutsideIn && nextRadius < finalRadius) break
      if (!isOutsideIn && nextRadius > finalRadius) break

      // Calculate end angle for this segment
      const endAngle = currentAngle + anglePerSegment

      // Calculate endpoint for this line segment
      const endX = centerX + nextRadius * Math.cos(endAngle)
      const endY = centerY + nextRadius * Math.sin(endAngle)

      spiralPoints.push({ x: endX, y: endY })

      // Update for next iteration
      currentRadius = nextRadius
      currentAngle = endAngle
    }
    // Inside predicate uses already-precomputed boundaries and allowed radius/tolerance
    const pointInside = (x: number, y: number) => {
      if (isCircular) {
        const dx = x - centerX
        const dy = y - centerY
        return Math.sqrt(dx * dx + dy * dy) <= allowedRadiusTol
      }
      return (
        x >= (boundaries.xMin - exitTolerance) &&
        x <= (boundaries.xMax + exitTolerance) &&
        y >= (boundaries.yMin - exitTolerance) &&
        y <= (boundaries.yMax + exitTolerance)
      )
    }

    // Helper: compute intersection on segment between inside->outside with expanded rectangle/circle
    // Note: local segment -> boundary intersection helpers removed; using module-level computeSegmentIntersectionRect / Circle



    // Now walk the points, inserting only cutting lines for 'inside' points and G0 moves for outside re-entry
    const L = spiralPoints.length
    // Find first index where we are inside
    let firstInsideIdx = spiralPoints.findIndex(p => pointInside(p.x, p.y))
    if (firstInsideIdx === -1) {
      // The whole spiral doesn't touch the stock - skip
      allPasses.push(levelPasses)
      continue
    }

    // Rapid to first inside point at safeZ and plunge
    const firstPt = spiralPoints[firstInsideIdx]
    levelPasses.push({ x: firstPt.x, y: firstPt.y, z: cutting.zOffset + cutting.safeZHeight, feedRate: 0, type: 'rapid' })
    levelPasses.push({ x: firstPt.x, y: firstPt.y, z: zLevel.depth, feedRate: feeds.z, type: 'linear' })

    let idx = firstInsideIdx
    while (idx < L - 1) {
      const nextIdx = idx + 1
      const nextPt = spiralPoints[nextIdx]
      const currPt = spiralPoints[idx]
      if (pointInside(nextPt.x, nextPt.y)) {
        // normal cutting linear
        levelPasses.push({ x: nextPt.x, y: nextPt.y, z: zLevel.depth, feedRate: feeds.xy, type: 'linear' })
        idx = nextIdx
        continue
      }

      // next point is outside: find next re-entry; compute exit intersection point at the expanded boundary
      let reentryIdx = -1
      for (let j = nextIdx + 1; j < L; j++) {
        if (pointInside(spiralPoints[j].x, spiralPoints[j].y)) {
          reentryIdx = j
          break
        }
      }
      if (reentryIdx === -1) {
        // no re-entry found: end spiral
        break
      }

      // First, compute exact exitIntersection for current segment (idx -> nextIdx)
      let exitIntersection: { x: number; y: number } | null = null
      if (isCircular) {
        exitIntersection = computeSegmentIntersectionCircle(currPt.x, currPt.y, nextPt.x, nextPt.y, centerX, centerY, allowedRadius)
      } else {
        exitIntersection = computeSegmentIntersectionRect(currPt.x, currPt.y, nextPt.x, nextPt.y, boundaries.xMin, boundaries.yMin, boundaries.xMax, boundaries.yMax)
      }
      // If we found an exit intersection, push a cutting linear to it; otherwise, push a linear to nextPt as before
      if (exitIntersection) {
        levelPasses.push({ x: exitIntersection.x, y: exitIntersection.y, z: zLevel.depth, feedRate: feeds.xy, type: 'linear' })
      } else {
        // fallback: do not cut to an outside point — safely raise and rapid to next point at safeZ
        const last = levelPasses[levelPasses.length - 1]
        if (last && last.z !== zLevel.depth + cutting.safeZHeight) {
          levelPasses.push({ x: last.x, y: last.y, z: zLevel.depth + cutting.safeZHeight, feedRate: 0, type: 'rapid' })
        }
        levelPasses.push({ x: nextPt.x, y: nextPt.y, z: zLevel.depth + cutting.safeZHeight, feedRate: 0, type: 'rapid' })
      }

      // Move up to safe height before rapid
      const last = levelPasses[levelPasses.length - 1]
      if (last && last.z !== zLevel.depth + cutting.safeZHeight) {
        levelPasses.push({ x: last.x, y: last.y, z: zLevel.depth + cutting.safeZHeight, feedRate: 0, type: 'rapid' })
      }

      // Compute reentry outside intersection (1mm outside the stock) for the segment reentryIdx-1 -> reentryIdx
      const preReentry = spiralPoints[reentryIdx - 1]
      const reentry = spiralPoints[reentryIdx]
      let reentryOutside: { x: number; y: number } | null = null
      let reentryInside: { x: number; y: number } | null = null
      if (isCircular) {
        reentryOutside = computeSegmentIntersectionCircle(preReentry.x, preReentry.y, reentry.x, reentry.y, centerX, centerY, allowedRadiusTol)
        reentryInside = computeSegmentIntersectionCircle(preReentry.x, preReentry.y, reentry.x, reentry.y, centerX, centerY, allowedRadius)
      } else {
        reentryOutside = computeSegmentIntersectionRect(preReentry.x, preReentry.y, reentry.x, reentry.y, boundaries.xMin - exitTolerance, boundaries.yMin - exitTolerance, boundaries.xMax + exitTolerance, boundaries.yMax + exitTolerance)
        reentryInside = computeSegmentIntersectionRect(preReentry.x, preReentry.y, reentry.x, reentry.y, boundaries.xMin, boundaries.yMin, boundaries.xMax, boundaries.yMax)
      }
      // Rapid to the outside intersection point and plunge to the inside re-entry point
      if (reentryOutside) {
        levelPasses.push({ x: reentryOutside.x, y: reentryOutside.y, z: zLevel.depth + cutting.safeZHeight, feedRate: 0, type: 'rapid' })
      } else {
        // fallback to reentry — still do rapid to reentry at safeZ, better than plunging blindly
        levelPasses.push({ x: reentry.x, y: reentry.y, z: zLevel.depth + cutting.safeZHeight, feedRate: 0, type: 'rapid' })
      }
      // Plunge to cutting depth at exact inside intersection if available, else the first spiral in-point
      if (reentryInside) {
        levelPasses.push({ x: reentryInside.x, y: reentryInside.y, z: zLevel.depth, feedRate: feeds.z, type: 'linear' })
      } else {
        levelPasses.push({ x: reentry.x, y: reentry.y, z: zLevel.depth, feedRate: feeds.z, type: 'linear' })
      }
      idx = reentryIdx
    }
    // Final retract for this Z level
    if (levelPasses.length > 0) {
      const lastPoint = levelPasses[levelPasses.length - 1]
      levelPasses.push({
        x: lastPoint.x,
        y: lastPoint.y,
        z: zLevel.depth + cutting.safeZHeight,
        feedRate: 0,
        type: 'rapid'
      })
    }

    allPasses.push(levelPasses)
  }

  return allPasses
}

/**
 * Calculate Z levels for roughing and finishing passes
 */
export function calculateZLevels(
  cutting: CuttingParameters
): Array<{ depth: number; isFinishing: boolean }> {
  const levels: Array<{ depth: number; isFinishing: boolean }> = []

  let roughingDepth = cutting.totalDepth

  if (cutting.finishingPass) {
    roughingDepth = cutting.totalDepth - cutting.finishingPassHeight
  }

  // Calculate roughing passes
  const numRoughingPasses = Math.ceil(roughingDepth / cutting.stepdown)

  for (let i = 0; i < numRoughingPasses; i++) {
    const depth = cutting.zOffset - Math.min((i + 1) * cutting.stepdown, roughingDepth)
    levels.push({ depth, isFinishing: false })
  }

  // Add finishing pass if enabled
  if (cutting.finishingPass) {
    const finishDepth = cutting.zOffset - cutting.totalDepth
    levels.push({ depth: finishDepth, isFinishing: true })
  }

  return levels
}

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
      throw new Error(`Unknown pattern type: ${params.pattern.type}`)
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
  const roughingPasses = zLevels.filter(l => !l.isFinishing).length
  const finishingPass = zLevels.some(l => l.isFinishing)

  // Calculate material removed (simplified - assumes rectangular stock)
  const materialRemoved = 0  // TODO: Calculate based on stock geometry

  return {
    totalDistance: Math.round(totalDistance * 10) / 10,
    estimatedTime: Math.round(estimatedTimeSeconds),
    materialRemoved,
    roughingPasses,
    finishingPass
  }
}
