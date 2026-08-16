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
5. **`nxt-probe-wcs.g`** when `!exists(global.nxtWPCtrPos)` (not gated on overtravel) → then **`nxt-mos-globals-align.g`** for mos WCS/OT copies
6. **`nxt-user-vars.g`** — operator Save (`set` only; omit unset keys)
7. **`nxt-probe-virtual.g`** — mill length datum sidecar (`set global.nxtProbeVirtualTsZ`); also persist finite virtual in `nxt-user-vars.g`
8. Board pack, tools, boot checks, plugin-init **once**, single post-colour RGB `M950`, …
9. **`nxt-user-overrides.g`** — last wins → then `nxtLoaded`

Configuration / Calibration **Save** and Custom **Apply** share [`ui/src/utils/nxtUserConfigPersist.ts`](../ui/src/utils/nxtUserConfigPersist.ts) (`persistNxtUserConfig`): user-vars upload, idempotent bootstrap + `nxt-custom.requested` / `nxt-custom-a.requested` sync, cached `ensureCustomGlobals`, optional Custom pack deploy.

## Rules

1. Prefer `null` slots over filled templates (`nxtTT`).
2. Do not expand `nxtProbeResults` / `nxtProbeHitXY` / cal travel vectors at boot.
3. Do not pre-fill `nxtToolLife` with `vector(limits.tools, 0.0)` — leave `null` and allocate on first use (`nxt-tool-life-ensure.g` / maintenance).
4. Do not put `nxtCustom*` or deprecated `nxtBoardKitKey` / `nxtScyllaMotorVoltage` in `nxt-vars.g`.
5. Do not declare touch/toolsetter-specific sample-count triples in `nxt-vars.g` (optional via overrides).
6. Never persist `set global.foo = null` for optional keys in `nxt-user-vars.g`.
7. Avoid dual `mosTT` + `nxtTT`.
8. Do not gate `nxt-probe-wcs.g` on `nxtOvertravel` (align may set OT from MOS first).
9. Tool-length mill cache is session scalars (`nxtToolCacheIdx` / `nxtToolCacheZ`). Mill datum (`nxtProbeVirtualTsZ`) is M5016 platen Z, persisted in `nxt-user-vars.g` (omit null) and `0:/sys/nxt-probe-virtual.g`.
10. `nxtPinStates` stays `null` until `pause.g`; do not persist it in user-vars.
11. Custom A-axis keys only when `0:/sys/nxt-custom-a.requested` exists (Save syncs when any `nxtCustomA*` is set).
12. **MosAtc / MosFourthAxis:** optional sibling plugins load from `nxt.g` only when `nxtFeatureAtc` / `nxtFeatureFourthAxis` is true and SD init macros exist — not via unconditional plugin-init dispatch (saves ~800B+ `atc*` globals when ATC is off).
13. Board pack path telemetry (`nxtBoardPackEntry` / Expected / ShortName / SysDeploy) is declare-on-use — not always-on nulls in `nxt-vars.g`.

## Checking size

```bash
node dist/check-om-global-budget.mjs
```

The checker does **three** things:

1. **Hygiene** — Custom gating, null session vectors, null-filled `nxtTT`, no deprecated keys, …
2. **Known bloat bans** — e.g. `nxtToolLife = { vector(limits.tools, 0.0) }` at boot (this alone can push Custom machines over 8 KiB)
3. **Estimated JSON size** — sums a pessimistic UTF-8 size for lean boot (`nxt-vars` + tooltable) and for lean + all Custom null declares; fails if estimates exceed soft thresholds below the 8192 cliff

Example OK line:

```text
check-om-global-budget: estimate lean≈NNNNB customNulls≈MMMMB lean+custom≈PPPPB (limit 8192; …)
```

Estimates are **not** a live DSF capture — leave headroom for `nxt-user-vars.g` strings, filled `nxtTT` slots, and third-party globals (e.g. MosFourthAxis). If the printer still reports `total length 8xxx, key global`, shrink further even when the checker is green.

Cursor rule: [`.cursor/rules/om-global-size.mdc`](../.cursor/rules/om-global-size.mdc).
