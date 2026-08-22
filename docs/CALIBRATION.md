# nxt Machine Calibration Guide

This document describes the resilient steps-per-mm calibration system for nxt, designed to eliminate the circular dependency between steps-per-mm accuracy, backlash compensation, and touch probe deflection measurement.

---

## 1. The Calibration Challenge

When setting up a CNC machine, three measurement errors can affect machine accuracy:

1. **Steps-per-mm** - The fundamental relationship between motor steps and actual distance traveled
2. **Backlash** - Mechanical slack that causes position error when changing direction
3. **Touch Probe Deflection** - The distance the probe tip moves before triggering

These three error sources create a circular dependency problem:

- **Touch probe deflection** cannot be accurately measured unless steps-per-mm are correct and backlash is compensated
- **Backlash** cannot be accurately measured unless steps-per-mm and probe deflection are correct
- **Steps-per-mm** can be calibrated manually, but doing it with automated touch probe measurements requires accurate backlash compensation and probe deflection

This creates a "chicken and egg" problem where each measurement depends on the others being accurate.

---

## 2. Theoretical Foundation

### 2.1 Understanding Each Error Source

#### Steps-per-mm Error
- **Cause**: Incorrect firmware configuration, mechanical tolerances in drive components
- **Effect**: Machine moves wrong distance when commanded (e.g., commanded 100mm, actually moves 99.8mm or 100.2mm)
- **Characteristics**: Proportional error - larger moves have larger absolute errors

#### Backlash Error
- **Cause**: Mechanical slack in couplings, lead screws, ball screws, or linear guides
- **Effect**: Position error when changing direction, until slack is "taken up"
- **Characteristics**: Fixed magnitude per axis, independent of move distance

#### Probe Deflection Error
- **Cause**: Physical deflection of probe tip and stylus before electrical trigger
- **Effect**: Probe appears to trigger before/after actual contact point
- **Characteristics**: 
  - Generally consistent magnitude for similar approach speeds
  - May vary slightly based on probe angle and surface material
  - Opposite when probing from opposite directions (deflects away from surface)

### 2.2 Key Insight: Breaking the Circular Dependency

The solution lies in exploiting different mathematical properties of each error source:

1. **Steps-per-mm error is proportional**: The error scales with distance
   - If steps-per-mm is 1% high, a 100mm move travels 101mm
   - By measuring TWO different dimensions and taking their difference, constant offsets (backlash + deflection) cancel out
   - The ratio `(d2_measured - d1_measured) / (d2_actual - d1_actual)` reveals only the steps-per-mm error

2. **Backlash is directional and consistent**: It only appears when changing direction
   - Repeated measurements from alternating directions create a bimodal (two-cluster) distribution
   - The separation between clusters equals the backlash magnitude
   - Probe deflection affects both clusters equally (constant offset)
   - Statistical analysis isolates backlash from deflection

3. **Probe deflection is symmetrical and constant**: When probing opposite sides of an object
   - From negative direction (e.g., X-): probe deflects in +X before triggering
   - From positive direction (e.g., X+): probe deflects in -X before triggering  
   - Tip radius is applied directionally in **G6512**; deflection is a positive magnitude per axis
   - For an **external** known-size object (1-2-3 block) with tip compensation on and deflection unset:
     `measured size ≈ actual size − 2 × deflection`
   - Internal features (pockets) read long by roughly `+2 × deflection` when deflection is unset
   - Once steps-per-mm and backlash are correct, deflection can be isolated

**The Calibration Sequence** (touch probe enabled — Phase 1 deflection first and required):
```
Tip radius (Configuration) → Phase 0 datum (confirm) → load probe (tpost G6511 at reference surface)
         ↓
Phase 1: Probe deflection (REQUIRED — no Skip; jobs gated by M4006)
         ↓
Manual: P2 travel (skip OK) → P3 dual-span M92 (skip OK) → P4 backlash refine (skip OK)
   —or—
Probe: G9000 backlash → P3 M92 → optional P4 cluster refine → re-check Phase 1 → Phase 5 verify + Save
```

**TR8×8:** Travel commanded legs are **1× / 2× / 3× of 8 mm lead** → **8 / 16 / 24 mm**.

**Note**: Dual-dimension Phase 3 still cancels constant offsets mathematically; deflection is required early so probe-assisted work and production jobs never run on factory-zero D.

---

## 3. Calibration Procedure

### 3.1 Prerequisites

**Required Equipment:**
- Touch probe (configured in nxt)
- **1-2-3 block** (1″ × 2″ × 3″ = 25.4 mm × 50.8 mm × 76.2 mm) — locked orientation: **3″ parallel to machine X**, **2″ along Y**, **1″ as height (Z)**. Same for A-axis / rotary setups.

**Initial State:**
- Machine must be mechanically assembled and motion system functional
- RRF firmware installed and basic axis configuration completed
- Approximate steps-per-mm values entered in firmware (even if incorrect)
- nxt system loaded
- Touch probe configured (ID, tip radius estimated). **Deflection must be calibrated (Phase 1) before probe-assisted cal and before jobs** — factory `{0,0,0}` is not acceptable when `nxtFeatureTouchProbe` is on.

### 3.2 Procedure Overview

When the touch probe is enabled, **Phase 1 deflection runs first** (after tip radius, Phase 0, and probe load). Manual then continues P2→P3→P4; Probe continues G9000→P3→re-check D. Skip is only for P2/P3/P4.

```
Phase 1: Probe Deflection (REQUIRED first when touch probe on)
         ↓
Phase 2: Travel Backlash Estimate (Manual M5014) — skip OK
         ↓
Phase 3: Precise Steps-per-mm (Dual-Dimension spans) — skip OK
         ↓
Phase 4: Backlash refine (probe cluster or typed means) — skip OK  /  Probe: G9000 then optional P4
         ↓
Phase 5: Verification & Refinement
```

**Why This Order Works**:
- **Phase 1** ensures probe compensation and job starts (`M4006`) never use factory-zero D
- **Phase 2** estimates backlash from dial/probe round-trip (TR8×8: 8/16/24 mm) — not steps/mm
- **Phase 3** achieves precise steps-per-mm using dual-dimension spans that cancel constant offsets
- **Phase 4 / G9000** isolate or refine backlash with accurate steps where needed
- **Phase 5** verifies all calibrations are working together correctly

### 3.2.1 Probe capability matrix

What the Calibration tab (and related cycles) can and cannot do with a touch probe. This matches shipped UI gates in `CalibrationPanel.vue`.

| Item | With probe | Manual / other | Notes |
|------|------------|----------------|-------|
| Tip radius R | — | Configuration only | Wrong R (diameter as radius) poisons D; fix R before Apply |
| Phase 0 datum | Mixed | Jog + `M5016` / toolsetter | V1/V2 ref confirm before probe-assisted work |
| Phase 1 XY deflection | Yes — `M5017` | Single-axis span entry | `newD = currentD + (actual − measured) / 2` |
| Phase 1 Z deflection | **Discarded** | — | Not calibrated or applied; G6512 Z = raw trigger (no D, no tip R). `nxtProbeDeflection[2]` forced 0 |
| Phase 2 travel backlash | — | Dial `M5014` | Manual dial path; round-trip ≠ steps/mm |
| Probe travel backlash | Yes — `G9000` | — | Preferred on solid faces; tip/D cancel in R; UI → **M425** |
| Phase 3 dual-span M92 | Yes — `M5018` outside + G6512 find | Manual span override | Constant δ+b cancel in span difference; not on A |
| Phase 4 backlash refine | Yes — ± free-space approaches | Typed cluster means | `|mean+−mean−|`; not through solid block — use G9000 on 1-2-3 faces |
| Phase 5 / `M6523` | Yes | Checklist | Repeatability at ref or toolsetter |
| A / rotary | Y flatness/center probes | A steps (`M4806` inputs) | **No** A tip/deflection channel; no G9000/M5017 on A |
| Workpiece θ (G68) | Probing cycles (`G6506`…) | — | In-plane stock rotation — not Calibration tab |
| Machine-axis skew / part lean | **Cannot** | Separate geometry work | See [DETAILS.md](DETAILS.md) — RRF has no XY skew matrix beyond G68 |
| Steps/mm from round-trip alone | **Cannot** | Dual-span Phase 3 | `G9000` / `M5014` isolate lost motion only |

### 3.3 Phase 2: Travel Calibration — Backlash Estimate (Manual)

**Goal**: Estimate backlash using a dial indicator on a fixed face (8 / 16 / 24 mm travel legs). Round-trip tests on one surface **do not isolate steps/mm** — use Phase 3 for M92.

**Procedure** (Calibration tab → `M5014`):
1. Secure the 1-2-3 block (**3″∥X**). Select which face you are measuring; travel is **away** from that face.
2. Jog the indicator onto the face and **zero the dial**.
3. For each commanded distance D ∈ {8, 16, 24} mm (optionally 3×):
   - Machine moves away by D, then returns by D
   - Enter dial **residual** R (+ = short of zero after return)
   - `measured = D − R`
4. UI classifies near-constant error → **M425 backlash**; Apply M425 as appropriate. Use Phase 3 for steps/mm.
5. Repeat for other axes as needed.

**Why This Works**:
- Zero → away → return measures **lost motion** (backlash) over known travel without depending on probe deflection
- Near-constant residual across 8/16/24 mm → backlash estimate
- Optional 3× averaging improves consistency

### 3.4 Phase 3: Precise Steps-per-mm Calibration (Dual-Dimension)

**Goal**: Achieve high-precision steps-per-mm calibration using dual-dimension spans (probe face captures or manual entry).

**Concept**:
With approximately correct steps-per-mm, we can achieve precision calibration using the dual-dimension method. This method works even with uncalibrated backlash and unknown probe deflection because these constant errors mathematically cancel out when measuring two different dimensions and taking their difference.

**Mathematical Proof**:
Let:
- `d_actual` = actual dimension of reference object
- `d_measured` = measured dimension from probe
- `δ` = probe deflection (same magnitude on both sides)
- `b` = backlash (appears in measurements)
- `s_current` = current steps-per-mm setting
- `s_actual` = actual steps-per-mm (what we need to find)

When measuring a single dimension with all errors present:
```
d_measured = (s_current / s_actual) × d_actual + 2δ + b
```

But we can eliminate both δ and b by comparing two different dimensions:
```
d1_measured = (s_current / s_actual) × d1_actual + 2δ + b
d2_measured = (s_current / s_actual) × d2_actual + 2δ + b

Subtracting:
d2_measured - d1_measured = (s_current / s_actual) × (d2_actual - d1_actual)

Therefore:
s_actual = s_current × (d2_measured - d1_measured) / (d2_actual - d1_actual)
```

**Both deflection and backlash terms cancel out!** This is why we can calibrate steps-per-mm precisely without knowing these other error sources.

**Procedure for Each Axis (Example: X-axis with 1-2-3 block)**:

1. **Setup**:
   - Install touch probe
   - Secure 1-2-3 block with **3″ parallel to machine X**, 2″ along Y, 1″ as height (Z)
   - For X-axis dual-dimension: use the 2″ and 3″ lengths (pair default `2x3`)

2. **Measure First Dimension (25.4mm side)**:
   - Position probe above the center of the narrow side
   - Probe left surface: `G6512 X{left_target} I{nxtTouchProbeID}`
   - Record: `left1 = nxtLastProbeResult`
   - Move probe across the block
   - Probe right surface: `G6512 X{right_target} I{nxtTouchProbeID}`
   - Record: `right1 = nxtLastProbeResult`
   - Calculate: `measured1 = abs(right1 - left1)`

3. **Measure Second Dimension (50.8mm side)**:
   - Rotate block or reposition to measure the 50.8mm dimension
   - Probe left surface: `G6512 X{left_target} I{nxtTouchProbeID}`
   - Record: `left2 = nxtLastProbeResult`
   - Probe right surface: `G6512 X{right_target} I{nxtTouchProbeID}`
   - Record: `right2 = nxtLastProbeResult`
   - Calculate: `measured2 = abs(right2 - left2)`

4. **Calculate Corrected Steps-per-mm**:
   ```
   actual1 = 25.4  ; mm
   actual2 = 50.8  ; mm
   s_new = s_current × (measured2 - measured1) / (actual2 - actual1)
   ```
   
5. **Apply Correction**:
   - Update firmware: `M92 X{s_new}`
   - Add to config.g for persistence
   - Restart or reload configuration

6. **Verify**:
   - Re-measure both dimensions
   - Both should now read within ±0.02mm of actual dimensions

**Repeat for Y and Z axes** using the appropriate dimensions of the reference block.

**Why Use a 1-2-3 Block**:
The 1-2-3 block is ideal for this calibration because:
- Large dimension differences (25.4mm vs 50.8mm = 25.4mm span) provide better accuracy
- Precision ground surfaces (typically ±0.005mm tolerance)
- The 25.4mm difference in measurements amplifies steps-per-mm errors while canceling constant offsets
- Larger blocks reduce measurement uncertainty compared to gauge pins

**Alternative Single-Dimension Method**:
If probe deflection and backlash have already been measured accurately, a single dimension can be used:
```
s_new = s_current × d_actual / (d_measured - 2δ - b)
```
However, the two-dimension method is more robust as it doesn't require knowing deflection or backlash.

**Automation Implementation**:

Shipped path: Calibration **Phase 3** face buttons (`M5018` raise → outside O=15 → dive → G6512 find → return to center) or Manual span override — **not** `G9000`. `G9000` is probe-mode **backlash** only (8/16/24 mm round-trips → M425). Example dual-span math:

```gcode
; Dual-span steps/mm (conceptual) — UI / M5015 face captures, then:
; measured1 = abs(right1 - left1)   ; e.g. ~50.8 mm face pair
; measured2 = abs(right2 - left2)   ; e.g. ~76.2 mm face pair
; new_steps = current_steps * (measured2 - measured1) / (actual2 - actual1)
; M92 X{new_steps}
```

**UI Component Integration**:

The Calibration tab wizard:
1. Guides block setup and opposing-face captures
2. Computes spans and proposed M92
3. Applies steps and flags Phase 1 deflection re-check after M92
4. Verifies with follow-up measurements

### 3.5 Phase 4: Backlash Measurement & Compensation (refine)

**Goal**: Refine mechanical backlash (M425). **Primary probe path is `G9000`** (Phase / probe-mode travel). Phase 4 cluster means are an optional refine when samples are valid.

**Probe travel residual (`G9000`) — preferred on a solid 1-2-3 face:**

1. Probe face (hit0) toward the surface (`dirToward` = ±1)
2. Command away by D ∈ {8, 16, 24}, then probe again the **same** way (hit1)
3. `R = (hit1 − hit0) × dirToward` ; `measured = D − R`
4. Same approach direction/speed ⇒ **tip radius and stylus deflection cancel in R**
5. With backlash `b` and no M425: `hit1 ≈ hit0 + dirToward×b` ⇒ `R ≈ b`
6. UI `classifyTravelCalibration` proposes M425 = constant intercept of `(measured − D)` vs D (not mean |error|)

**Cluster refine (`|mean+ − mean−|`) — only when both approaches are free-space safe:**

Formula `backlash = abs(mean_positive − mean_negative)` is correct when both sample sets hit the **same** surface from **opposite G6512 approach directions**, after tip/deflection compensation. Deflection cancels between cluster means.

**Do not** start “inside” a solid 1-2-3 block to approach an external face from the far side — that is not free space. For external block faces, use **`G9000`** (or dial `M5014`). Opposite free-space approaches apply to thin webs/fences (air on both sides), not a solid cube face.

**Concept (cluster):**
Backlash causes repeated measurements of the same feature to cluster into two groups when alternating true approach directions; probe deflection is common-mode after G6512 compensation.

**Procedure (cluster, thin feature / free both sides only):**

1. Install touch probe; secure artifact so the target surface has clearance on **both** approach sides
2. Alternate `G6512` toward the surface from − and from + (never through material)
3. `backlash = abs(mean_positive − mean_negative)`
4. Each cluster std-dev should be &lt; ~0.005 mm
5. Apply `M425`; re-run — clusters should collapse

**Dial path (Manual):** `M5014` zero → away → return → residual (same `measured = D − R` identity as G9000).

**UI:** Calibration tab — Probe: Run G9000 then optional Phase 4 samples; Manual: M5014 and/or Phase 4 typed means.
### 3.6 Phase 1: Probe Deflection Measurement (required first)

**Goal**: Measure touch-probe **XY** deflection. Runs **before** Phase 2–4 when the touch probe is enabled (see §3.2). **Z deflection is not calibrated or applied** (G6512 Z uses the raw trigger; `nxtProbeDeflection[2]` stays 0).

**XY — Calibration Probe mode (`M5017 D…`):**
1. Place 1-2-3 with **3″ facing operator (∥ X)**, 2″ ∥ Y
2. Jog to approx **XY center at safe Z** (do not lower into the block)
3. **3-point CCW perimeter:** start −Y near −X; on each face probe near-corner / mid / far-corner (**10 mm** inset from assumed edges); stay at dive Z along the face; raise only between faces
4. Spans from **means** of the three hits per opposing face pair; park at probed center at original safe Z
5. `newD = currentD + (nominal − measured) / 2` per axis
6. Apply `{Dx, Dy, 0}` only when proposed XY D is plausible (typically **0.01–0.05 mm**; **> 0.5 mm** usually means tip **radius** was entered as tip **diameter**)

**G6511 (optional):** Pad probe only if you run `G6511 R1`. Mill length datum is M5016 platen Z. Clears the Z deflection channel when it does run.

**Span identity** (G6512 tip on; \(R\) = configured tip radius, \(D\) = configured deflection):

\[
S = L + 2(R_{\mathrm{true}} - R) + 2(D - D_{\mathrm{phys}})
\]

Shortfall \(\Delta = L - S = 2[(R - R_{\mathrm{true}}) + (D_{\mathrm{phys}} - D)]\). Entering tip diameter as radius (e.g. `2` for a 2 mm ball → true \(R=1\)) shortens both spans by ~**2 mm** and makes naive \(D\) look ~1 mm — fix tip radius and re-run before Apply.

**Update nxt:** Persist via Calibration / Configuration **Save** → `nxt-user-vars.g`. A-axis has no linear tip/deflection channel. Z deflection discarded for now.

### 3.7 Phase 5: Verification & Refinement

**Goal**: Verify all calibrations are working together correctly.

**Procedure**:

1. **Dimensional Verification**:
   - Measure multiple features on the reference block using probing cycles
   - All measurements should be within ±0.02mm of actual dimensions
   - Test different feature sizes to verify proportional accuracy

2. **Backlash Verification**:
   - Probe the same surface from opposite directions multiple times
   - Position difference should be < 0.01mm
   - If larger, backlash compensation may need adjustment

3. **Repeatability Test**:
   - Probe the same feature 10 times without moving the part
   - On a nxt machine with touch probe or toolsetter configured, run **`M6523`** (e.g. `M6523 B0 C10` at the touch reference, or `M6523 B1 C10` at the toolsetter) — see [GCODE.md](../GCODE.md) and `macros/utilities/M6523.g`
   - Review echoed min / max / **range** / mean; range should be **< 0.005 mm** for a good setup
   - Tune pair tolerance via `nxt-user-overrides.g` or Configuration repeatability notes if range exceeds `L`

4. **Directional Test**:
   - Probe surfaces from both positive and negative approach directions
   - Measurements should be consistent within ±0.01mm
   - Verifies both backlash compensation and deflection compensation

5. **Real-World Verification**:
   - Create a simple test part with known dimensions (e.g., rectangular pocket)
   - Machine the part and measure with calibrated touch probe
   - Measurement should match CAD dimensions within machine capability

**Refinement**:
If verification reveals errors:
- **Proportional errors**: Revisit steps-per-mm calibration
- **Directional inconsistency**: Check backlash compensation
- **Fixed offset on all measurements**: Verify probe deflection value
- **Large scatter in repeated measurements**: Check mechanical issues (loose probe, spindle runout, etc.)

---

## 4. Implementation in nxt

### 4.1 Calibration tab (guided wizard)

The **Calibration** tab on the main nxt dashboard (`ui/src/nxt.vue` → `CalibrationPanel.vue`) implements Option A below. Configuration’s “go to calibration” control switches to that tab (`nxt-goto-calibration` / `?tab=calibration`). Cross-link: static datum details in [TOOLSETTING.md](TOOLSETTING.md).

**Phase 0 — Probe / datum setup** (when touch probe + toolsetter are enabled but `nxtTouchProbeRefPos` or `nxtDeltaMachine` is unset):

1. `M5016` — launched from Calibration (must run from DWC; **not** gated on motion-system `thisInput.active`). Uses M291 **S2/S3** (jog axes require S2/S3; avoids S4/`M292 R{n}` channel races). Ack is **stock DWC modal only** (nxt does not mount a second Action Required widget). On **standalone** (no SBC), nxt forces `M292` with `noWait` at plugin load so sequential prompts do not hang after the first OK (DWC 3.6 workaround; see [UI_IMPLEMENTATION.md](UI_IMPLEMENTATION.md#standalone-no-sbc-m292-must-not-await-replies)). Verify configured toolsetter input (press platen) → jog ~20 mm above platen → probe for `nxtToolSetterPos`, then:
   - **V1:** mill paper-touch on the reference surface (not a probe trigger) → set `nxtTouchProbeRefPos` → `nxtDeltaMachine = Z_ref - Z_act`. Later **G6511** seeks **`nxtToolSetterProbeTravelMm`** (default 80 mm) past that Z.
   - **V2.0** (`nxtToolSetterV2` + `nxtToolSetterRefDir`): compute ref pad at ±13 mm XY from platen and `Z_ref = Z_act − 6`, then **jog-confirm** near that pad (never info-only). Mill datum is platen `Z_act`, not a later G6511.
2. **Enable Probe** (`G53 G0 Z{move.axes[2].max}` → `T{nxtProbeToolID}`) — raises to machine Z **maximum** (safe up), then installs the probe tool. Install/remove/`nxt-probe-sensor-wait` prompts use **S4** OK/Cancel (soft Cancel; **no** `abort` in the T-stack). Ack is stock DWC modal only. **Never** rapids to WCS Z0 (workpiece). Same control on the Probing tab. Does **not** send G6511 itself; probe **`tpost`** runs **`G6511 R1 S0`** at **`nxtTouchProbeRefPos`** when datum is complete (else soft-skips).
3. **Save** persists positions + delta to `nxt-user-vars.g`

**Readiness (Calibration UI):** When touch probe or toolsetter is enabled, Phase 0 shows a live checklist (features, sensor IDs/slots, probe tool, datum quartet, tool-change idle, axes homed). **Run M5016** is blocked only by hard preflight that the macro itself needs (features, configured `nxtTouchProbeID`, live toolsetter slot, axes/TC idle) — not by a live tip slot or probe tool (those are for **Enable Probe** after datum). **Enable Probe** also requires tip slot/type, probe tool, and ref/delta.

#### Remote machine stuck on prompts

If your machine completes M5016 / Enable Probe but another does not, treat it as **config / sensors / DWC skew**, not a missing macro path:

1. **Calibration checklist** — clear all red items; press tip and platen so `sensors.probes[K].value` crosses threshold (IDs alone are not enough).
2. **Console dump** (RRF uses `^` for string concat, not `+`):

```text
echo {"TP=" ^ global.nxtFeatureTouchProbe ^ " TS=" ^ global.nxtFeatureToolSetter}
echo {"probeTool=" ^ global.nxtProbeToolID ^ " touchK=" ^ global.nxtTouchProbeID ^ " setK=" ^ global.nxtToolSetterID}
echo {"setterPos=" ^ global.nxtToolSetterPos}
echo {"refPos=" ^ global.nxtTouchProbeRefPos}
echo {"delta=" ^ global.nxtDeltaMachine ^ " virtual=" ^ global.nxtProbeVirtualTsZ}
echo {"tcState=" ^ global.nxtToolChangeState ^ " tcCancel=" ^ global.nxtToolChangeCancelled}
echo {sensors.probes[global.nxtTouchProbeID].value[0]}
echo {sensors.probes[global.nxtToolSetterID].value[0]}
```

3. **Sync** hardened `tpre`/`tfree`/`tpost`/`nxt-probe-sensor-wait` + a plugin ZIP built for the host DWC version exactly.
4. Status stuck **Changing Tool** with `nxtToolChangeState` null → **`M999`** (no RRF clear API).

**Mode:** When the touch probe feature is ready, choose **Manual (1-2-3)** or **Probe**. Probe-assisted moves require the probe tool installed (Enable Probe). Phase 0 datum remains recommended for mill length (M5016 platen Z) / deflection height, but does not hard-block probe mode.

**Recommended order (both modes, touch probe enabled):**

1. Tip radius (Configuration)
2. Phase 0 datum (with location confirms) — Save ref before height checks
3. Load probe (Enable Probe; tpost G6511 R1 S0 at nxtTouchProbeRefPos; L1 Z0)
4. **Phase 1 deflection — required**: XY via `M5017 D…` (dive + 5 mm face clearance, 10 mm corner inset); Apply `{Dx, Dy, 0}`
5. Manual: P2 travel → P3 M92 → P4 backlash refine — **or** Probe: `G9000` → P3 → optional P4 cluster refine → re-check D after M92
6. Phase 5 verify + Save

**Skip:** Allowed only for Manual P2 / P3 / P4 (and optional verify items). **Not** for Phase 0 when required, Phase 1 deflection, or post-M92 deflection re-check.

**Jobs:** When `nxtFeatureTouchProbe` is true, `M4005` runs **`M4006`**, which aborts if deflection is unset / factory zero. Tip radius alone is not enough.

**TR8×8 travel legs:** Default lead `8` mm → commanded distances **8 / 16 / 24** mm (`1× / 2× / 3×` lead). Nominal steps hint `(200 × microsteps × gear) / 8` (e.g. 800 @ 32 µstep). Encoded in `travelCommandedLegs()` / `nominalStepsPerMm()`.

**Manual XYZ (phases after D):** Assumes a **1-2-3 block** with **3″∥X, 2″∥Y, 1″∥Z**. Phase 2 (`M5014`): pick block face → zero dial → away/return at **8 / 16 / 24 mm** → enter residual. Optional **3×** average per leg. UI estimates **M425 backlash only** — use Phase 3 for steps/mm. Phase 3 assist (`M5018` outside + probe-find): capture opposing faces (L1/R1/L2/R2) and compute spans — X uses 3″ ends, Y uses 2″ sides in the locked pose (no reorient required for that size). Phase 4: ±-direction samples or typed means → M425.

**Probe mode:** Phase 1 (XY `M5017`; Z D unused) → `G9000` travel backlash → Phase 3 dual spans → optional Phase 4 cluster refine → re-check D → Phase 5. Deflection must be confirmed before `G9000`.

**Session persistence (UI):** Mid-wizard values (face captures, travel table, `pending*` Apply bridge, mode/axis) and a **deflection confirm fingerprint** live in DWC plugin settings as `nxtCalSession`. Leaving the Calibration tab or `/nxt` restores that progress on return. **Confirm deflection** is not re-prompted while OM `nxtProbeDeflection` still matches the last confirmed vector (unless M92 set a recheck). Durable machine values still require **Apply** + **Save** (`nxt-user-vars.g`). After a successful Save, wizard captures clear but the confirm fingerprint is kept.

**A / rotary:** Shown only when both are true:

1. DWC plugin **`MosFourthAxis`** is installed ([MOS Fourth Axis](https://github.com/MillenniumMachines/mos-fourth-axis) sibling pack).
2. Object model has a visible **A** axis.

| Macro | Role |
|-------|------|
| `M4912` | Y flatness / tilt on rotary |
| `M4910` | Probe rotary Y center |
| `M4807 W…` | Optional: apply stored Y center as Y0 to WCS |
| `M4806 V…` | Apply A steps/mm (`M92 A` + `rotaryAStepsPerMm`) |
| `M5014` | Phase 2: zero dial → away/return 8/16/24 → residual → backlash estimate (not M92) |
| `M5015` | Phase 3: G6512 + return; optional `J0` skips jog when after `M5018` |
| `M5016` | Phase 0 static datum (jog-confirm when establishing ref) |
| `M5017` | Phase 1 XY spans: `D` dive, O=5 face clearance, 10 mm corner inset, 3-pt perimeter |
| `M5018` | Phase 3: raise → outside O=15 → dive → G6512 find edge; default return to center; `R0` stay out (G9000) |
| `G6511` | Optional pad probe (`R1`); skips if mill virtual already set from M5016; clears Z D / `nxtCalDefZ` |
| `G9000` | Probe-mode 8/16/24: probe → away → re-probe ×3 per leg (backlash only); XY via `M5018 … R0` then `J0 H±1` |
| `M4005` / `M4006` | Job preamble: version check + require non-zero deflection when touch probe on |

**Save calibration:** uploads `nxt-user-vars.g` (`nxtProbeDeflection`, `nxtTouchProbeRefPos`, `nxtToolSetterPos`, `nxtDeltaMachine`, finite **`nxtProbeVirtualTsZ`**; on **Custom** also `nxtCustom*Steps` / `nxtCustom*Backlash`). Blocked when touch probe is on and D is unset / factory zero / recheck pending. On **Custom** platform, also regenerates pack overlays (`steps.g`, `drives-overlay.g` with `M425`).

### 4.2 Implementation Approach

Two implementation approaches are possible:

#### Option A: UI-Based Calibration Wizard (shipped)
- **Advantages**:
  - User-friendly step-by-step workflow
  - Visual feedback and progress indication
  - Can show real-time measurements and calculations
  - Easier to guide user through complex procedure
  - Can validate measurements and provide warnings

- **Implementation**:
  - **Calibration** tab + `CalibrationPanel.vue` (phases 1–5 + gated A section)
  - UI guides user through each phase with instructions
  - Optional `G6512` / fourth-axis M-codes; capture `nxtLastProbeResult`
  - Calculations in `nxtCalibrationMath.ts`
  - Persist via user-vars (+ Custom overlays on Save)

#### Option B: G-code Macro Based (Alternative)
- **Advantages**:
  - Works without UI
  - Self-contained in macro system
  - Can be triggered from any G-code sender

- **Implementation**:
  - Create G-code macro (e.g., G6599 or M9000)
  - Uses M291 dialogs for user interaction
  - Prompts for reference block dimensions
  - Executes probe commands and calculations
  - Updates nxt-user-vars.g with results

### 4.3 Recommended Workflow Integration

**In Configuration / Calibration UI:**

1. **Calibration entry**:
   - Configuration links to the Calibration tab
   - Tab shows current steps/mm, backlash, and deflection from the object model

2. **Calibration Wizard Flow**:
   ```
   Phase 1: Rough Steps-per-mm (Manual)
            - Instructions for manual measurement
            - Input fields for measured distances
            - Calculate and apply M92
            
   Phase 2: Precise Steps-per-mm (Dual-dimension)
            - For each axis:
              * Probe/measure two different dimensions
              * Optional G6512 + capture nxtLastProbeResult
              * Calculate correction and Apply M92
              
   Phase 1: Probe Deflection
            - Probe known dimension (M5017)
            - Update nxtProbeDeflection
              
   Phase 2: Travel Backlash Estimate
            - Dial / M5014 legs
              
   Phase 3: Dual-Dimension Steps
            - Probe/measure two different dimensions
            - Optional G6512 + capture nxtLastProbeResult
            - Calculate correction and Apply M92
              
   Phase 4: Backlash Measurement
            - Means from +/− approaches (or captured samples)
            * Optional scatter plot (off by default)
            * Apply M425
              
   Phase 5: Verification
            - Checklist + optional M6523
            - Save calibration (user-vars + Custom overlays)
   ```

3. **Calibration Results Storage**:
   - `0:/sys/nxt-user-vars.g` for globals (`nxtProbeDeflection`; Custom: `nxtCustomX/Y/Z/ASteps`, `nxtCustom*Backlash`)
   - Custom platform: regenerate `0:/sys/nxt-user-custom/steps.g` and `drives-overlay.g` (`M92` / `M425`)
   - A steps also kept consistent with MosFourthAxis via live `M4806`

### 4.4 API Requirements

**Backend Macros Needed**:
- Existing `G6512` (single-axis probe) - already implemented ✓
- Existing `M5000` (machine position query) - already implemented ✓
- MosFourthAxis (when installed): `M4912`, `M4910`, `M4807`, `M4806`

**UI Integration Points**:
- Read current calibration values from object model (`move.axes[].stepsPerMm`, `move.axes[].backlash`, `rotaryAStepsPerMm`)
- Execute probe / rotary commands via G-code
- Update firmware parameters via `M92` / `M425` / `M4806` and `set global.nxtProbeDeflection`
- Persist via `nxt-user-vars.g` (+ Custom pack overlays)

### 4.5 Error Handling

**Common Issues & Solutions**:

1. **Probe Fails to Trigger**:
   - Check probe mounting and electrical connection
   - Verify probe ID is correct in configuration
   - Ensure target position is beyond the expected surface

2. **Measurements Inconsistent**:
   - Check mechanical rigidity (loose parts, worn bearings)
   - Verify reference block is properly secured
   - Ensure work surface is clean and free of debris
   - Check for spindle/probe holder runout

3. **Calculated Values Unreasonable**:
   - Verify reference block dimensions entered correctly
   - Check that probe is approaching from correct directions
   - Ensure machine is homed properly before starting

4. **Compensation Makes Things Worse**:
   - May indicate mechanical problems (binding, friction)
   - Steps-per-mm may be drastically wrong (>5% error)
   - Recommend manual verification before accepting values

**Safety Checks**:
- Limit maximum adjustment per iteration (e.g., ±5% steps-per-mm change)
- Require operator confirmation before applying changes
- Store backup of previous values
- Provide rollback option if results are poor

---

## 5. Expected Accuracy

With proper calibration following this procedure, the machine should achieve:

- **Steps-per-mm accuracy**: < 0.1% (±0.1mm per 100mm of travel)
- **Backlash compensation**: < 0.01mm residual error
- **Probe deflection compensation**: < 0.01mm residual error
- **Overall probing accuracy**: ±0.02mm for features > 10mm
- **Repeatability**: < 0.005mm standard deviation

These accuracies assume:
- Reasonable mechanical quality (hobby CNC or better)
- Proper machine assembly and tramming
- Quality touch probe (±0.01mm repeatability)
- Precision reference block (±0.01mm tolerance)

---

## 6. Roadmap Integration

This calibration system should be implemented in **Phase 4** of the nxt development roadmap.

**Justification**:
- Requires stable probing engine (Phase 1) ✓
- Requires UI framework for wizard (Phase 2)
- Benefits from probe results management (Phase 3)
- Enhances overall system accuracy for advanced features

**Phase 4 Addition**:
```markdown
## Phase 4: Tool Change & Advanced Features

...existing items...

4. **Machine Calibration System:**
   * Implement UI-based calibration wizard in Settings panel
   * Create M-code macros for querying and updating calibration parameters
   * Implement automated steps-per-mm calibration using dual-dimension method
   * Implement automated backlash measurement and compensation
   * Implement automated probe deflection measurement
   * Add calibration verification and reporting
   * Document calibration procedure and best practices
```

---

## 7. References

### Related Documentation
- `docs/CODE.md` - nxt coding standards and conventions
- `docs/FEATURES.md` - Feature requirements and implementation status
- `docs/ROADMAP.md` - Development phases and timeline
- `GCODE.md` - Custom G-code and M-code reference

### RRF Firmware Commands
- `M92` - Set steps per mm
- `M425` - Backlash compensation
- `G38.2` - Probe toward workpiece (used by G6512)
- Object Model: `move.axes[].stepsPerMm` - Query current settings

### External Resources
- RepRapFirmware Object Model Documentation
- Touch Probe Selection and Setup Guide
- CNC Machine Tramming and Alignment Procedures

---

## Appendix A: Quick Reference

### Calibration Sequence Summary
```
1. Manual travel backlash → estimate M425
2. Dual-dimension spans → M92 steps/mm
3. Probe backlash → Measure & compensate via statistical drift
4. Probe deflection → Measure with known object
5. Verify → Test accuracy and repeatability
```

### Key Formulas

**Steps-per-mm Correction (Manual)**:
```
new_steps = current_steps × (commanded / actual_measured)
```

**Steps-per-mm Correction (Automated, dual-dimension)**:
```
new_steps = current_steps × (d2_measured - d1_measured) / (d2_actual - d1_actual)
measured = abs(right_face - left_face)   ; per size
```

**Probe Deflection** (external block, tip radius in G6512):
```
; S = L + 2(R_true − R) + 2(D − D_phys)
new_deflection = current_deflection + (actual - measured) / 2
; If proposed D > 0.5 mm, check tip RADIUS (not diameter) before Apply
```

**Backlash**:
```
backlash = abs(probe_result_positive - probe_result_negative)
```

### Reference Block Dimensions (1-2-3 Block)
- Side 1: 1 inch = 25.4 mm — **along Z** (height)
- Side 2: 2 inches = 50.8 mm — **along Y**
- Side 3: 3 inches = 76.2 mm — **along X** (parallel to machine X)
- Typical tolerance: ±0.0002 inches (±0.005 mm) or better

**Locked orientation (Calibration tab):** place the block so the **3″ edge is parallel to X** for all XYZ and A-axis work.

---

*Last Updated: 2024-01-15*
*Document Version: 1.0*
