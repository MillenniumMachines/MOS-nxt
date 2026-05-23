# NeXT board configuration (nxt/config)

NeXT ships vendored **board packs**: RepRapFirmware macro trees for machine platforms and controller boards. On the SD card they live under `0:/sys/nxt/config/` (synced from the repo’s `macros/nxt-config/` at build time).

## Directory layout

Each **platform** is a top-level folder (directory name = `global.nxtPlatformProfile` value):

```
nxt-config/
  <platformId>/          e.g. v1.5, v1.6_v2
    OVERVIEW.txt
    common/              shared fragments + homing macros for sys deploy
      general.g
      movement.g
      network-default.g
      homeall.g, homex.g, homey.g, homez.g
      sys-deploy-manifest.txt
    boards/
      <shortName>/entry.g
      <shortName>/motor-24v/entry.g   (optional)
```

Platforms are discovered at **build time** into `ui/src/generated/nxtConfigManifest.json` (see `dist/generate-nxt-config-manifest.mjs`). The Configuration panel platform list and board entries come from that manifest.

| Platform | `common/` homing | Board packs |
|----------|------------------|-------------|
| `v1.5` | Milo v1.5 baseline (Y → max) | `cdy3_f4`, `scylla1_0_h723` motor 24/48 V |
| `v1.6_v2` | v1.6 / v2.0 (Y → Y0, Z reversed, Z800) | Same board tree as v1.5 |
| `atlas` | (not shipped yet) | placeholder only |

**Homing requirements (X/Y/Z per platform):** [NXT_BOARD_HOMING.md](NXT_BOARD_HOMING.md)

## Two load paths

| Path | What runs | When |
|------|-----------|------|
| **Pack loader** | `M98` board `entry.g` + `common/` fragments (drives, limits, spindle, …) | Boot when `0:/sys/nxt-board-bootstrap.requested` exists |
| **Sys homing deploy** | Copies `common/home*.g` → `0:/sys/homeall.g`, etc. | Configuration UI **Apply platform sys files** |

DWC **Home All** uses `0:/sys/homeall.g`, not the pack tree directly.

## Save / Reload contract (Configuration UI)

**Save Configuration** writes board intent to `nxt-user-vars.g` and syncs SD sentinel files:

| Global | Purpose |
|--------|---------|
| `nxtPlatformProfile` | Platform folder under `nxt/config/` |
| `nxtBoardShortNameOverride` | Optional board id override |
| `nxtBoardMotorVoltage` | `24` or `48` for `motor-24v` / `motor-48v` packs |
| `nxtBoardBootstrapMode` | `"auto"` or `"off"` (intent) |
| `nxtBoardPackExpectedEntry` | Computed pack path at Save (for drift checks) |
| `nxtBoardSysDeployPlatform` | Platform whose `home*.g` were last deployed to `0:/sys/` |
| `nxtBoardPackEntry` | Set at boot by loader (last path actually loaded) |

| Bootstrap mode | Save action on SD |
|----------------|-------------------|
| **Auto** | Creates `0:/sys/nxt-board-bootstrap.requested`; removes `.skip` if present |
| **Off** | Deletes `nxt-board-bootstrap.requested` |

**Reload** runs `M98 P"nxt-user-vars.g"`, refreshes the form, checks bootstrap sentinels vs mode, compares `nxtBoardPackExpectedEntry` vs `nxtBoardPackEntry`, and scans `nxt/config/` against the bundled manifest.

Legacy global `nxtScyllaMotorVoltage` is still read by the resolver if `nxtBoardMotorVoltage` is unset.

## Load order (firmware)

1. **`config.g`** should invoke `M98 P"nxt.g"` per NeXT install instructions.
2. **`nxt.g`** loads `nxt-vars.g`, optional MOS import, `nxt-tooltable.g`, then **`nxt-user-vars.g`** (or config-pending mode if missing).
3. Optional **`nxt-user-overrides.g`** (probe repeatability tuning).
4. **`nxt-board-pack-loader.g`** when **opt-in** is present — convention resolver → board `entry.g`.
5. **`nxt-boot.g`** and plugin init.

Board packs load **after** `nxt-user-vars.g` so `nxtPlatformProfile`, `nxtBoardMotorVoltage`, and related globals are available.

## Opt-in, opt-out, manual override

- **Auto load (recommended):** Configuration → bootstrap **Auto** → **Save** (creates `nxt-board-bootstrap.requested`).
- **Hard disable:** create `0:/sys/nxt-board-bootstrap.skip` (pack never loads while skip exists).
- **Manual chain:** add `0:/sys/nxt-user-board.g`; the loader runs this file and returns. See `macros/system/nxt-user-board.g.example`.

## Pack path convention (`nxt-board-pack-resolve.g`)

The loader delegates to **`nxt-board-pack-resolve.g`**, which builds paths under `nxt/config/<platform>/boards/<shortName>/`:

**M98 and local variables:** RepRapFirmware does **not** pass `var.*` from a parent macro into a child called with `M98`. The loader therefore copies the board id into `global.nxtBoardPackResolveBrd` before calling the resolver. Do not use `var.brd` inside the resolver unless you set it there from that global.

| Case | Path |
|------|------|
| Single pack | `.../boards/<shortName>/entry.g` |
| 24 V motor variant | `.../motor-24v/entry.g` when `nxtBoardMotorVoltage == 24` |
| 48 V motor variant | `.../motor-48v/entry.g` when `nxtBoardMotorVoltage == 48` |

Platform must exist on SD: `0:/sys/nxt/config/<platform>/OVERVIEW.txt`.

If `nxtBoardPackExpectedEntry` is set and differs from the resolved path, the resolver logs a warning before `M98`.

## DWC UI

The Configuration panel:

- Lists platforms from `nxtConfigManifest.json` (directory-driven).
- Shows deployable `0:/sys/` files and board `entry.g` paths for the selected platform.
- **Save Configuration** — persists globals + bootstrap sentinel sync.
- **Check SD board packs** — compares manifest to on-SD tree.
- **Apply platform sys files** — homing macros (see [NXT_BOARD_HOMING.md](NXT_BOARD_HOMING.md)).

Path previews use `ui/src/utils/nxtBoardManifest.ts`, aligned with the firmware resolver.

## Adding a new platform

1. Create `macros/nxt-config/<platformId>/` with `OVERVIEW.txt`, `boards/**/entry.g`, optional `common/`.
2. Add `common/sys-deploy-manifest.txt` if homing files should deploy to `0:/sys/`.
3. Run `node dist/generate-nxt-config-manifest.mjs` (validates paths; writes `board-pack-index.txt`).
4. Reinstall plugin ZIP so SD has the new tree.
5. Document homing in [NXT_BOARD_HOMING.md](NXT_BOARD_HOMING.md).

No firmware loader edit is required if paths follow the convention above.

## References

- [plugin-spec.md](plugin-spec.md) — plugin dispatchers and `next-init.g`.
- `macros/nxt-config/board-pack-index.txt` — build-time index of all pack entry paths.
- `macros/nxt-config/ATTRIBUTION.txt` — upstream Millennium Machines paths.
