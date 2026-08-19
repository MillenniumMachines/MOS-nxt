# Object model `global` size budget

RepRapFirmware (especially SBC / DSF SPI) rejects oversized single-key OM responses:

```text
Error: Cannot store excessively long object model response, discarding request
(total length NNNN, key global, flags d99vno)
```

Stay **comfortably under ~8 KiB** (aim for headroom; 8192 is the cliff).

DWC always polls the whole `global` key; plugins cannot split that request.

## Boot load order (overlay model)

1. **`nxt-vars.g`** — lean core defaults (session vectors stay `null` until used)
2. **`nxt-custom-globals.g`** — only if `0:/sys/nxt-custom.requested` **or** Custom overlays exist (`if !exists` → null)
3. Optional **MOS import** (nested from `nxt.g`: skips re-loading custom-globals / mid-import user-vars; standalone `M98` still does both)
4. **`nxt-tooltable.g`** — sole `mosTT`/`mosET` → `nxtTT`/`nxtET` owner
5. **`nxt-probe-wcs.g`** when `!exists(global.nxtWPDeg)` (not gated on overtravel) → then **`nxt-mos-globals-align.g`** for mos WCS/OT copies. Other `nxtWP*` allocate on first write: **`nxt-wp-ensure.g`** (Ctr/Dims/Rad), **`nxt-wp-ensure-cnr.g`**, **`nxt-wp-ensure-sfc.g`**. String catalogs are local-var (`nxt-m291-corners.g`), not `global`.
6. **`nxt-user-vars.g`** — operator Save (`set` only; omit unset keys)
7. **`nxt-probe-virtual.g`** — mill length datum sidecar (`set global.nxtProbeVirtualTsZ`); also persist finite virtual in `nxt-user-vars.g`
8. Board pack, tools, boot checks, plugin-init **once**, single post-colour RGB `M950`, …
9. **`nxt-user-overrides.g`** — last wins → then `nxtLoaded`

Configuration / Calibration **Save** and Custom **Apply** share [`ui/src/utils/nxtUserConfigPersist.ts`](../ui/src/utils/nxtUserConfigPersist.ts) (`persistNxtUserConfig`): user-vars upload, idempotent bootstrap + `nxt-custom.requested` / `nxt-custom-a.requested` sync, cached `ensureCustomGlobals`, optional Custom pack deploy.

## Rules

1. Prefer `null` slots over filled templates (`nxtTT`).
2. Do not expand `nxtProbeResults` / `nxtProbeHitXY` / cal travel vectors at boot.
3. Do not pre-fill `nxtToolLife` with `vector(limits.tools, 0.0)` — leave `null` and allocate on first use (`nxt-tool-life-ensure.g`). Do not expand it in `nxt.g` just because `nxt-maintenance.g` exists.
4. Do not put `nxtCustom*` or deprecated `nxtBoardKitKey` / `nxtScyllaMotorVoltage` in `nxt-vars.g`.
5. Do not declare touch/toolsetter-specific sample-count triples in `nxt-vars.g` (optional via overrides).
6. Never persist `set global.foo = null` for optional keys in `nxt-user-vars.g`.
7. Avoid dual `mosTT` + `nxtTT`.
8. Do not gate `nxt-probe-wcs.g` on `nxtOvertravel` (align may set OT from MOS first) — use `!exists(global.nxtWPDeg)`.
9. Tool-length mill cache is session scalars (`nxtToolCacheIdx` / `nxtToolCacheZ`). Mill datum (`nxtProbeVirtualTsZ`) is M5016 platen Z, persisted in `nxt-user-vars.g` (omit null) and `0:/sys/nxt-probe-virtual.g`.
10. `nxtPinStates` stays `null` until `pause.g`; do not persist it in user-vars.
11. Custom A-axis keys only when `0:/sys/nxt-custom-a.requested` exists (Save syncs when any `nxtCustomA*` is set).
12. **MosAtc:** still skipInitDispatch — `nxt.g` loads MosAtc only when `nxtFeatureAtc` is true (saves ~800B+ `atc*` globals when ATC is off). **MosFourthAxis:** catalog init dispatch gated on `nxtFeatureFourthAxis` (rotary scalars are small; mapping is skipped if A already exists).
13. Board pack path telemetry: persist `nxtBoardPackEntry` at resolve time; keep expected path as a **comment** in `nxt-user-vars.g` (do not store `nxtBoardPackExpectedEntry` / `nxtBoardPackShortName` in OM). `nxtBoardSysDeployPlatform` is declare-on-use.

## Checking size

```bash
node dist/check-om-global-budget.mjs
```

The checker does **four** things:

1. **Hygiene** — Custom gating, null session vectors, null-filled `nxtTT`, no deprecated keys, …
2. **Known bloat bans** — e.g. `nxtToolLife = { vector(limits.tools, 0.0) }` at boot (this alone can push Custom machines over 8 KiB)
3. **Estimated JSON size** — lean boot (`nxt-vars` + tooltable) and lean + all Custom null declares
4. **Sibling idle** — adds `nxt-probe-wcs.g` (always-on Deg/scalars, not the lazy WP pack) plus sibling `arborctl-vars.g` and MosFourthAxis init when those repos sit next to NeXT; fails `siblingsIdle` if too close to 8192

Example OK line:

```text
check-om-global-budget: estimate lean≈NNNNB customNulls≈MMMMB lean+custom≈PPPPB siblingsIdle≈QQQQB extra≈RRRRB (limit 8192; …)
```

Estimates are **not** a live DSF capture — leave headroom for `nxt-user-vars.g` strings, filled `nxtTT` slots, filled `arborVFDStatus`, and leftover `mosTT` (RRF cannot delete declared globals). Recapture live `key=global` length after probe/VFD Apply. If the printer still reports `total length 8xxx, key global`, shrink further even when the checker is green.

Cursor rule: [`.cursor/rules/om-global-size.mdc`](../.cursor/rules/om-global-size.mdc).
