/**
 * Web Worker for generating toolpaths in background thread
 * Prevents UI freezing during generation of large toolpaths
 */

import {
  generateToolpath,
  calculateToolpathStatistics,
  ToolpathGenerationParams,
  ToolpathPoint
} from '../utils/toolpath'

export interface ToolpathWorkerRequest {
  type: 'generate'
  params: ToolpathGenerationParams
}

export interface ToolpathWorkerProgress {
  type: 'progress'
  progress: number
  message: string
}

export interface ToolpathWorkerResponse {
  type: 'complete' | 'error'
  toolpath?: ToolpathPoint[][]
  statistics?: {
    totalDistance: number
    estimatedTime: number
    materialRemoved: number
    roughingPasses: number
    finishingPass: boolean
  }
  error?: string
}

export type ToolpathWorkerMessage = ToolpathWorkerProgress | ToolpathWorkerResponse

// Handle messages from main thread
self.addEventListener('message', async (event: MessageEvent<ToolpathWorkerRequest>) => {
  const { type, params } = event.data

  if (type !== 'generate') {
    postMessage({
      type: 'error',
      error: `Unknown worker request type: ${type}`
    } as ToolpathWorkerResponse)
    return
  }

  try {
    // Report start
    postMessage({
      type: 'progress',
      progress: 0,
      message: 'Starting toolpath generation...'
    } as ToolpathWorkerProgress)

    // Generate toolpath
    // Note: The generateToolpath function doesn't currently support progress callbacks,
    // but we can estimate progress based on the operation parameters
    const toolpath = generateToolpath(params)

    // Report toolpath generation complete
    postMessage({
      type: 'progress',
      progress: 80,
      message: 'Calculating statistics...'
    } as ToolpathWorkerProgress)

    // Calculate statistics
    const statistics = calculateToolpathStatistics(toolpath, params.cutting)

    // Report complete
    postMessage({
      type: 'progress',
      progress: 100,
      message: 'Generation complete'
    } as ToolpathWorkerProgress)

    // Send final result
    postMessage({
      type: 'complete',
      toolpath,
      statistics
    } as ToolpathWorkerResponse)

  } catch (error) {
    postMessage({
      type: 'error',
      error: error instanceof Error ? error.message : String(error)
    } as ToolpathWorkerResponse)
  }
})
