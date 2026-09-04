# nxt Plugin Spec

nxt plugins reuse DWC `plugin.json` metadata and generate RRF macro dispatchers at build time. Runtime macros never parse JSON.

## Metadata Source

Each plugin uses DWC `plugin.json` and may include nxt runtime metadata in `data.nxt`.

### Required DWC Fields

- `id`
- `version`

### Version compatibility (catalog policy)

Catalog plugins in [`dist/plugins.catalog.json`](../dist/plugins.catalog.json) (nxt, MosAtc, ArborCTL, MosFourthAxis) should set:

- `dwcVersion`: **`"auto-minor"`** — build stamps major.minor.patch without prerelease (e.g. pin `3.7.0-beta.1` → `3.7.0`). Host must share that prefix.
- `rrfVersion`: **`"auto-major"`** — stamps major.minor (e.g. `3.7`).

Do not hardcode a full prerelease string or major.minor-only `dwcVersion` for release ZIPs.

### nxt Metadata (`data.nxt`)

- `tag` (string): must equal `nxt-plugin` to opt in.
- `enabled` (bool): defaults to `true` if omitted.
- `loadOrder` (number): lower values initialize first.
- `failureMode` (`soft` or `strict`): defaults to `soft`.
- `featureFlag` (string, optional): global name (e.g. `nxtFeatureAtc`) — init dispatch runs only when that global is true.
- `skipInitDispatch` (bool, optional): when true, init is **not** emitted in `nxt-plugin-init-dispatch.g`; load from `nxt.g` when the feature flag and SD macros are present (MosAtc pattern).
- `entrypoints` (object):
  - `init` (string, optional): one-time init macro path under `/sys`.
  - `daemon` (string, optional): periodic daemon macro path under `/sys`.
  - `pause` (string, optional): pause event hook under `/sys`.
  - `resume` (string, optional): resume event hook under `/sys`.
  - `stop` (string, optional): stop event hook under `/sys`.
  - `cancel` (string, optional): cancel event hook under `/sys`.

Example snippet:

```json
{
  "id": "nxt",
  "version": "1.0.0",
  "data": {
    "nxt": {
      "tag": "nxt-plugin",
      "enabled": true,
      "loadOrder": 10,
      "failureMode": "soft",
      "entrypoints": {
        "init": "plugins/next/next-init.g",
        "daemon": "plugins/next/next-daemon.g"
      }
    }
  }
}
```

## Generated Runtime Files

Build scripts generate dispatcher files in `/sys/nxt/plugins`:

- `nxt-plugin-init-dispatch.g`
- `nxt-plugin-daemon-dispatch.g`
- `nxt-plugin-hooks-pause.g`
- `nxt-plugin-hooks-resume.g`
- `nxt-plugin-hooks-stop.g`
- `nxt-plugin-hooks-cancel.g`

If no plugins are tagged `nxt-plugin`, generated files contain no-op comments.

## DSF Runtime Sync (Optional)

For live plugin discovery without rebuilding release assets, run the helper script
`dist/nxt_plugin_registry_sync.py` on the SBC.

- Reads a plugin registry JSON (default: `/opt/dsf/sd/sys/dwc-plugins.json`)
- Filters plugins tagged `data.nxt.tag == "nxt-plugin"`
- Regenerates all dispatcher files in `/sys/nxt/plugins` atomically
- Supports one-shot and polling modes

Example:

```bash
python3 dist/nxt_plugin_registry_sync.py --once
python3 dist/nxt_plugin_registry_sync.py --interval 5
```

This is optional. The default supported mode is fully RRF runtime with build-time
dispatcher generation.

## Future-State Template

Use `docs/future-state-plugin-template.md` for net-new plugin requirements,
catalog usage, and baseline automation patterns for external plugin repos.

For local build, test, and sibling-directory layout, see
[LOCAL_PLUGIN_BUILD_AND_TEST.md](LOCAL_PLUGIN_BUILD_AND_TEST.md).

## Runtime Integration Points

- `nxt.g` calls the generated init dispatcher once boot checks pass.
- `nxt-daemon.g` runs every daemon cycle and calls init dispatcher first, daemon dispatcher second.
- system event macros (`pause.g`, `resume.g`, `stop.g`, `cancel.g`) call corresponding generated event dispatchers when present.
- The built-in nxt plugin `plugins/next/next-init.g` echoes board-related globals (`nxtPlatformProfile`, `nxtBoardPackEntry`, `nxtBoardMotorVoltage`) for diagnostics after `nxt.g` has run; it does not load hardware board packs (that is `macros/system/nxt-board-pack-loader.g`). See [NXT_BOARD_CONFIG.md](NXT_BOARD_CONFIG.md).

## Load Semantics

Init dispatchers guard one-time execution with plugin-specific globals.

- First load: `global nxtPluginLoaded_<plugin_id> = false`
- Subsequent updates: `set global.nxtPluginLoaded_<plugin_id> = true`

Dispatcher guards:

- `init`: run only when not loaded.
- `daemon` + events: run only when loaded.

Flags are in-memory and reset on reboot.

## Build-Time Validation Rules

- Skip entries where `data.nxt.tag != "nxt-plugin"` or `enabled` is `false`.
- Sort plugins by `loadOrder` then `id`.
- Validate entrypoint files exist in staged `/sys`; for missing files:
  - `soft`: emit warning and continue
  - `strict`: fail build

## Compatibility

- **ArborCTL** (optional catalog plugin): spindle polling runs via `data.nxt` daemon entrypoint `plugins/arborctl/arborctl-daemon-hook.g` → `arborctl/arborctl-daemon.g`. Install the ArborCTL DWC ZIP (or stage sibling `../ArborCTL`) so entrypoints exist; `macros/system/daemon.g` no longer hard-codes a direct `arborctl-daemon.g` call (avoids double-polling).
- **MosFourthAxis** (optional catalog plugin): init runs via `data.nxt` + catalog `featureFlag` `nxtFeatureFourthAxis` (`plugins/mos-fourth-axis/mos-fourth-axis-init.g` → `mos-fourth-axis.g`). Mapping in `rotary-plugin-config.g` is skipped when A is already mapped (Scylla `axis-a.g`). Do not add an `M98` of that file to `config.g`.
- Legacy standalone ArborCTL installs (no nxt) still use their own `daemon.g` → `arborctl-daemon.g`.
- `nxt-daemon.g` and `user-daemon.g` remain valid.
- Missing generated dispatcher files must not break core nxt startup.
