import { defineComponent, h } from 'vue'

/**
 * Smallest possible nxt plugin export for DWC integration debugging.
 *
 * Use when "Failed to start plugin" / a plugin-load error happens before any nxt logic runs:
 * swap `ui/src/index.ts`'s default export for this module's default export temporarily.
 *
 * - If **minimal starts**: problem is in full `index.ts` (imports, registerRoute, etc.).
 * - If **minimal also fails**: DWC build/version, plugin registration, or host bundle mismatch.
 */
export default defineComponent({
  name: 'nxtMinimalDiagnostic',
  render() {
    return h('div', { class: 'pa-4' }, [
      h('div', { class: 'text-h6' }, 'nxt — diagnostic minimal'),
      h('div', { class: 'text-body-2 mt-2' }, [
        'If this message appears, DWC loaded the nxt plugin chunk. ',
        'Restore ui/src/index.ts to export the real nxt component and narrow down from there.'
      ])
    ])
  }
})
