# NeXT plugin load failure (`can't access property "call"`)

This guide assumes the failure is one of:

1. **404** — `NeXT.<hash>.js` not on the DWC web root  
2. **`dwcFiles`** — plugin object missing JS/CSS paths after install  
3. **Version skew** — ZIP `dwcVersion` (e.g. **3.6.2**) does not match host DWC, or webpack modules differ between builds

The error is always **webpack** failing while loading `dwc/js/NeXT.*.js`, not RRF macros.

## Quick checks (browser, after failed Start)

Open DevTools → **Network** (disable cache):

| Request | Expected |
|---------|----------|
| `app.<hash>.js` | **200** |
| `js/NeXT.<hash>.js` | **200** (not 404, not `NeXT.undefined.js`) |
| `css/NeXT.<hash>.css` | **200** |

Open DevTools → **Console** (if you can connect to the object model):

```javascript
// Replace store access if needed — run on DWC page when connected
const p = document.querySelector('#app')?.__vue__?.$store?.state?.machine?.model?.plugins?.get?.('NeXT')
p?.dwcFiles
```

Expected:

```json
["js/NeXT.<hash>.js", "css/NeXT.<hash>.css"]
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
| **Stale hash** | Page requests `NeXT.782c5978.js` but only `NeXT.884dc59d.js` exists |
| **Old bloated ZIP** | Huge manifest embedded G-code with `{move.axes[0]…}` — rebuild after slim manifest |

**Checks:**

1. DevTools → Network → the `NeXT.*.js` request → **Response** tab must start with `"use strict";(self["webpackChunkduetwebcontrol"]`  
2. Compare size to your ZIP: `unzip -l dist/NeXT-*.zip 'dwc/NeXT/js/*'`  
3. Direct URL must match `dwcFiles` (subdir layout): `/NeXT/js/NeXT.<hash>.js`  
4. Rebuild with current NeXT (`./dist/build-plugin.sh`) — manifest no longer embeds homing file bodies.

Build runs `node --check` on the chunk before finishing.

## 1) Fix: 404 (file missing on www)

**Cause:** The browser requests `js/NeXT.<hash>.js` from the **DWC web root** (`directories.web`, e.g. SBC `/opt/dsf/www/`), but the file is missing or the **hash in `dwc-plugins.json` does not match** the file on disk. Webpack then fails with the same `.call` error as version skew.

**How install maps paths (PollConnector):**

| ZIP entry (correct) | On SBC after DSF install | `plugin.dwcFiles` | Browser URL |
|-------------------|--------------------------|-------------------|-------------|
| `dwc/js/NeXT.abc.js` | `0:/www/NeXT/js/NeXT.abc.js` | `NeXT/js/NeXT.abc.js` | `/NeXT/js/NeXT.abc.js` |

**Wrong layout (404 at `/NeXT/js/…`):** `dwc/NeXT/js/NeXT.abc.js` in the ZIP → DSF puts files at `0:/www/NeXT/NeXT/js/…` while the browser requests `/NeXT/js/…`. Fix: `node dist/fix-plugin-dwc-zip-layout.cjs dist/NeXT-*.zip` or rebuild.

**Install timeout:** The ZIP also uploads many `sd/sys/` macros. On slow links the install can time out before `dwc/` lands on `www` → same 404. Retry install; in DWC **Files → System** confirm `www/NeXT/js/NeXT.<hash>.js` exists.

`plugin.json` in the ZIP is **not** uploaded — only `dwc/*` and `sd/*`.

**SD full release trap:** `dist/release.sh` unpacks `dwc/*` into `sd/dwc/` on the SD card zip. That puts files at `0:/dwc/js/…` on the card, **not** on the HTTP www root. If you only copied the SD release and have `0:/sys/dwc-plugins.json` listing `js/NeXT.<hash>.js`, DWC will still **404** until you **install the plugin ZIP** in Settings → Plugins (or manually copy `dwc/js` and `dwc/css` into the www tree).

**Trace locally:**

```bash
node dist/trace-plugin-404.mjs dist/NeXT-*.zip
# After downloading 0:/sys/dwc-plugins.json from the printer:
node dist/trace-plugin-404.mjs dist/NeXT-*.zip dwc-plugins.json
```

**Steps:**

1. **Uninstall** NeXT in DWC → Settings → Plugins (if listed).  
2. **Re-upload** the latest `dist/NeXT-*.zip` and wait until install finishes.  
3. On the printer/SBC, confirm files exist next to `app.*.js` (paths are relative to the DWC web root):

   - `js/NeXT.<hash>.js`  
   - `css/NeXT.<hash>.css`  

4. In the browser, open directly:  
   `http://<printer-host>/js/NeXT.<hash>.js`  
   (use the hash from the ZIP — run `node dist/verify-plugin-zip.mjs dist/NeXT-*.zip`).  
5. **Hard refresh** DWC (Ctrl+Shift+R).

**Build-side:** Rebuild so the ZIP only contains runtime assets:

```bash
./dist/build-plugin.sh /path/to/DuetWebControl   # same major line as printer
node dist/verify-plugin-zip.mjs dist/NeXT-*.zip
```

## 2) Fix: `dwcFiles` empty or wrong

**Cause:** DWC resolves the script URL from `plugin.dwcFiles` when `window.pluginBeingLoaded` is set. On **stock** DWC (no NeXT baked into `app.js`), if `dwcFiles` is empty, webpack requests **`js/NeXT.undefined.js`** → same `.call` error.

**Steps:**

1. **Disable auto-load** while fixing: DWC → Settings → uncheck **Start** for NeXT (or remove from enabled plugins), refresh once.  
2. **Uninstall** NeXT plugin completely.  
3. **Reinstall** the ZIP; confirm install completes without errors.  
4. Verify persistence on SD:

   - File: **`0:/sys/dwc-plugins.json`**  
   - Entry: **`plugins.NeXT.dwcFiles`** must list `js/NeXT.<hash>.js` and `css/NeXT.<hash>.css`.

5. **Then** Start the plugin from Settings (not only via old browser localStorage auto-enable).

**Do not** rely on built-in NeXT in `DuetWebControl/src/plugins/imports.ts` unless `src/plugins/NeXT` symlink exists (`./dist/setup-dwc-dev-symlink.sh`).

## 3) Fix: version skew

**Cause:** The NeXT chunk expects **~45 webpack modules** from host `app.js`. If the ZIP was built with a different DWC than the printer serves (e.g. plugin built on **3.6.2** but host is **3.7.x**, or a different **3.6.x** webpack layout), a module is `undefined` → `.call` error.

**DWC version gate (first line of defence):** Shipped ZIPs now set `plugin.json` **`dwcVersion` to the exact build version** (e.g. `"3.6.2"`), not just `"3.6"`. DWC should refuse load with a clear message:

`Plugin NeXT requires incompatible DWC version (need 3.6.2, got 3.7.0)`

If you still only see `.call` with no version message, the host may match semver but webpack modules still differ — use the diagnose step below.

**Steps:**

1. Note **exact** host DWC version (footer / about / `package.json` if you have the tree), e.g. **3.6.2** or **3.7.2**.  
2. Inspect the ZIP you installed:

   ```bash
   unzip -p dist/NeXT-*.zip plugin.json | jq '.dwcVersion'
   ```

   Host and this value must match **exactly**.

3. Build against the pinned reference (or the same version as your printer):

   ```bash
   ./dist/ci-fetch-dwc.sh                    # optional: fetch ci/dwc-build-ref → dwc-build/
   ./dist/verify-dwc-build-alignment.sh /path/to/DuetWebControl-3.6.2
   ./dist/build-plugin.sh /path/to/DuetWebControl-3.6.2
   ```

   Build output prints: `Plugin ZIP requires host DWC version: 3.6.2`.

4. If the printer runs another **3.6.x patch** (e.g. **3.6.5**), rebuild the plugin using **that** DWC tree (update `ci/dwc-build-ref` only when intentionally moving the whole project pin).

5. Confirm webpack modules (catches skew that semver hides):

   ```bash
   node dist/diagnose-plugin-chunk.mjs dist/NeXT-*.zip /path/to/host/app.<hash>.js
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
| `node dist/verify-plugin-zip.mjs dist/NeXT-*.zip` | ZIP has one JS + one CSS; shows expected `dwcFiles` |
| `node dist/trace-plugin-404.mjs dist/NeXT-*.zip [dwc-plugins.json]` | Install URL mapping; hash mismatch vs printer manifest |
| `node dist/diagnose-plugin-chunk.mjs dist/NeXT-*.zip app.<hash>.js` | Host module + URL resolution analysis |
