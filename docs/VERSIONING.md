# nxt versioning and RRF / DWC alignment

Branch ↔ firmware policy and release workflow. For moving changes between lines, see [BRANCH_PORTING.md](BRANCH_PORTING.md).

## Dual maintenance (current)

**`v0.6.0` and `v0.7.0` are maintained simultaneously** until **`v0.6.0` is EOL'd**. Lines do **not** merge; porting is manual ([BRANCH_PORTING.md](BRANCH_PORTING.md)).

## Branch ↔ firmware rule

**nxt `v0.M.0` aligns with RRF / DWC `3.M.x`.**

| nxt line | Git branch | nxt tags | RRF / DWC generation | Notes |
|----------|------------|----------|----------------------|--------|
| **0.6.x** | **`v0.6.0`** | `v0.6.0-beta.N` … `v0.6.0` | **3.6.x** | Eval **3.6.3**; OM **~5 KiB**; CDYv3 supported |
| 0.7.x | `v0.7.0` | `v0.7.0-beta.N` … `v0.7.0` | **3.7.x** | Forward line; OM **~8 KiB** |
| 0.8.x (future) | `v0.8.0` | `v0.8.0-*` | **3.8.x** | When RRF 3.8 ships |

Patch releases on the same line stay on the same RRF **3.M** generation unless a hotfix documents a different pin.

## Pins on branch `v0.6.0`

| Pin | Location | Current value |
|-----|----------|---------------|
| DWC build ref | [`ci/dwc-build-ref`](../ci/dwc-build-ref) | `v3.6.3` |
| RRF evaluation target | [RRF_REFERENCE.md](RRF_REFERENCE.md) | **3.6.3** (3.6.x line) |
| Plugin manifest | [`ui/plugin.json`](../ui/plugin.json) | `rrfVersion: "auto-major"` → `3.6.*`; `dwcVersion: "auto"` → exact DWC at build |
| OM budget | [OM_GLOBAL_SIZE.md](OM_GLOBAL_SIZE.md) | **~5 KiB** serialized `global` |

When upstream ships a newer **3.6.x** patch, bump `ci/dwc-build-ref` and `RRF_REFERENCE.md` together on `v0.6.0`. Rebuild plugin ZIPs against matching DWC.

## Release workflow

1. **Development** on versioned branch `v0.6.0` until EOL.
2. **Pre-releases:** `v0.6.0-beta.N` — see [release-plugin-verify](../.cursor/rules/release-plugin-verify.mdc).
3. **Release candidates:** `v0.6.0-rcN` (no dot before `rc`).
4. **Stable:** `v0.6.0` on branch `v0.6.0`.
5. **ZIP naming:** `nxt-<version>.zip` ([NAMING.md](NAMING.md)).
6. **`global.nxtVersion`** and CAM post-processors (`M4005`) match the installed release from this line.

## Related docs

- [BRANCH_PORTING.md](BRANCH_PORTING.md) — v0.6.0 ↔ v0.7.0 manual porting until EOL
- [RRF_REFERENCE.md](RRF_REFERENCE.md)
- [OM_GLOBAL_SIZE.md](OM_GLOBAL_SIZE.md)
- [PLUGIN_LOAD_TROUBLESHOOTING.md](PLUGIN_LOAD_TROUBLESHOOTING.md)
