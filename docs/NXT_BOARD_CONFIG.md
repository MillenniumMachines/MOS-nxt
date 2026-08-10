# nxt board and machine configuration (nxt-config)

nxt ships vendored **board packs** (controller pins, drives, fans) and **machine packs** (motion, limits, homing sources). On the SD card they live under `0:/sys/nxt-config/` (from `macros/nxt-config/` at build time).

## Directory layout

```
nxt-config/
  board/
    <shortName>/              RRF boards[].shortName (e.g. scylla1_0_h723)
      entry.g                 Board load chain
      pinmap.json             Named pins + free pins for UI assignment
      endstops.g, drives.g, fans.g, spindle.g, …
      motor-24v/ | motor-48v/ Optional supply variants

  machine/
    <machineId>/              global.nxtPlatformProfile (e.g. v1.5, v1.6, v2.0, custom)
      OVERVIEW.txt
      entry.g                 Machine motion chain (no homing at boot)
      movement.g, limits.g, general.g, network-default.g, steps.g
      drives-dir.g, endstops.g   Stock Milo: M569 dirs + M574 min/max (after board)
      drives-overlay.g, endstops.g, steps.g   Custom stubs → nxt-user-custom/
      homeall.g, homex.g, …   Deploy-only → 0:/sys/
      sys-deploy-manifest.txt
```

**Ownership:** Board packs own controller **pins**, sense resistors, `M584`/`M350`/`M906`. Stock machine packs own XYZ **driver direction** (`drives-dir.g`) and endstop **min/max** (`endstops.g`, re-issuing `M574` with board pins). Custom regenerates full overlays under `0:/sys/nxt-user-custom/`.
Build-time manifest: `dist/generate-nxt-config-manifest.mjs` → `ui/src/generated/nxtConfigManifest.json`.

| Machine | Homing deploy | Boards (shared) |
|---------|---------------|-----------------|
| `v1.5` | Y → max, Z steps 1600 | `scylla1_0_h723` 24/48 V |
| `v1.6` | Y → min (Y0), Z steps 800 | same board tree |
| `v2.0` | Same as v1.6 for now (diverge when hardware differs) | same board tree |
| `custom` | Generated home*.g from endstop Min/Max; full Custom editor (`nxtCustom*`) | same board tree |

**RRF 3.7:** Fly CDYv3 (`cdy3_f4`) is **not** supported and is not shipped. Use Scylla packs only.

**Custom platform:** Configuration edits travel (XYZ required; A optional but complete when used), multi-pin endstops, steps/mm, drive map, `M569` directions, and `M906` currents. Values persist in `nxt-user-vars.g`; Save regenerates overlays under **`0:/sys/nxt-user-custom/`** (install-safe; not overwritten by the plugin ZIP) and deploys direction-aware `home*.g` (including `homea.g` when A is set). Stock `machine/custom/` stubs `M98` those user files. Overlays run **after** the board pack (board files stay stock). After upgrading from an older build that wrote overlays into `nxt-config/machine/custom/`, Save once to migrate.

Keep the SBC `global` OM under ~8KB — see [OM_GLOBAL_SIZE.md](OM_GLOBAL_SIZE.md).

**Homing:** [NXT_BOARD_HOMING.md](NXT_BOARD_HOMING.md)

## Two load paths

| Path | What runs | When |
|------|-----------|------|
| **Board + machine boot** | `M98` board `entry.g`, then `machine/<id>/entry.g` | Boot when `nxt-board-bootstrap.requested` exists |
| **Homing deploy** | Copies `machine/<id>/home*.g` → `0:/sys/homeall.g`, etc. | Configuration **Apply platform sys files** only |

Homing macros are **not** `M98`'d at boot.

## Boot order (firmware)

1. `config.g` → `M98 P"nxt.g"`.
2. `nxt.g` → `nxt-vars.g` → gated **`nxt-custom-globals.g`** → optional MOS import (nested skips double custom/user-vars load) → **`nxt-tooltable.g`** → **`nxt-probe-wcs.g`** (if `!nxtWPCtrPos`) → align WCS/OT → **`nxt-user-vars.g`** → **`nxt-board-pack-loader.g`** → tools → **`nxt-boot.g`** (probe sync only; sets `nxtBootOk`) → plugin-init once → RGB colours + single `M950` → **`nxt-user-overrides.g` (last)** → **`nxtLoaded`**.
3. Loader: `nxt-board-pack-resolve.g` → board entry → `machine/<nxtPlatformProfile>/entry.g` → optional `nxt-user-pinmap.g`.

Board `rgb.g` sets pin/strip only; strip type (`nxtRGBType`), colour order (`nxtRGBOrder`), and LED count (`nxtRGBCount`) come from Configuration → `nxt-user-vars.g`. `nxt.g` owns the post-colour `M950` (`T`/`K`/`U`). Daemon caches plugin hook paths and runs plugin-init at most once (`nxtPluginsInited`).

Configuration / Calibration Save and Custom Apply share `persistNxtUserConfig` (bootstrap + custom sentinels idempotent).

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
| `nxtBoardPackShortName` | Set during pack resolve (`nxt-board-pack-resolve.g`) |
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

Each board ships `pinmap.json` (`assigned` + `free`) with human-readable labels from RRF pin names (e.g. Scylla `mist`, `coolant`, `aux0`–`aux2`, `relay`, `probe`, `tool`).

**Scylla probes:** pack `entry.g` loads toolsetter K1 (`PE_7`) and touch probe K0 (`PE_15`, P5) from voltage-specific `toolsetter.g` / `touchprobe.g`, unless overridden by `0:/sys/toolsetter.g` or `0:/sys/touchprobe.g`. Touch polarity follows `nxtTouchProbeInvert`.

Configuration dropdowns list **free** named pins (Mist, Coolant, Relay, Aux, Probe, Toolsetter). Pins already assigned to another role or selected as **fans** are shown **disabled**. Clear a select to unassign.

### Scylla named outputs (board-owned)

Create order and preferred **gpOut** indices when the pin is **not** a fan ([`gpio.g`](../macros/nxt-config/board/scylla1_0_h723/gpio.g)). Aux0–2 and relay are **24 V** rails (independent of motor pack voltage):

| Order | Pin | Preferred `M950 P` | Default role (null-only) |
|------|-----|--------------------|---------------------------|
| 1 | aux0 | P0 | `nxtAux1ID` (UI: Aux 0) |
| 2 | aux1 | P1 | `nxtAux2ID` (UI: Aux 1) |
| 3 | aux2 | P2 | `nxtAux3ID` (UI: Aux 2) |
| 4 | coolant | P3 | `nxtCoolantFloodID` |
| 5 | mist | P4 | `nxtCoolantMistID` |
| 6 | relay | P5 | `nxtRelayID` |

After create, [`gpio-role-defaults.g`](../macros/nxt-config/board/scylla1_0_h723/gpio-role-defaults.g) fills those globals **only when still null** (user-vars win).

**Fans:** `global.nxtBoardFanPins` lists aliases created as `M950 F` instead of `M950 P`. Default when null: always **`aux0`** (any motor voltage). Persist as a CSV string (`"aux0"` / `"mist,aux1"`); explicit none is `""`. Legacy single-pin vectors still work at boot. Hold-to-test uses `M106` for fan-mode pins and `M42` for gpOut roles.

### Scylla UART header (PD8 / PD9)

Firmware `serial.aux2`: TX=`PD_8` (`tx3`), RX=`PD_9` (`rx3`). [`uart.g`](../macros/nxt-config/board/scylla1_0_h723/uart.g) issues `M575` when `nxtUartDevice` ≠ 0 (0=off, 1=PanelDue, 2=BTT TFT, 3=pendant). On RRF 3.7.x nxt uses **P3** for aux2 (verify on hardware). One primary device in UI; further devices can daisy-chain on the same TX/RX later.

### Scylla A axis (fourth / rotary)

| Item | Scylla mapping |
|------|----------------|
| Physical driver | Drive **3** (4th TMC5160; `M569.9 P0.3` sense already in `drives.g`) |
| Endstop min | `D.15` / `amin` (PD_15) |
| Endstop max | `D.13` / `amax` (PD_13) |
| Board fragment | `nxt-config/board/scylla1_0_h723/axis-a.g` |

**Enable:** Configuration → **Fourth Axis (A / Rotary)** → enable `nxtFeatureFourthAxis` → **Save**, then reboot with board bootstrap. MOS import may also set the flag from `mosFAE`.

**MosFourthAxis on boot:** When the feature flag is on, [`nxt.g`](../macros/system/nxt.g) soft-loads (with `fileexists`) `0:/sys/mos-fourth-axis.g`, or else `plugins/mos-fourth-axis/mos-fourth-axis-init.g` + `M4800` if present. Missing macros only `echo` a warning — boot continues.

**Still from MosFourthAxis:** steps/° (`M92 A` / `M4806`), soft limits, speeds, and `homea.g`. Do **not** also `M98` `rotary-plugin-config.g` when Scylla `axis-a.g` already mapped A (duplicate `M584` / `M574` / `M569`).

## Adding hardware

## Opt-in, opt-out, manual override

- **Auto load (recommended):** Configuration → bootstrap **Auto** → **Save** (creates `nxt-board-bootstrap.requested`, and sets `nxtBoardBootstrapMode=auto`). The pack loader also runs when mode is **auto** even if the sentinel file is briefly missing after M999 (then recreates it).
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
