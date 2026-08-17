import Vue from 'vue'

/**
 * Smallest possible nxt plugin export for DWC integration debugging.
 *
 * Use when "Failed to start plugin" / `...[...].call` happens before any nxt logic runs:
 * in `ui/index.ts`, export from `./src/index.minimal` instead of `./src/index`.
 *
 * - If **minimal starts**: problem is in full `index.ts` (imports, registerRoute, etc.).
 * - If **minimal also fails**: DWC build/version, plugin registration, or webpack host mismatch.
 */
export default Vue.extend({
  name: 'nxtMinimalDiagnostic',
  render(h) {
    return h('div', { staticClass: 'pa-4' }, [
      h('div', { staticClass: 'title' }, 'nxt — diagnostic minimal'),
      h('div', { staticClass: 'body-2 mt-2' }, [
        'If this message appears, DWC loaded the nxt plugin chunk. ',
        'Restore `ui/index.ts` to export `./src/index` and narrow down from there.'
      ])
    ])
  }
})
