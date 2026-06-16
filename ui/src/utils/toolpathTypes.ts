/**
 * Toolpath generation types (stock preparation / facing).
 * Public entry: toolpath.ts
 */

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
