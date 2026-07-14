/**
 * Live OM updates that may need `if` / `global` declare.
 *
 * RRF rejects interactive `if` with "Conditional codes must not be executed".
 * Upload a scratch macro and M98 it instead.
 */
import { uploadDwcFile } from './nxtFileUpload'

export const NXT_OM_SET_SCRATCH_PATH = '0:/sys/nxt-om-set-scratch.g'

export type OmSetSender = (code: string) => Promise<unknown>

/**
 * Ensure `global.<key>` exists, then assign RHS (already formatted for G-code).
 * Example rhs: `null`, `48`, `"custom"`, `{ "aux0" }`
 */
export async function ensureSetFirmwareGlobal(
  key: string,
  rhs: string,
  sendCode: OmSetSender
): Promise<void> {
  const safeKey = String(key).replace(/[^A-Za-z0-9_]/g, '')
  if (!safeKey.startsWith('nxt')) {
    throw new Error(`ensureSetFirmwareGlobal: refused key ${key}`)
  }
  const body = [
    '; nxt-om-set-scratch.g — written by nxt UI (do not edit)',
    `if { !exists(global.${safeKey}) }`,
    `    global ${safeKey} = ${rhs}`,
    `else`,
    `    set global.${safeKey} = ${rhs}`,
    ''
  ].join('\n')
  await uploadDwcFile(NXT_OM_SET_SCRATCH_PATH, body)
  await sendCode('M98 P"nxt-om-set-scratch.g"')
}

/** Clear a deprecated optional global only if it already exists (no declare). */
export async function clearFirmwareGlobalIfExists(
  key: string,
  sendCode: OmSetSender
): Promise<void> {
  const safeKey = String(key).replace(/[^A-Za-z0-9_]/g, '')
  if (!safeKey.startsWith('nxt')) {
    throw new Error(`clearFirmwareGlobalIfExists: refused key ${key}`)
  }
  const body = [
    '; nxt-om-set-scratch.g — written by nxt UI (do not edit)',
    `if { exists(global.${safeKey}) }`,
    `    set global.${safeKey} = null`,
    ''
  ].join('\n')
  await uploadDwcFile(NXT_OM_SET_SCRATCH_PATH, body)
  await sendCode('M98 P"nxt-om-set-scratch.g"')
}

export function formatOmRhs(value: unknown): string {
  if (value === null || value === undefined || value === '') {
    return 'null'
  }
  if (typeof value === 'boolean') {
    return value ? 'true' : 'false'
  }
  if (typeof value === 'number') {
    return Number.isFinite(value) ? String(value) : 'null'
  }
  if (Array.isArray(value)) {
    if (value.length === 0) {
      return '""'
    }
    if (value.every((v) => typeof v === 'number')) {
      return `{${value.join(', ')}}`
    }
    // Fan-pin style string lists → CSV (matches gpio.g / formatPersistedStringVector)
    return `"${value.map((s) => String(s).replace(/"/g, '').trim()).filter(Boolean).join(',')}"`
  }
  return `"${String(value).replace(/"/g, '')}"`
}
