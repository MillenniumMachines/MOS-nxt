/**
 * DWC file upload for NeXT persistence files.
 * Uses the machine connector (rr_upload + CRC/retry) — not raw fetch.
 */
import store from '@/store'

export const NXT_USER_VARS_DWC_PATH = '0:/sys/nxt-user-vars.g'
export const NXT_USER_PINMAP_DWC_PATH = '0:/sys/nxt-user-pinmap.g'
export const NXT_USER_TOOLS_DWC_PATH = '0:/sys/nxt-user-tools.g'

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
