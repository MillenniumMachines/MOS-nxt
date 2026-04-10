import Vue from 'vue'

/**
 * Smallest possible NeXT plugin export for DWC integration debugging.
 *
 * Use when "Failed to start plugin" / `...[...].call` happens before any NeXT logic runs:
 * in `ui/index.ts`, export from `./src/index.minimal` instead of `./src/index`.
 *
 * - If **minimal starts**: problem is in full `index.ts` (imports, registerRoute, etc.).
 * - If **minimal also fails**: DWC build/version, plugin registration, or webpack host mismatch.
 */
export default Vue.extend({
  name: 'NeXTMinimalDiagnostic',
  render(h) {
    return h('div', { staticClass: 'pa-4' }, [
      h('div', { staticClass: 'title' }, 'NeXT — diagnostic minimal'),
      h('div', { staticClass: 'body-2 mt-2' }, [
        'If this message appears, DWC loaded the NeXT plugin chunk. ',
        'Restore `ui/index.ts` to export `./src/index` and narrow down from there.'
      ])
    ])
  }
})
