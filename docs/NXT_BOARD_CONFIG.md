# nxt board and machine configuration (nxt-config)

nxt ships vendored **board packs** (controller pins, drives, fans) and **machine packs** (motion, limits, homing sources). On the SD card they live under `0:/sys/nxt-config/` (from `macros/nxt-config/` at build time).

## Directory layout

```
nxt-config/
  board/
    <shortName>/              RRF boards[].shortName (e.g. cdy3_f4, scylla1_0_h723)
      entry.g                 Board load chain
      pinmap.json             Named pins + free pins for UI assignment
      endstops.g, drives.g, fans.g, spindle.g, …
      motor-24v/ | motor-48v/ Optional supply variants

  machine/
    <machineId>/              global.nxtPlatformProfile (e.g. v1.5, v1.6, v2.0, custom)
      OVERVIEW.txt
      entry.g                 Machine motion chain (no homing at boot)
      movement.g, limits.g, general.g, network-default.g
      drives-overlay.g, endstops.g, steps.g   Custom: M584/M569/M906/M574/M92 overlays
      homeall.g, homex.g, …   Deploy-only → 0:/sys/
      sys-deploy-manifest.txt
```

Build-time manifest: `dist/generate-nxt-config-manifest.mjs` → `ui/src/generated/nxtConfigManifest.json`.

| Machine | Homing deploy | Boards (shared) |
|---------|---------------|-----------------|
| `v1.5` | Y → max, Z steps 1600 | `cdy3_f4`, `scylla1_0_h723` 24/48 V |
| `v1.6` | Y → min (Y0), Z steps 800 | same board tree |
| `v2.0` | Same as v1.6 for now (diverge when hardware differs) | same board tree |
| `custom` | Generated home*.g from endstop Min/Max; full Custom editor (`nxtCustom*`) | same board tree |

**Custom platform:** Configuration edits travel, endstop pins/sides, steps/mm, drive map, `M569` directions, and `M906` currents. Values persist in `nxt-user-vars.g`; Save also regenerates `machine/custom/` overlays and deploys direction-aware `home*.g`. Overlays run **after** the board pack (board files stay stock).

**Homing:** [NXT_BOARD_HOMING.md](NXT_BOARD_HOMING.md)

## Two load paths

| Path | What runs | When |
|------|-----------|------|
| **Board + machine boot** | `M98` board `entry.g`, then `machine/<id>/entry.g` | Boot when `nxt-board-bootstrap.requested` exists |
| **Homing deploy** | Copies `machine/<id>/home*.g` → `0:/sys/homeall.g`, etc. | Configuration **Apply platform sys files** only |

Homing macros are **not** `M98`'d at boot.

## Boot order (firmware)

1. `config.g` → `M98 P"nxt.g"`.
2. `nxt.g` → `nxt-vars.g` → … → `nxt-user-vars.g` → **`nxt-board-pack-loader.g`** → `nxt-boot.g` → …
3. Loader: `nxt-board-pack-resolve.g` → board entry → `machine/<nxtPlatformProfile>/entry.g` → optional `nxt-user-pinmap.g`.

Resolver path: `nxt-config/board/<shortName>/[motor-24v|motor-48v/]entry.g`.  
Legacy shim (one release): `nxt-config/<platform>/boards/...` if new path missing.

## Network configuration

Machine packs load network settings from **`machine/<id>/entry.g`** (not board packs):

1. If **`0:/sys/network.g`** exists → `M98 P"network.g"` (user override; nxt does not ship this file).
2. Else → `M98 P"nxt-config/machine/<id>/network-default.g"` (vendored default).

**`network-default.g`** (v1.5 / v1.6 / v2.0 / custom) enables WiFi AP mode and **`M586 P0 S1`** (HTTP) on **standalone** boards. On **RRF 3.7+**, HTTP is off by default — the default file satisfies DWC and nxt Configuration saves without editing root `config.g`. In **SBC mode** (`exists(sbc)`), it skips `M552`/`M586` so boot does not error; the Pi/DSF owns networking.

| Situation | Action |
|-----------|--------|
| Stock Milo + bootstrap + no `network.g` | No change — default applies at boot |
| Custom **`network.g`** on SD | Audit for `M586 P0 S1` after RRF 3.7 upgrade |
| Bootstrap skipped | HTTP must be set in `config.g`, `network.g`, or `user-config.g` |

The Configuration UI does **not** deploy `network.g` (only homing via sys-deploy). See [RRF_3.7_MIGRATION.md](RRF_3.7_MIGRATION.md).

## Globals

| Global | Purpose |
|--------|---------|
| `nxtPlatformProfile` | Machine id → `nxt-config/machine/<id>/` |
| `nxtBoardShortNameOverride` | Optional board shortName override |
| `nxtBoardMotorVoltage` | `24` or `48` for motor variant dirs |
| `nxtBoardPackShortName` | Set during pack load (machine `endstop-y.g`) |
| `nxtBoardPackEntry` | Last board entry path loaded |
| `nxtBoardPackExpectedEntry` | Saved board entry path (Configuration Save) |

## Pack path convention

| Case | Board entry path |
|------|------------------|
| Single pack | `nxt-config/board/<shortName>/entry.g` |
| 24 V | `.../motor-24v/entry.g` |
| 48 V | `.../motor-48v/entry.g` |

Machine must exist on SD: `0:/sys/nxt-config/machine/<id>/OVERVIEW.txt`.

## Pin maps and free pins

Each board ships `pinmap.json` (`assigned` + `free`) with human-readable labels from RRF pin names (e.g. Scylla `mist`, `coolant`, `relay`, `aux0`–`aux2`, `probe`, `tool`).

Configuration dropdowns list **free** named pins (Mist, Coolant, Relay, Aux, Fan 2 / heaters on CDYv3, Probe, Toolsetter). Pins already assigned to another role are shown **disabled**. Clear a select to unassign.

Board packs create matching `M950 J…` ports in `gpio.g` (and Scylla `motor-*/gpio-aux.g`) so Mist/Coolant/Relay/Aux map to stable gpOut indices for `M42`.

### Scylla A axis (fourth / rotary)

| Item | Scylla mapping |
|------|----------------|
| Physical driver | Drive **3** (4th TMC5160; `M569.9 P0.3` sense already in `drives.g`) |
| Endstop min | `D.15` / `amin` (PD_15) |
| Endstop max | `D.13` / `amax` (PD_13) |
| Board fragment | `nxt-config/board/scylla1_0_h723/axis-a.g` |

**Enable:** Configuration → **Fourth Axis (A / Rotary)** → enable `nxtFeatureFourthAxis` → **Save**, then reboot with board bootstrap. MOS import may also set the flag from `mosFAE`.

**Still from MosFourthAxis:** steps/° (`M92 A` / `M4806`), soft limits, speeds, and `homea.g`. If you also `M98` `rotary-plugin-config.g`, remove duplicate `M584 A` / `M574 A` / `M569 P3` lines from that file so they are not applied twice.

## Adding hardware

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

1. **New board:** `macros/nxt-config/board/<shortName>/` with `entry.g`, `pinmap.json`, fragments.
2. **New machine:** `macros/nxt-config/machine/<id>/` with `entry.g`, homing macros, `sys-deploy-manifest.txt`.
3. Run `node dist/generate-nxt-config-manifest.mjs`.
4. Reinstall plugin ZIP.

## References

- [plugin-spec.md](plugin-spec.md)
- `macros/nxt-config/board-pack-index.txt`
- `macros/nxt-config/ATTRIBUTION.txt`
