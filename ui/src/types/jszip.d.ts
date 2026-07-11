/**
 * Minimal ambient shim for the `jszip` package types.
 *
 * The real `jszip` package ships its own `.d.ts` and is present in DuetWebControl's
 * `node_modules` (a DWC dependency, used elsewhere in DWC via dynamic `import('jszip')`), so it
 * resolves fine at runtime/build time. The plugin type-check step (DuetWebControl's
 * `scripts/build-plugin.js`) runs against a throwaway tsconfig whose explicit `paths` only cover
 * a small whitelist of shared libs (vue, vuetify, …); bare `jszip` imports from the plugin's own
 * (temp-copied) source tree fall back to Node module resolution walking up from that temp
 * directory, which never reaches DWC's `node_modules`. This ambient declaration keeps the plugin
 * type-check self-contained without depending on that whitelist.
 */
declare module 'jszip' {
  interface JSZipObject {
    name: string
    dir: boolean
    async(type: 'string' | 'text' | 'arraybuffer' | 'uint8array' | 'blob'): Promise<string>
  }

  interface JSZip {
    files: Record<string, JSZipObject>
    file(name: string): JSZipObject | null
  }

  interface JSZipStatic {
    loadAsync(data: ArrayBuffer | Uint8Array | Blob): Promise<JSZip>
  }

  const JSZip: JSZipStatic
  export default JSZip
}
