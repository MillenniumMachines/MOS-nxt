# nxt versioning and RRF / DWC alignment

Branch ↔ firmware policy and release workflow. For moving changes between lines during dual maintenance, see [BRANCH_PORTING.md](BRANCH_PORTING.md).

## Dual maintenance (current)

**`v0.6.0` and `v0.7.0` are maintained simultaneously** until **`v0.6.0` is EOL'd**. Lines do **not** merge; porting is manual ([BRANCH_PORTING.md](BRANCH_PORTING.md)).

## Branch ↔ firmware rule

**nxt `v0.M.0` aligns with RRF / DWC `3.M.x`.**

| nxt line | Git branch | nxt tags | RRF / DWC generation | Notes |
|----------|------------|----------|----------------------|--------|
| 0.6.x | `v0.6.0` | `v0.6.0-beta.N` … `v0.6.0` | **3.6.x** | Supported in parallel until EOL; OM **~5 KiB**; CDYv3 |
| **0.7.x** | **`v0.7.0`** | **`v0.7.0-beta.N` … `v0.7.0`** | **3.7.x** | **Forward line**; OM **~8 KiB** |
| 0.8.x (future) | `v0.8.0` | `v0.8.0-*` | **3.8.x** | Open when RRF 3.8 ships |

The **minor** digit in nxt semver (`0.M.0`) matches the **minor** digit in RRF/DWC (`3.M`). Patch releases on the same line stay on the same RRF **3.M** generation unless a hotfix explicitly documents a different pin.

## Pins on the active branch (`v0.7.0`)

| Pin | Location | Current value |
|-----|----------|---------------|
| DWC build ref | [`ci/dwc-build-ref`](../ci/dwc-build-ref) | `v3.7.0-beta.1` |
| RRF evaluation target | [`RRF_REFERENCE.md`](RRF_REFERENCE.md) | **3.7.0-beta.1** (3.7.x line) |
| Plugin manifest | [`ui/plugin.json`](../ui/plugin.json) | `rrfVersion: "auto-major"` → `3.7.*`; `dwcVersion: "auto"` → exact DWC at build |
| OM budget | [OM_GLOBAL_SIZE.md](OM_GLOBAL_SIZE.md) | **~8 KiB** serialized `global` (CDYv3 dropped on this line) |

When upstream ships a stable **3.7.0** (or newer 3.7.x patch), bump `ci/dwc-build-ref` and [`RRF_REFERENCE.md`](RRF_REFERENCE.md) together on branch `v0.7.0`. Rebuild plugin ZIPs against the matching DWC tree.

## Release workflow

1. **Active development** on versioned branch `v0.7.0` (forward line).
2. **Pre-releases:** `v0.7.0-beta.N` — see [release-plugin-verify](../.cursor/rules/release-plugin-verify.mdc).
3. **Release candidates:** `v0.7.0-rcN` (no dot before `rc`).
4. **Stable:** `v0.7.0` on branch `v0.7.0`.
5. **ZIP naming:** `nxt-<version>.zip` ([NAMING.md](NAMING.md)).
6. **`global.nxtVersion`** and CAM post-processors (`M4005`) match the installed release from this line.

## Starting a new RRF generation (e.g. 3.8)

When RRF **3.8.x** is the target:

1. Branch from the previous line: `git checkout -b v0.8.0`.
2. Bump [`ci/dwc-build-ref`](../ci/dwc-build-ref) to the matching DWC tag (e.g. `v3.8.0`).
3. Update [`RRF_REFERENCE.md`](RRF_REFERENCE.md), [`README.md`](../README.md), [`ui/src/index.ts`](../ui/src/index.ts), [`UI_DEVELOPMENT.md`](UI_DEVELOPMENT.md).
4. Add [`RRF_3.8_MIGRATION.md`](RRF_3.8_MIGRATION.md) (or equivalent) from the upstream changelog.
5. Run release gates: `./dist/audit-naming.sh`, `node dist/verify-nxt-plugin-contract.mjs`, `./dist/check-macro-line-length.sh`.

## Related docs

- [BRANCH_PORTING.md](BRANCH_PORTING.md) — dual-line manual porting until v0.6.0 EOL
- [RRF_REFERENCE.md](RRF_REFERENCE.md) — evaluation RRF for macro/OM review on this branch
- [RRF_3.7_MIGRATION.md](RRF_3.7_MIGRATION.md) — upgrading from 3.6 to 3.7
- [PLUGIN_LOAD_TROUBLESHOOTING.md](PLUGIN_LOAD_TROUBLESHOOTING.md) — DWC exact-version match for plugin ZIPs
- [ROADMAP.md](ROADMAP.md) — feature track for the current line
