/**
 * DWC file upload for NeXT persistence files.
 * Uses the machine connector (rr_upload + CRC/retry) — not raw fetch.
 */
import store from '@/store'

export const NXT_USER_VARS_DWC_PATH = '0:/sys/nxt-user-vars.g'
export const NXT_USER_PINMAP_DWC_PATH = '0:/sys/nxt-user-pinmap.g'
export const NXT_USER_TOOLS_DWC_PATH = '0:/sys/nxt-user-tools.g'
export const NXT_BOARD_BOOTSTRAP_REQUESTED = '0:/sys/nxt-board-bootstrap.requested'
export const NXT_BOARD_BOOTSTRAP_SKIP = '0:/sys/nxt-board-bootstrap.skip'

/** Legacy HTTP-style paths from early NeXT UI — normalize to SD paths. */
export function resolveDwcUploadPath(fullPath: string): string {
  const trimmed = fullPath.trim()
  if (/^\d+:/.test(trimmed)) {
    return trimmed
  }
  if (trimmed.startsWith('/')) {
    return `0:${trimmed}`
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
export async function listDwcDirectory(dir: string): Promise<string[] | null> {
  const axios = (store as { $axios?: { get: (url: string, config?: object) => Promise<{ data: unknown }> } }).$axios
  if (!axios) {
    return null
  }
  try {
    const res = await axios.get('machine/directory', { params: { dir: resolveDwcUploadPath(dir) } })
    const data = res.data as { files?: Array<{ name?: string }> }
    if (!Array.isArray(data?.files)) {
      return []
    }
    return data.files.map((f) => f.name).filter((n): n is string => typeof n === 'string')
  } catch (e) {
    console.warn('NeXT: listDwcDirectory failed', dir, e)
    return null
  }
}
