# NeXT board configuration (nxt/config)

NeXT ships vendored **board packs**: RepRapFirmware macro trees for specific Milo platforms and controller boards. On the SD card they live under `0:/sys/nxt/config/` (synced from the repo’s `macros/nxt-config/` at build time).

## Directory layout

For each machine profile (`v1.5`, `v1.6_v2`):

- **Shared:** `milo-common/` — `general.g`, `movement.g`, `network-default.g`, etc.
- **Board packs:** `boards/<RRF_shortName>/` or `boards/<RRF_shortName>/motor-24v/` and `motor-48v/` when motor supply variants exist.

Bundled boards today:

| `boards[0].shortName` (RRF) | Variants |
| --- | --- |
| `cdy3_f4` (Fly CDYv3) | Single pack: `boards/cdy3_f4/entry.g` |
| `scylla1_0_h723` (Scylla v1.0) | `boards/scylla1_0_h723/motor-24v/entry.g` and `motor-48v/entry.g` |

Paths are the same under `nxt/config/v1.5/` and `nxt/config/v1.6_v2/`; only the profile prefix changes.

## Load order (firmware)

1. **`config.g`** should invoke `M98 P"nxt.g"` per NeXT install instructions.
2. **`nxt.g`** loads `nxt-vars.g`, optional MOS import, `nxt-tooltable.g`, then **requires** `nxt-user-vars.g`.
3. **`nxt-board-pack-loader.g`** runs next when **opt-in** is present (see below). It may `M98` a pack `entry.g` so drives, limits, spindle, etc. match the board.
4. **`nxt-boot.g`** and plugin init dispatchers run afterward.

Board packs intentionally load **after** `nxt-user-vars.g` so globals such as `nxtScyllaMotorVoltage` (24 or 48) are available for Scylla path selection.

## Opt-in, opt-out, manual override

- **Auto load:** create empty `0:/sys/nxt-board-bootstrap.requested` on the SD card.
- **Disable:** create `0:/sys/nxt-board-bootstrap.skip`.
- **Manual chain:** add `0:/sys/nxt-user-board.g` with your own `M98 P"…"` line(s); the loader runs this file and returns. See `macros/system/nxt-user-board.g.example` in the repo.

## Resolution inside `nxt-board-pack-loader.g`

1. If the request file is missing → return (no pack).
2. If skip file exists → return.
3. If `nxt-user-board.g` exists → `M98` it; set `global nxtBoardPackEntry = "nxt-user-board.g"` (telemetry).
4. Else require `global nxtPlatformProfile` in `{ "v1.5", "v1.6_v2" }` (set in `nxt-user-vars.g`).
5. **Board id:** `global nxtBoardShortNameOverride` if set and non-empty; otherwise `boards[0].shortName` from the object model.
6. **Scylla only:** require `global nxtScyllaMotorVoltage` ∈ `{ 24, 48 }`. Missing or invalid values **do not** fall back to a default; the loader prints a message and exits without loading a pack.
7. Set `global nxtBoardPackEntry` to the chosen entry path (under `nxt/config/...`) and `M98` it.

Globals are declared in `macros/system/nxt-vars.g` (`nxtBoardShortNameOverride`, `nxtScyllaMotorVoltage`, `nxtBoardPackEntry`, etc.).

## DWC UI

The Configuration panel writes the same globals (and can clear deprecated `nxtBoardKitKey` when saving `nxt-user-vars.g`). Path previews use `ui/src/utils/nxtBoardManifest.ts`, which should stay aligned with the firmware loader.

## Adding a new board pack

1. Under `macros/nxt-config/v1.5/` (and usually `v1.6_v2/`), create `boards/<newShortName>/entry.g` plus fragments, following an existing pack’s `entry.g` chain.
2. If the board needs 24 V / 48 V motor variants, use `boards/<shortName>/motor-24v/` and `motor-48v/` subtrees.
3. Extend `macros/system/nxt-board-pack-loader.g` with explicit branches and `M98` paths (RRF `M98 P"…"` does not take a runtime path variable).
4. Register the board in `ui/src/utils/nxtBoardManifest.ts` (`NXT_BUNDLED_BOARDS`).
5. Add any UI strings in `ui/src/locales/en.json` and verify the Configuration panel.

## Plugin init echo

`macros/plugins/next/next-init.g` prints `nxtPlatformProfile`, `nxtBoardPackEntry`, and `nxtScyllaMotorVoltage` after NeXT boot for support logs. It does **not** load board packs a second time.

## References

- [plugin-spec.md](plugin-spec.md) — NeXT plugin dispatchers and `next-init.g`.
- `macros/nxt-config/ATTRIBUTION.txt` — upstream Millennium Machines paths (historical naming).
