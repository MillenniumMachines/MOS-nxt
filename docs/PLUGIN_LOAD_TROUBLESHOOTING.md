# nxt plugin load failure (`can't access property "call"`)

This guide assumes the failure is one of:

1. **404** — `nxt.<hash>.js` not on the DWC web root  
2. **`dwcFiles`** — plugin object missing JS/CSS paths after install  
3. **Version skew** — ZIP `dwcVersion` (e.g. **3.7.0-beta.1**) does not match host DWC, or webpack modules differ between builds

The error is always **webpack** failing while loading `dwc/js/nxt.*.js`, not RRF macros.

## Quick checks (browser, after failed Start)

Open DevTools → **Network** (disable cache):

| Request | Expected |
|---------|----------|
| `app.<hash>.js` | **200** |
| `js/nxt.<hash>.js` | **200** (not 404, not `nxt.undefined.js`) |
| `css/nxt.<hash>.css` | **200** |

Open DevTools → **Console** (if you can connect to the object model):

```javascript
// Replace store access if needed — run on DWC page when connected
const p = document.querySelector('#app')?.__vue__?.$store?.state?.machine?.model?.plugins?.get?.('nxt')
p?.dwcFiles
```

Expected:

```json
["js/nxt.<hash>.js", "css/nxt.<hash>.css"]
```

If `undefined` or `[]` → **dwcFiles** problem.  
If URLs 404 → **404** problem.  
If version error in console before `.call` → **version skew** (DWC also checks `plugin.dwcVersion`).

## 0) Fix: `Uncaught SyntaxError: missing ] in index expression`

**Usually means the browser received invalid JavaScript** (not a Vue bug). Common causes:

| Cause | What you see |
|--------|----------------|
| **Truncated upload** | Network shows 200 but file size ≠ ZIP (was ~200 KB; check Content-Length) |
| **Wrong URL still** | Response is HTML/JSON, not JS (open the script URL in a new tab) |
| **Stale hash** | Page requests `nxt.782c5978.js` but only `nxt.884dc59d.js` exists |
| **Old bloated ZIP** | Huge manifest embedded G-code with `{move.axes[0]…}` — rebuild after slim manifest |

**Checks:**

1. DevTools → Network → the `nxt.*.js` request → **Response** tab must start with `"use strict";(self["webpackChunkduetwebcontrol"]`  
2. Compare size to your ZIP: `unzip -l dist/nxt-*.zip 'dwc/nxt/js/*'`  
3. Direct URL must match `dwcFiles` (subdir layout): `/nxt/js/nxt.<hash>.js`  
4. Rebuild with current nxt (`./dist/build-plugin.sh`) — manifest no longer embeds homing file bodies.

Build runs `node --check` on the chunk before finishing.

## 1) Fix: 404 (file missing on www)

**Cause:** The browser requests `js/nxt.<hash>.js` from the **DWC web root** (`directories.web`, e.g. SBC `/opt/dsf/www/`), but the file is missing or the **hash in `dwc-plugins.json` does not match** the file on disk. Webpack then fails with the same `.call` error as version skew.

**How install maps paths (PollConnector):**

| ZIP entry (correct) | On SBC after DSF install | `plugin.dwcFiles` | Browser URL |
|-------------------|--------------------------|-------------------|-------------|
| `dwc/js/nxt.abc.js` | `0:/www/nxt/js/nxt.abc.js` | `nxt/js/nxt.abc.js` | `/nxt/js/nxt.abc.js` |

**Wrong layout (404 at `/nxt/js/…`):** `dwc/nxt/js/nxt.abc.js` in the ZIP → DSF puts files at `0:/www/nxt/nxt/js/…` while the browser requests `/nxt/js/…`. Fix: `node dist/fix-plugin-dwc-zip-layout.cjs dist/nxt-*.zip` or rebuild.

**Install timeout:** The ZIP also uploads many `sd/sys/` macros. On slow links the install can time out before `dwc/` lands on `www` → same 404. Retry install; in DWC **Files → System** confirm `www/nxt/js/nxt.<hash>.js` exists.

`plugin.json` in the ZIP is **not** uploaded — only `dwc/*` and `sd/*`.

**Install via DWC:** Release builds ship a single `nxt-<version>.zip`. Upload it in **Settings → Plugins** so `dwc/js` and `dwc/css` land on the HTTP www root. Copying only `sd/sys` macros from the ZIP (or an old SD-card layout) leaves DWC assets missing → **404** until the plugin ZIP is installed (or you manually copy `dwc/js` and `dwc/css` into the www tree).

**Trace locally:**

```bash
node dist/trace-plugin-404.mjs dist/nxt-*.zip
# After downloading 0:/sys/dwc-plugins.json from the printer:
node dist/trace-plugin-404.mjs dist/nxt-*.zip dwc-plugins.json
```

**Steps:**

1. **Uninstall** nxt in DWC → Settings → Plugins (if listed).  
2. **Re-upload** the latest `dist/nxt-*.zip` and wait until install finishes.  
3. On the printer/SBC, confirm files exist next to `app.*.js` (paths are relative to the DWC web root):

   - `js/nxt.<hash>.js`  
   - `css/nxt.<hash>.css`  

4. In the browser, open directly:  
   `http://<printer-host>/js/nxt.<hash>.js`  
   (use the hash from the ZIP — run `node dist/verify-plugin-zip.mjs dist/nxt-*.zip`).  
5. **Hard refresh** DWC (Ctrl+Shift+R).

**Build-side:** Rebuild so the ZIP only contains runtime assets:

```bash
./dist/build-plugin.sh /path/to/DuetWebControl   # same major line as printer
node dist/verify-plugin-zip.mjs dist/nxt-*.zip
```

## 2) Fix: `dwcFiles` empty or wrong

**Cause:** DWC resolves the script URL from `plugin.dwcFiles` when `window.pluginBeingLoaded` is set. On **stock** DWC (no nxt baked into `app.js`), if `dwcFiles` is empty, webpack requests **`js/nxt.undefined.js`** → same `.call` error.

**Steps:**

1. **Disable auto-load** while fixing: DWC → Settings → uncheck **Start** for nxt (or remove from enabled plugins), refresh once.  
2. **Uninstall** nxt plugin completely.  
3. **Reinstall** the ZIP; confirm install completes without errors.  
4. Verify persistence on SD:

   - File: **`0:/sys/dwc-plugins.json`**  
   - Entry: **`plugins.nxt.dwcFiles`** must list `js/nxt.<hash>.js` and `css/nxt.<hash>.css`.

5. **Then** Start the plugin from Settings (not only via old browser localStorage auto-enable).

**Do not** rely on built-in nxt in `DuetWebControl/src/plugins/imports.ts` unless `src/plugins/nxt` symlink exists (`./dist/setup-dwc-dev-symlink.sh`).

## 3) Fix: version skew

**Cause:** The nxt chunk expects **~45 webpack modules** from host `app.js`. If the ZIP was built with a different DWC than the printer serves (e.g. plugin built on **3.6.2** but host is **3.7.x**, or a different patch webpack layout), a module is `undefined` → `.call` error.

**DWC version gate (first line of defence):** Shipped ZIPs set `plugin.json` **`dwcVersion` to the exact build version** (e.g. `"3.7.0-beta.1"`), not just `"3.7"`. DWC should refuse load with a clear message:

`Plugin nxt requires incompatible DWC version (need 3.7.0-beta.1, got 3.6.2)`

If you still only see `.call` with no version message, the host may match semver but webpack modules still differ — use the diagnose step below.

**Steps:**

1. Note **exact** host DWC version (footer / about / `package.json` if you have the tree), e.g. **3.7.0-beta.1** or **3.6.2** (on nxt `v0.6.0` line).  
2. Inspect the ZIP you installed:

   ```bash
   unzip -p dist/nxt-*.zip plugin.json | jq '.dwcVersion'
   ```

   Host and this value must match **exactly**.

3. Build against the pinned reference (or the same version as your printer):

   ```bash
   ./dist/ci-fetch-dwc.sh                    # optional: fetch ci/dwc-build-ref → dwc-build/
   ./dist/verify-dwc-build-alignment.sh /path/to/DuetWebControl-3.7.0-beta.1
   ./dist/build-plugin.sh /path/to/DuetWebControl-3.7.0-beta.1
   ```

   Build output prints: `Plugin ZIP requires host DWC version: 3.7.0-beta.1` (on branch `v0.7.0`).

4. If the printer runs another **3.7.x patch**, rebuild the plugin using **that** DWC tree (update `ci/dwc-build-ref` only when intentionally moving the whole project pin).

5. Confirm webpack modules (catches skew that semver hides):

   ```bash
   node dist/diagnose-plugin-chunk.mjs dist/nxt-*.zip /path/to/host/app.<hash>.js
   ```

   **MISSING** lines → rebuild plugin against the host’s DWC sources.

6. Reinstall ZIP + hard refresh (**Ctrl+Shift+R**).

## Local dev (not ZIP)

`npm run dev` **cannot** load an external plugin ZIP. Use:

```bash
./dist/setup-dwc-dev-symlink.sh /path/to/DuetWebControl
cd /path/to/DuetWebControl && npm run dev
```

## Tooling

| Command | Purpose |
|---------|---------|
| `node dist/verify-plugin-zip.mjs dist/nxt-*.zip` | ZIP has one JS + one CSS; shows expected `dwcFiles` |
| `node dist/trace-plugin-404.mjs dist/nxt-*.zip [dwc-plugins.json]` | Install URL mapping; hash mismatch vs printer manifest |
| `node dist/diagnose-plugin-chunk.mjs dist/nxt-*.zip app.<hash>.js` | Host module + URL resolution analysis |
