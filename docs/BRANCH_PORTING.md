# Branch porting (v0.6.0 ↔ v0.7.0)

Manual workflow for moving changes between **parallel release lines** while both are maintained. See [VERSIONING.md](VERSIONING.md) for branch ↔ RRF/DWC alignment.

**Lifecycle:** Active until **`v0.6.0` is EOL'd** as a version branch. After EOL, archive this doc; stop routine backports to `v0.6.0`.

## Rules (hard)

1. **Branches never merge** — no `git merge v0.7.0` into `v0.6.0` (or vice versa).
2. **Each line ships independently** — own tags, `ci/dwc-build-ref`, plugin ZIPs, post-processors.
3. **Port by copy-and-adapt** — `git show other-branch:path`, diff, adapt, commit on **target branch only**.
4. **Never copy version-line artifacts** across branches (see exclusion table below).

## Branch ↔ firmware

| nxt line | Git branch | RRF / DWC | OM budget target |
|----------|------------|-----------|------------------|
| 0.6.x | `v0.6.0` | **3.6.x** (eval **3.6.3**) | **~5 KiB** `key=global` |
| 0.7.x | `v0.7.0` | **3.7.x** | **~8 KiB** (CDYv3 dropped) |

## Direction

| Direction | When | Adaptation |
|-----------|------|------------|
| **v0.7.0 → v0.6.0** | Feature/fix is RRF-3.6.3-compatible | Strip 3.7 pins; Vuetify **2** templates; keep **CDYv3** board pack |
| **v0.6.0 → v0.7.0** | Shared bugfix/macros during dual maintenance | Vue 3 / Vuetify 3 pass; rebuild against 3.7 pin |

Default **new RRF-3.7 features** on `v0.7.0`. Backport to `v0.6.0` only when 3.6.x-compatible and `v0.6.0` is still supported.

## Version artifact exclusions

Never copy these from the other line:

| Category | Examples |
|----------|----------|
| Build pin | `ci/dwc-build-ref`, `docs/RRF_REFERENCE.md` generation values |
| 3.7-only docs | `docs/RRF_3.7_MIGRATION.md` → v0.7.0 only |
| Vue 3 shim | `ui/src/compat/*`, `.cursor/rules/ui-plugin-typecheck.mdc` |
| Version strings | `v0.7.0`, `3.7.0-beta.1`, `dist/post-processors/v0.7.x/*` |
| CDYv3 removal | Do not delete `board/cdy3_f4/` on v0.6.0 |
| 3.7 build gates | `dist/check-node-for-dwc-build.sh`, Vite-only ZIP paths |

## UI adaptation (v0.7.0 → v0.6.0)

| Vuetify 3 (v0.7.0) | Vuetify 2 (v0.6.0) |
|--------------------|---------------------|
| `:model-value` | `:value` |
| `density="compact"` | `dense` |
| `variant="outlined"` | `outlined` |
| `v-expansion-panel-title` | `v-expansion-panel-header` |
| Pinia / `@/plugins` | Vue 2 `@/store`, `@/routes` in `ui/src/index.ts` |

Do **not** port `ui/src/compat/dwcStore.ts` or `vueCompat.ts` to v0.6.0.

## Macro checklist

- Line length ≤ **200** chars (`node dist/check-gcode-line-length.mjs`)
- OM hygiene (`node dist/check-om-global-budget.mjs`)
- **CDYv3 endstop:** On v0.6.0, keep board-conditional Y pins (`PD_11` CDYv3, `PD_14` Scylla) — never copy v0.7.0 Scylla-only `machine/*/endstops.g` wholesale to v0.6.0
- Regenerate manifest if `nxt-config/` changed

## CDYv3 endstop guard

v0.7.0 hard-codes Scylla pins in stock `machine/*/endstops.g` (full XYZ; CDYv3 dropped). On v0.6.0, preserve board conditionals for Y (and any axis that still shares a pin map):

```gcode
if { exists(global.nxtBoardPackShortName) && global.nxtBoardPackShortName == "scylla1_0_h723" }
    M574 Y1 S1 P"PD_14"
else
    M574 Y1 S1 P"PD_11"
```

(`Y2` for v1.5 toward max.) CI: `./dist/check-cdy-endstop-y.sh`.

## Process

1. Classify change (compatible? which direction?).
2. `git show v0.7.0:path` or diff against target.
3. Adapt (UI, OM budget, endstops, version pins).
4. Run gates on **target branch** (see [release-plugin-verify](../.cursor/rules/release-plugin-verify.mdc)).
5. Smoke-test on that line's RRF/DWC.

## Release gates (per branch)

```bash
./dist/audit-naming.sh
node dist/verify-nxt-plugin-contract.mjs
node dist/check-gcode-line-length.mjs
node dist/check-om-global-budget.mjs
./dist/check-line-endings.sh
./dist/check-cdy-endstop-y.sh          # v0.6.0 only
./dist/verify-dwc-build-alignment.sh <DWC>
./dist/build-plugin.sh <DWC>
```

## At v0.6.0 EOL

- Freeze `v0.6.0`; no new feature backports.
- Archive this document.
- Critical security fixes only if explicitly documented.

## Related

- [VERSIONING.md](VERSIONING.md)
- [OM_GLOBAL_SIZE.md](OM_GLOBAL_SIZE.md)
- [RRF_REFERENCE.md](RRF_REFERENCE.md)
