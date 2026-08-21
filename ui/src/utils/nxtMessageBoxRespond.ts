/**
 * Build M292 acknowledgements matching DWC 3.7 / RRF 3.5+ MessageBoxDialog.
 *
 * S4 (mode 4) multiple-choice requires `M292 R{index} S{seq}` so meta `input` is set.
 * Legacy `M292 P{n}` alone does not populate `input` for S4 — Activate then appears to do nothing.
 *
 * Modes (MessageBoxMode): 0 none, 1 close, 2 okOnly, 3 okCancel, 4 multipleChoice, 5–7 inputs.
 */

export type NxtMessageBoxLike = {
  mode?: number | null
  seq?: number | null
  choices?: string[] | null
  cancelButton?: boolean | null
  message?: string | null
  title?: string | null
}

export function nxtMessageBoxButtons(messageBox: NxtMessageBoxLike | null | undefined): string[] {
  if (!messageBox) {
    return ['OK']
  }
  const mode = typeof messageBox.mode === 'number' ? messageBox.mode : 0
  if (mode === 0) {
    return []
  }
  if (mode === 1 || mode === 2) {
    return ['OK']
  }
  if (mode === 3) {
    return ['OK', 'Cancel']
  }
  // mode >= 4 (multipleChoice / inputs): prefer firmware K labels
  if (Array.isArray(messageBox.choices) && messageBox.choices.length > 0) {
    return messageBox.choices.map((c: string) => String(c))
  }
  if (mode === 4) {
    return ['OK', 'Cancel']
  }
  return ['OK']
}

/**
 * @param buttonIndex Zero-based choice index (or 0 for OK, 1 for Cancel on okCancel).
 */
export function nxtBuildM292Ack(
  messageBox: NxtMessageBoxLike | null | undefined,
  buttonIndex: number
): string {
  const seq =
    messageBox != null && typeof messageBox.seq === 'number' && Number.isFinite(messageBox.seq)
      ? messageBox.seq
      : 0
  const mode = messageBox != null && typeof messageBox.mode === 'number' ? messageBox.mode : 0

  // Multiple choice / numeric / string input — R sets `input`
  if (mode >= 4) {
    return `M292 R{${buttonIndex}} S${seq}`
  }

  // okCancel: Cancel is P1
  if (mode === 3 && buttonIndex !== 0) {
    return `M292 P1 S${seq}`
  }

  // closeOnly / okOnly / okCancel OK
  return `M292 S${seq}`
}
