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
7. Board pack, tools, boot checks, plugin-init **once**, single post-colour RGB `M950`, …
8. **`nxt-user-overrides.g`** — last wins → then `nxtLoaded`

Configuration / Calibration **Save** and Custom **Apply** share [`ui/src/utils/nxtUserConfigPersist.ts`](../ui/src/utils/nxtUserConfigPersist.ts) (`persistNxtUserConfig`): user-vars upload, idempotent bootstrap + `nxt-custom.requested` sync, cached `ensureCustomGlobals`, optional Custom pack deploy.

## Rules

1. Prefer `null` slots over filled templates (`nxtTT`).
2. Do not expand `nxtProbeResults` / `nxtProbeHitXY` / cal travel vectors at boot.
3. Do not put `nxtCustom*` or deprecated `nxtBoardKitKey` / `nxtScyllaMotorVoltage` in `nxt-vars.g`.
4. Do not declare touch/toolsetter-specific sample-count triples in `nxt-vars.g` (optional via overrides).
5. Never persist `set global.foo = null` for optional keys in `nxt-user-vars.g`.
6. Avoid dual `mosTT` + `nxtTT`.
7. Do not gate `nxt-probe-wcs.g` on `nxtOvertravel` (align may set OT from MOS first).

## Checking size

```bash
node dist/check-om-global-budget.mjs
```

Cursor rule: [`.cursor/rules/om-global-size.mdc`](../.cursor/rules/om-global-size.mdc).
