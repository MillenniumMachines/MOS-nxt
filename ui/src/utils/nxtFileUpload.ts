/**
 * DWC file upload for nxt persistence files.
 * Uses the machine connector (rr_upload + CRC/retry) — not raw fetch.
 */
import store from '@/store'

export const NXT_USER_VARS_DWC_PATH = '0:/sys/nxt-user-vars.g'
export const NXT_USER_PINMAP_DWC_PATH = '0:/sys/nxt-user-pinmap.g'
export const NXT_USER_TOOLS_DWC_PATH = '0:/sys/nxt-user-tools.g'
export const NXT_BOARD_BOOTSTRAP_REQUESTED = '0:/sys/nxt-board-bootstrap.requested'
export const NXT_BOARD_BOOTSTRAP_SKIP = '0:/sys/nxt-board-bootstrap.skip'

/** Legacy HTTP-style paths from early nxt UI — normalize to SD paths. */
export function resolveDwcUploadPath(fullPath: string): string {
  const trimmed = fullPath.trim()
  if (/^\d+:/.test(trimmed)) {
    return trimmed
  }
  if (trimmed.startsWith('/')) {
    return `0:${trimmed}`
  }
  // Manifest / boot macro paths (nxt-config/…) live under 0:/sys/
  if (trimmed.startsWith('nxt-config/')) {
    return `0:/sys/${trimmed}`
  }
  if (trimmed.startsWith('sys/')) {
    return `0:/${trimmed}`
  }
  return `0:/${trimmed}`
}

/**
 * Upload text content to the board.
 * @throws Error if upload fails
 */
export async function uploadDwcFile(fullPath: string, content: string): Promise<void> {
  const filename = resolveDwcUploadPath(fullPath)
  const body = content.endsWith('\n') ? content : `${content}\n`

  await store.dispatch('machine/upload', {
    filename,
    content: body,
    showProgress: false,
    showSuccess: false,
    showError: false
  })
}

/**
 * Delete a file on the machine SD card (DWC machine/delete).
 */
export async function deleteDwcFile(fullPath: string): Promise<void> {
  const filename = resolveDwcUploadPath(fullPath)
  await store.dispatch('machine/delete', {
    filename,
    showProgress: false,
    showSuccess: false,
    showError: false
  })
}

/** True if filename appears in a machine/directory listing (best-effort). */
export async function dwcFileExists(fullPath: string): Promise<boolean> {
  const filename = resolveDwcUploadPath(fullPath)
  const lastSlash = filename.lastIndexOf('/')
  const dir = lastSlash >= 0 ? filename.slice(0, lastSlash) : '0:/'
  const base = lastSlash >= 0 ? filename.slice(lastSlash + 1) : filename
  const names = await listDwcDirectory(dir)
  if (names == null) {
    return false
  }
  return names.includes(base)
}

/** List file names in a directory via DWC REST API. */
/** Download a text file from the machine SD / www tree. */
export async function downloadDwcTextFile(fullPath: string): Promise<string> {
  const filename = resolveDwcUploadPath(fullPath)
  const response = await store.dispatch('machine/download', {
    filename,
    type: 'text',
    showProgress: false,
    showSuccess: false,
    showError: true
  })
  if (typeof response === 'string') {
    return response
  }
  if (response instanceof ArrayBuffer) {
    return new TextDecoder('utf-8').decode(response)
  }
  throw new Error(`Unexpected download response for ${filename}`)
}

type DwcListEntry = { name: string; isDirectory?: boolean }

/**
 * List names in a directory via the host DWC connector (GET machine/directory/…).
 * @param directoriesOnly When true, return subdirectory names only (e.g. machine profile ids).
 */
export async function listDwcDirectory(
  dir: string,
  options?: { directoriesOnly?: boolean }
): Promise<string[] | null> {
  const directory = resolveDwcUploadPath(dir)
  try {
    const items = (await store.dispatch('machine/getFileList', directory)) as DwcListEntry[]
    if (!Array.isArray(items)) {
      return []
    }
    return items
      .filter((item) => !options?.directoriesOnly || item.isDirectory)
      .map((item) => item.name)
      .filter((n): n is string => typeof n === 'string')
  } catch (e) {
    console.warn('nxt: listDwcDirectory failed', directory, e)
    return null
  }
}
