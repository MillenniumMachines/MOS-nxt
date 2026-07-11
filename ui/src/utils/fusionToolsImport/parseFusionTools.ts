/**
 * Parse Autodesk Fusion `.tools` archives (ZIP with tools.json).
 */

import type { FusionToolRecord } from './fusionImportPolicy'

export function parseFusionToolsJson(text: string): FusionToolRecord[] {
  let doc: unknown
  try {
    doc = JSON.parse(text)
  } catch {
    throw new Error('That file is not valid JSON.')
  }
  if (doc == null || typeof doc !== 'object') {
    throw new Error('tools.json root must be an object.')
  }
  const data = (doc as Record<string, unknown>).data
  if (!Array.isArray(data)) {
    throw new Error('This does not look like a Fusion tool library (no "data" array).')
  }
  return data as FusionToolRecord[]
}

function findToolsJsonName(names: string[]): string | null {
  if (names.includes('tools.json')) {
    return 'tools.json'
  }
  const lower = names.find((n) => n.toLowerCase().endsWith('/tools.json'))
  return lower ?? null
}

/**
 * Read a Fusion `.tools` file (ZIP) or plain tools.json text.
 */
export async function parseFusionToolsFile(file: File): Promise<FusionToolRecord[]> {
  const buf = await file.arrayBuffer()
  const bytes = new Uint8Array(buf)
  const isZip = bytes.length >= 4 && bytes[0] === 0x50 && bytes[1] === 0x4b

  if (!isZip) {
    const text = new TextDecoder('utf-8').decode(buf)
    return parseFusionToolsJson(text)
  }

  const JSZip = (await import('jszip')).default
  const zip = await JSZip.loadAsync(buf)
  const entryName = findToolsJsonName(Object.keys(zip.files))
  if (!entryName) {
    throw new Error('Expected tools.json inside the .tools archive.')
  }
  const text = await zip.file(entryName)!.async('string')
  return parseFusionToolsJson(text)
}
