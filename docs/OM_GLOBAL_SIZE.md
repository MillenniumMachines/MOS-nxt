# Object model `global` size budget (v0.6.0 line)

RepRapFirmware rejects oversized single-key OM responses (SBC SPI ~8 KiB cliff; CDYv3 stm32f4 RAM is tighter):

```text
Error: Cannot store excessively long object model response, discarding request
(total length NNNN, key global, flags d99vno)
```

On branch **`v0.6.0`**, design for **5120 bytes (~5 KiB)** serialized `global` after boot — CDYv3 is the binding constraint. Branch **`v0.7.0`** targets **~8 KiB** (CDYv3 dropped).

DWC always polls the whole `global` key; plugins cannot split that request.

## Boot load order (overlay model)

1. **`nxt-vars.g`** — lean core defaults (session vectors stay `null` until used)
2. **`nxt-custom-globals.g`** — only if Custom sentinel/overlays exist (`if !exists` → null)
3. Optional **MOS import** → **`nxt-tooltable.g`** → **`nxt-probe-wcs.g`** when `!nxtWPCtrPos` → **`nxt-mos-globals-align.g`**
4. **`nxt-user-vars.g`** — operator Save (`set` only; omit unset keys)
5. Board pack, tools, boot checks, plugin-init **once**, RGB, …
6. **`nxt-user-overrides.g`** — last wins → then `nxtLoaded`

Configuration / Calibration **Save** and Custom **Apply** share [`ui/src/utils/nxtUserConfigPersist.ts`](../ui/src/utils/nxtUserConfigPersist.ts).

## Rules

1. Prefer `null` slots over filled templates (`nxtTT`).
2. Do not expand `nxtProbeResults` / `nxtProbeHitXY` / cal travel vectors at boot.
3. Do not put `nxtCustom*` in `nxt-vars.g`.
4. Never persist `set global.foo = null` for optional keys in `nxt-user-vars.g`.
5. Avoid dual `mosTT` + `nxtTT`.
6. Do not gate `nxt-probe-wcs.g` on `nxtOvertravel`.

## Checking size

```bash
node dist/check-om-global-budget.mjs
```

Static checker enforces hygiene and `nxt-vars.g` declare count (warn >100, fail >120). **Measure** actual bytes on hardware via DWC OM browser or `M409 K"global"`.

## Expansion points (do not raise limits without measurement)

| Expansion | When |
|-----------|------|
| Scylla standalone | Measured headroom on `scylla1_0_h723` above 5 KiB |
| SBC / DSF (~8 KiB) | `exists(sbc)` — primarily v0.7.0 line |
| Custom platform | Gated; more keys only if post-Apply OM measured |
| Drop dual `mosTT`+`nxtTT` | After MOS migration |

Cursor rule: [`.cursor/rules/om-global-size.mdc`](../.cursor/rules/om-global-size.mdc).

Branch porting: [BRANCH_PORTING.md](BRANCH_PORTING.md).
