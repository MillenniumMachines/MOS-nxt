# RRF meta pitfalls (nxt probing / macros)

Hard-won constraints from rewriting UI probe cycles (`G650x` / `G6520` / `G6550` / `G6512`) on the RRF **3.7** line. Prefer this over rediscovering faults on the machine.

Related: [RRF_LINE_LENGTH.md](RRF_LINE_LENGTH.md), [CODE.md](CODE.md), [RRF_META.txt](RRF_META.txt), [RRF_3.7_MIGRATION.md](RRF_3.7_MIGRATION.md), [GCODE.md](../GCODE.md).

## 1. `^` is concatenation, not power

In RRF meta, **`^` concatenates strings** (and in 3.7+, arrays). It is **not** exponentiation.

| Symptom | Cause |
|---------|--------|
| `missing expected numeric operand` on lines with `sqrt((…)^2 + …)` | `(dx)^2` is parsed as concat, then fed to `sqrt` |

**Do:**

```gcode
var dx = { var.cx - var.hx }
var dy = { var.cy - var.hy }
var r = { sqrt(var.dx * var.dx + var.dy * var.dy) }
; or: sqrt(pow(var.dx, 2) + pow(var.dy, 2))
```

**Do not:** `sqrt((…)^2 + (…)^2)` or `var.deltaX^2`.

**Gate:** `node dist/check-rrf-caret-power.mjs` (also run by `build-plugin.sh`). Bans `^N` inside `{…}` meta expressions.

## 1b. Never `M98` numbered `M####` / `G####` files

Release sync places `macros/**/M6520.g` (etc.) on **`0:/sys/`**. RRF runs them as meta commands **`M6520`**, **`G6503`**, …

| Symptom | Cause |
|---------|--------|
| `M6520: Result index parameter P is required` after a probe U-chain | `M98 P"M6520.g" P{slot} …` — **`P` is M98’s filename**, not a nested param |

**Do:** `M6520 P{var.pSlot} W{param.U} X1 Y1`  
**Do not:** `M98 P"M6520.g" P{…}` (or any `M98 P"M….g"` / `G….g"`)

Named helpers stay OK, but **do not pass a second `P`**: `M98 P"nxt-….g" P1` is dropped the same way. Use **`Q` / `I` / `W`**.

**Gate:** `node dist/check-m98-numbered-meta.mjs` (also run by `build-plugin.sh`). Flags numbered-meta `M98` **and** nested `P` on any `M98` line.

## 1c. Meta axis *flags* need a number (`X1`, not bare `X`)

[`M6520`](../macros/utilities/M6520.g) only tests **`exists(param.X)`** (etc.) — the numeric value is ignored. On RRF numbered meta commands, a **bare letter without a following number often does not bind** `param.X`, so `exists(param.X)` stays false and M6520 aborts (“at least one axis flag”) or skips apply.

| Call | Typical result |
|------|----------------|
| `M6520 … X Y` | `param.X` / `param.Y` absent |
| `M6520 … X1 Y1` | `param.X=1`, `param.Y=1` → G10 L2 then `G53 G1` to stored L2 XY (Z pinned; never work Z0) |

**Do:** `M6520 P{var.pSlot} W{param.U} X1 Y1` (then G10 L2 and `G53 G1` to stored origin XY; never Z0)  
**Do not:** `M6520 … X Y` / bare `X` / `Y` / `Z` / `A` as flags

Same rule for UI Push-to-WCS (`ProbeResultsPanel` emits `X1`…).

**Gate:** `node dist/check-m6520-axis-flags.mjs` (also run by `build-plugin.sh`).

## 1d. No dynamic `G{…}` / `M{…}` command numbers

RRF error: **`dynamic command numbers are only allowed in T-codes`**.

`T{expr}` is legal; **`G{53 + wcs}`** / **`M{…}`** are not. Selecting a workplace must use a literal code (`G54`…`G59.3`) or the named helper:

```gcode
; ❌ BAD
G{53 + var.wcsNumber}

; ✅ GOOD
M98 P"nxt-select-wcs.g" W{var.wcsNumber}
```

String echoes / `M291` text that *display* `(53 + wcs)` are fine — those are not command numbers.

**Gate:** `node dist/check-no-dynamic-gm-codes.mjs` (also run by `build-plugin.sh`).

## 2. Axis count — never assume A exists

`#move.axes` is often **3** (Milo / no rotary). Arrays sized to `#move.axes` have no index `[3]`.

| Symptom | Cause |
|---------|--------|
| Meta errors around `G6550` target build / `G38.3 … A{…}` | Always indexing `targetCoords[3]` or emitting `A` on a 3-axis machine |

**Do (pattern from `G6512` / fixed `G6550`):**

```gcode
M5000
var targetCoords = { global.nxtAbsPos }
var hasA = { #var.targetCoords > 3 }
if { var.hasA && exists(param.A) }
    set var.targetCoords[3] = { param.A }
if { var.hasA }
    ; M6515 / G38.3 with A
else
    ; M6515 / G38.3 without A
```

Prefer `exists(param.X)` / `exists(param.Y)` / … over `{ param.X, param.Y, param.Z, param.A }` when mutating a pose vector whose length is `#move.axes`.

## 3. Probe dive height — never park before capturing `startZ`

`G27 Z1` does `G53 G0 Z{move.axes[2].max}`. On many machines Z max displays as **0**, so a pre-dive park looks like “raise to Z0”, and `L` then drops from **park**, not the jogged height.

| Symptom | Cause |
|---------|--------|
| Cycle raises to Z0 / Z max then probes at the wrong height | `G27` (or Enable Probe raise) before `M5000` → `startZ` |

**Contract for UI probe cycles (`G6500`…`G6520`):**

1. Operator jogs to start XYZ (probe already selected).
2. `M5000` → `startZ = nxtAbsPos[2]`.
3. Dive: `G6550 Z{startZ - L}` only (drop by `L`; no raise).
4. Horizontal probes at dive Z.
5. End at `startZ` (or feature result Z for vise corner) — **not** `G27` Z max. XY apply cycles raise to **startZ** first (XY pinned), then **`G53 G1`** to the fitted origin. Never XY-park at dive Z. Never work `G0 X0 Y0` after a `G53`/`G38` cycle.

Enable Probe may still raise to Z max **before** `T…` for tool change safety; the operator must re-jog before Execute.

## 4. `nxtProbeHitXY` starts `null`

Boot declares `global nxtProbeHitXY = null`. `#null` and arithmetic on slots fail with numeric-operand / length errors.

`G6512 … Hn` allocates and writes hit XY only when `H` is set **and** hits were recorded. Cycles that read H0…Hn must:

1. Assert buffer exists, non-null, and length sufficient **before** slot reads.
2. Abort on null coordinates (clearer than a mid-`sqrt` fault).

`G6512` itself aborts if `H` was requested but `finalHitN == 0` (do not silently skip the write).

## 5. Null-safe parameter checks

`!exists(param.L) || param.L <= 0` is unsafe if the letter exists with a **null** value (`null <= 0` → numeric operand).

**Do:** `!exists(param.L) || param.L == null || param.L <= 0` (same for `D` / `W` / `H` as needed).

## 6. Brace every assignment / expression

Unbracketed aliases are brittle:

```gcode
; Bad
var x1 = var.xPx
; Good
var x1 = { var.xPx }
```

See [CODE.md](CODE.md) § Expression Handling.

## 7. Line length ≤ 200

Overlong lines → `GCode command too long` (boot killer on `nxt.g`). Split compound `if` / long `echo` / `abort` / `M291`. Gate: `node dist/check-gcode-line-length.mjs`. Full policy: [RRF_LINE_LENGTH.md](RRF_LINE_LENGTH.md).

## 8. Positive-Z shortcut in `G6550`

`G6550` treats **Z-only upward** moves as unprotected `G53 G1` **only when the probe is clear**. That `G1` **pins current XY (and A)** from the M5000 snapshot — never emit Z-only after a **`G38`**, or the leftover interpolator can continue toward the last wall (bore rim after triangulation). If the stylus is already triggered on a Z-only raise, it **aborts** instead of silent `G1`. If already triggered on any other move, it first **`G1` toward the commanded target** (clear/retract direction the caller requested) — never away from target (that drove into the bore wall after `G6512.1` retract). Then the main move uses probe-protected `G38.3`. Do not pass a dive target that is **above** current Z unless you intend a raise.

Probe **triangulation** (`G6500` / `G6501` via **`G6513`** → **`G6512.1`**) repositions **between stations** with **`G6550`**, never bare `G0` for that travel. After **`G38`**, issue **`M400`** **before** any following move so a leftover wall target cannot complete first. Native circumcenter is **A = P2−P1**, **B = P3−P1**. **B = P3−P2** parks the “center” on a vertex (wall contact) and reports a bogus mean diameter. Finish: **`M400`**, **raise to startZ with XY (and A) pinned**, then **`G53 G1`** to fitted circumcenter XY — not one combined diagonal (rim clip), not XY at dive Z, not **`G6550`/`G38.3`**. If the stylus is still triggered, a short **`G53 G1`** toward the fit (≤ dive-height) clears it — not **`G6550`**. Do **not** overwrite `nxtProbeResults` XY from post-park `machinePosition`. Other UI cycles use single-axis **`G6512`**. Post-touch backoff in **`G6512`** / **`G6512.1`** is rapid **`G53 G0`** (all axes pinned, **`M400`** first), not probe feed; **A**-axis **`G6512`** skips backoff (`diveHeights` are millimetres). **G6506** raises to **startZ** then parks XY at the edge midpoint before **M6520**. **G6508** / **G6509** / **G6520** use the same **G53 G1** park at the fitted corner, then **`nxt-wcs-apply.g`**.

## 9. Nested G53 / leftover G38 then machine 0,0 (XY then unhomed)

| Symptom | Cause |
|---------|--------|
| After a corner the mill runs to **machine home**, then **X/Y cannot jog** | Leftover **G38** after G6508 returns completes as **G53 X0 Y0**, slams min endstops, drops `homed`. Park+apply echoes can still show the fitted corner. |
| Park/apply log is correct (work XY ≈ 0 at the feature), then Console **`G0 X0 Y0`** flies home | Zero-length `G53 G1` of the current pose in **`nxt-g38-cancel.g`** is skipped; leftover G38 waits for the next motion. |
| Same after HTTP `G6508` if DSF treats it as a job | [`stop.g`](../macros/system/stop.g) used to **`G27`** (table park). Skipped when `nxtSkipJobPark` or there is no `job.file.fileName`. |

**Do:** G53-park at the stored L2 millimetres, apply with **`nxt-wcs-apply.g`** (no `G0`), then **`M98 P"nxt-g38-cancel.g"`**. That helper **must actually move**: a **zero-length** `G53 G1` of the current pose is skipped by the planner, leftover **G38** stays armed, and the next Console **`G0 X0 Y0`** (omits Z) completes as **machine** X0 Y0. Cancel nudges Z (or Y) 0.05 mm in **G53**, restores, then a **non-G53** `G91` all-axis nudge and back, and **ends on `G90`**. Echoes `drain nudge` plus machine/user/homed **after** the drain. **M6520** Push uses `G53 G1` to stored XY (Z/A pinned), then the same cancel. **`nxt-workzero.g`** uses `G53 G1` to `workplaceOffsets` (never work `G0 X0 Y0` after `G27`).  
**Do not:** `G0 X0 Y0` after a `G53`/`G38` probe cycle until cancel has **moved**. Do not omit XY on the next move after `G38`. Do not end a helper on `G53`.

A correct `G10 L2` plus a real work-space `G0 X0 Y0` would park at the **feature**. Work XY ≈ 0 at machine ≈ corner is success. Reaching **machine** 0,0 means leftover G38/G53 (or `stop.g` `G27`). Never switch apply to **`G10 L20`**.

## Checklist before claiming probe-macro work done

```bash
node dist/check-gcode-line-length.mjs
node dist/check-m98-numbered-meta.mjs
node dist/check-rrf-caret-power.mjs
node dist/check-g6512-axis-contract.mjs
# then build-plugin.sh <DWC> and reinstall ZIP so SD macros update
```

After install, confirm bore dive echoes `startZ` / `L` / `diveZ` with `diveZ < startZ` before XY probes.

## Validation sweep (v0.7.0-beta.1-bugs)

Repo scan after documenting these pitfalls:

| Pitfall | Status |
|---------|--------|
| `^N` as power in `{…}` | Clean (`check-rrf-caret-power`) |
| `M98 P"M…/G….g"` for numbered meta | Banned (`check-m98-numbered-meta`) |
| UI `G650x`/`G6510`/`G6520` pre-dive `G27` | Removed |
| `G6550` / `G6512` A-axis without `hasA` | Gated |
| UI cycle hit-buffer guards | Present on H-slot cycles |
| `!exists \|\| <=` without `== null` on UI D/L/W/H/S | Hardened (`G6502`/`03`/`06`/`08`, `.1` N checks) |
| `G6510` `{ param.X, param.Y, param.Z }` | Rewritten to `exists()` fill |
| Deflection element `null * 1000` | Guarded in `G6512` |

Still intentional (out of UI dive path): `G6511` / `G6512.1` error-path `G27 Z1` park; Enable Probe raise to Z max before `T…`.
