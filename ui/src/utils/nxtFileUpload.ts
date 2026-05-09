/**
 * DWC HTTP file upload via POST /rr_upload (RepRapFirmware HTTP API).
 * Uses a raw request body as documented on the RRF wiki (curl --data-binary style).
 * Path form: `/sys/...` (HTTP examples use this — not `0:/sys/...`).
 */

export const NXT_USER_VARS_DWC_PATH = '/sys/nxt-user-vars.g'
export const NXT_USER_PINMAP_DWC_PATH = '/sys/nxt-user-pinmap.g'
export const NXT_USER_TOOLS_DWC_PATH = '/sys/nxt-user-tools.g'

function parseRrUploadErr(responseText: string): number | undefined {
  try {
    const j = JSON.parse(responseText) as { err?: number }
    if (typeof j.err === 'number') {
      return j.err
    }
  } catch {
    // ignore
  }
  return undefined
}

/**
 * Upload text content. `fullPath` must match RRF HTTP expectations (e.g. `/sys/nxt-user-vars.g`).
 * @throws Error if HTTP status is not OK or JSON body reports `err !== 0`
 */
export async function uploadDwcFile(
  fullPath: string,
  content: string,
  mime: string = 'text/plain'
): Promise<void> {
  const body = content.endsWith('\n') ? content : content + '\n'
  const url = `/rr_upload?name=${encodeURIComponent(fullPath)}`

  const response = await fetch(url, {
    method: 'POST',
    credentials: 'same-origin',
    headers: { 'Content-Type': mime },
    body: body
  })

  const text = await response.text()
  const rrErr = parseRrUploadErr(text)

  if (!response.ok || (rrErr != null && rrErr !== 0)) {
    const detail =
      rrErr != null && rrErr !== 0 ? ` (firmware err=${rrErr})` : ''
    throw new Error(`Upload failed (${response.status})${detail}: ${fullPath}`)
  }
}
