# NeXT board and machine configuration (nxt-config)

NeXT ships vendored **board packs** (controller pins, drives, fans) and **machine packs** (motion, limits, homing sources). On the SD card they live under `0:/sys/nxt-config/` (from `macros/nxt-config/` at build time).

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
    <machineId>/              global.nxtPlatformProfile (e.g. v1.5, v1.6_v2)
      OVERVIEW.txt
      entry.g                 Machine motion chain (no homing at boot)
      movement.g, limits.g, general.g, network-default.g
      homeall.g, homex.g, …   Deploy-only → 0:/sys/
      sys-deploy-manifest.txt
```

Build-time manifest: `dist/generate-nxt-config-manifest.mjs` → `ui/src/generated/nxtConfigManifest.json`.

| Machine | Homing deploy | Boards (shared) |
|---------|---------------|-----------------|
| `v1.5` | Y → max, Z steps 1600 | `cdy3_f4`, `scylla1_0_h723` 24/48 V |
| `v1.6_v2` | Y → min (Y0), Z steps 800 | same board tree |

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

Each board may ship `pinmap.json` (`assigned` + `free`). The Configuration UI will assign **free** pins to coolant/aux roles via `0:/sys/nxt-user-pinmap.g` (loaded after board + machine packs).

## Adding hardware

1. **New board:** `macros/nxt-config/board/<shortName>/` with `entry.g`, `pinmap.json`, fragments.
2. **New machine:** `macros/nxt-config/machine/<id>/` with `entry.g`, homing macros, `sys-deploy-manifest.txt`.
3. Run `node dist/generate-nxt-config-manifest.mjs`.
4. Reinstall plugin ZIP.

## References

- [plugin-spec.md](plugin-spec.md)
- `macros/nxt-config/board-pack-index.txt`
- `macros/nxt-config/ATTRIBUTION.txt`
