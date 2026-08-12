# nxt Custom G-Code and M-Code Reference

This document provides reference documentation for custom G-codes and M-codes implemented in nxt.

## Table of Contents

- [G-codes](#g-codes)
  - [G27](#g27-parking)
  - [G37](#g37-tool-length-probe)
  - [G6500](#g6500-bore-probe) … [G6600](#g6600-workpiece-probing-gateway)
- [M-codes](#m-codes)
  - [M3.9 / M4.9 / M5.9](#m39-m49-m59-spindle-control)
  - [M7 / M7.1 / M8 / M9](#m7-m71-m8-m9-coolant-control)
  - [M80.9 / M81.9](#m809-m819-atx-power-control)
  - [M4000](#m4000-define-tool) … [M6525](#m6525-prepare-for-plugin-update)
- [Global Variables](#global-variables)
- [Workflow Examples](#workflow-examples)

---

## G-codes

### G27: Parking

Moves the machine to a safe, known parking position.

RRF homing uses `0:/sys/homeall.g`, `homex.g`, `homey.g`, `homez.g`, and optionally `homea.g`. nxt vendors homing sources under `nxt-config/machine/<profile>/` and deploys them from the Configuration panel (not loaded at boot). **Home all** order: Z → A (if `homea.g` present) → X+Y together. See [docs/NXT_BOARD_HOMING.md](docs/NXT_BOARD_HOMING.md) for axis directions and verification.

**Usage:** `G27 [X<level>] [Y<level>] [Z<level>]`

**Parameters:**
- `X|Y|Z`: Parking level (0-2), where higher levels are safer/further from workpiece

---

### G37: Tool Length Probe

Measures the active tool on the configured toolsetter (single **G6512** Z probe at `nxtToolSetterPos`).

**Usage:** `G37`

**Requirements:** `nxtToolSetterPos`, `nxtToolSetterID`, tool loaded over setter.

---

### G6500: Bore Probe

Uses **three triangulated** inward touches at **0° / 120° / 240°** via **`G6513`** (same geometry family as **`G6500.1`**). The circle center is the **circumcenter** of the three contacts. Stays at dive Z between touches (`D1 H1` — no raise to start Z while triangulating). Repositioning uses **`G6550`** protected moves; each radial contact uses **`G6512.1`**. No approach clearance (start inside the bore) — use accurate **`D`** + **`O`**. Ends at the circumcenter XY at start Z.

**Usage:** `G6500 P|U D<diameter> L<depth> [F<speed>] [R<retries>] [O<overtravel>] [T] [Q]`

**Parameters:**
- `P` or `U`: Result row **`P`** (0–9) **or** target workplace **`U`** (1–9) — **REQUIRED** (one of)
- `D`: Bore diameter for move planning (mm) - **REQUIRED**
- `L`: Depth to **drop** into bore before probing (mm), relative to **current machine Z at execute time**. Cycles do not park/raise before the dive — jog to start height first. - **REQUIRED**
- `F`: Optional speed override (mm/min; reserved — radial probes use probe `M558` speeds via **`G6512.1`**)
- `R`: Retry / sample budget passed through to **`G6513`** / **`G6512.1`** (default: `global.nxtProbeInnerSampleCount`)
- `O`: Overtravel distance beyond expected surface (default: 2mm; reduced by tool radius when available)
- `T`: Max |skew| in degrees — angular registration of the 0° hit vs **+X** from the circumcenter (default: `global.nxtProbeMaxSkewDeg`)
- `Q`: **`M6520`** rotation policy when **`U`** is used

**Results:** Stores X and Y center coordinates in the probe results table.

> **RRF meta note:** `^` is string/array **concatenation**, not exponentiation. Probe geometry uses `dx*dx` / `pow(dx,2)` for squares. See [docs/RRF_META_PITFALLS.md](docs/RRF_META_PITFALLS.md) for dive/`startZ`, A-axis, and hit-buffer constraints.

---

### G6501: Boss Probe

Probes a circular boss from the outside with **three triangulated** OD touches at **0° / 120° / 240°** via **`G6513`** (same geometry family as **`G6501.1`**), then the same **circumcenter** fit as **`G6500`**. Raises to jogged **start Z** between touches. Repositioning uses **`G6550`** protected moves; each radial contact uses **`G6512.1`**. Ends at the circumcenter XY at start Z.

**Usage:** `G6501 P|U D<diameter> L<depth> [F<speed>] [R<retries>] [C<clearance>] [O<overtravel>] [T] [Q]`

**Parameters:**
- `P` or `U`: Result row **`P`** (0–9) **or** target workplace **`U`** (1–9) — **REQUIRED** (one of)
- `D`: Boss diameter for move planning (mm) - **REQUIRED**
- `L`: Depth to move down before probing (mm) - **REQUIRED**
- `F`: Optional speed override (mm/min; reserved — see **`G6500`**)
- `R`: Retry / sample budget passed through to **`G6513`** / **`G6512.1`** (default: `global.nxtProbeInnerSampleCount`)
- `C`: **Approach clearance** — outside air gap before OD touch (default: **5** mm; same role as **G6503** outside clearance; tool radius is added when available)
- `O`: Overtravel distance beyond expected surface (default: 2mm; reduced by tool radius when available)
- `T`, `Q`: Same as **`G6500`**

**Results:** Stores X and Y center coordinates in the probe results table.

---

### G6502: Rectangle Pocket Probe

Probes all 4 edges of a rectangular pocket in X and Y to find the center.

**Usage:** `G6502 P<index> W<width> H<height> L<depth> [F<speed>] [R<retries>] [O<overtravel>]`

**Parameters:**
- `P`: Result table index (0-9) - **REQUIRED**
- `W`: Pocket width in X direction (mm) - **REQUIRED**
- `H`: Pocket height in Y direction (mm) - **REQUIRED**
- `L`: Depth to move down into pocket before probing (mm) - **REQUIRED**
- `F`: Optional speed override (mm/min)
- `R`: Number of retries for averaging per probe point
- `O`: Overtravel distance (default: 2mm)

**Results:** Stores X and Y center coordinates in the probe results table.

---

### G6503: Rectangle Block Probe

Probes all 4 faces of a rectangular block from outside to find the center. **3 points per face** (near-corner, mid, far-corner) with edge inset **`E`** (default **10** mm). Stays at dive Z along a face; raises to start Z only between faces. CCW perimeter starting at the −Y face near −X.

**Usage:** `G6503 P<index>|U<wcs> W<width> H<height> L<depth> [F] [R] [C] [O] [E] [T] [Q]`

**Parameters:**
- `P`: Result table index (0-9) — required if `U` omitted
- `U`: Target workplace 1–9; stores at `P=U-1` and chains `M6520`
- `W`: Block width in X (mm) — **REQUIRED**
- `H`: Block height in Y (mm) — **REQUIRED**
- `L`: Dive depth below start Z before side probes (mm) — **REQUIRED**
- `F`: Optional speed override (mm/min)
- `R`: Inner sample count per probe point
- `C`: Outside face clearance (default: **5** mm)
- `O`: Overtravel past expected face into the block (default: 2 mm)
- `E`: Corner clearance / edge inset for outer points (default: **10** mm); must be less than half W and half H
- `T`, `Q`: Skew limit and `M6520` rotation policy

**Results:** Face means → `nxtProbeHitXY` H0–H3 → center / skew / size in `nxtProbeResults`. Parks at solved center.

---

### G6504: Web Probe (X/Y)

Probes a web (block) in either X or Y to find the center point on that axis.

**Usage:** `G6504 P<index> N<axis> D<dimension> L<depth> [F<speed>] [R<retries>] [C<clearance>] [O<overtravel>]`

**Parameters:**
- `P`: Result table index (0-9) - **REQUIRED**
- `N`: Axis to probe (0=X, 1=Y) - **REQUIRED**
- `D`: Web dimension on specified axis (mm) - **REQUIRED**
- `L`: Depth to move down before probing (mm) - **REQUIRED**
- `F`: Optional speed override (mm/min)
- `R`: Number of retries for averaging
- `C`: Clearance distance (default: 5mm)
- `O`: Overtravel distance (default: 2mm)

**Results:** Stores coordinate on specified axis in the probe results table.

---

### G6505: Pocket Probe (X/Y)

Probes a pocket in either X or Y to find the center point on that axis.

**Usage:** `G6505 P<index> N<axis> D<dimension> L<depth> [F<speed>] [R<retries>] [O<overtravel>]`

**Parameters:**
- `P`: Result table index (0-9) - **REQUIRED**
- `N`: Axis to probe (0=X, 1=Y) - **REQUIRED**
- `D`: Pocket dimension on specified axis (mm) - **REQUIRED**
- `L`: Depth to move down into pocket (mm) - **REQUIRED**
- `F`: Optional speed override (mm/min)
- `R`: Number of retries for averaging
- `O`: Overtravel distance (default: 2mm)

**Results:** Stores coordinate on specified axis in the probe results table.

---

### G6506: Rotation Probe

Probes 2 points along a surface in X or Y to find the rotation angle.

**Usage:** `G6506 P<index> N<axis> D<depth> S<spacing> [F<speed>] [R<retries>] [O<overtravel>]`

**Parameters:**
- `P`: Result table index (0-9) - **REQUIRED**
- `N`: Axis to probe (0=X, 1=Y) - **REQUIRED**
- `D`: Depth/distance parameter - **REQUIRED**
- `S`: Spacing between probe points (mm) - **REQUIRED**
- `F`: Optional speed override (mm/min)
- `R`: Number of retries for averaging
- `O`: Overtravel distance (default: 2mm)

**Results:** Stores rotation angle in degrees in the probe results table.

---

### G6508: Outside Corner Probe

Probes an assumed-90-degree outside corner to find the intersection point.

**Usage:** `G6508 P<index> N<axis> L<depth> [F<speed>] [R<retries>] [C<clearance>] [O<overtravel>]`

**Parameters:**
- `P`: Result table index (0-9) - **REQUIRED**
- `N`: Primary axis (0=X, 1=Y) - **REQUIRED**
- `L`: Depth to move down before probing (mm) - **REQUIRED**
- `F`: Optional speed override (mm/min)
- `R`: Number of retries for averaging
- `C`: Clearance distance (default: 10mm)
- `O`: Overtravel distance (default: 2mm)

**Results:** Stores X and Y corner coordinates in the probe results table.

---

### G6509: Inside Corner Probe

Probes an assumed-90-degree inside corner to find the intersection point.

**Usage:** `G6509 P<index> N<axis> D<approximate_distance> L<depth> [F<speed>] [R<retries>] [O<overtravel>]`

**Parameters:**
- `P`: Result table index (0-9) - **REQUIRED**
- `N`: Primary axis (0=X, 1=Y) - **REQUIRED**
- `D`: Approximate distance from start to corner (mm) - **REQUIRED**
- `L`: Depth to move down into corner (mm) - **REQUIRED**
- `F`: Optional speed override (mm/min)
- `R`: Number of retries for averaging
- `O`: Overtravel distance (default: 2mm)

**Results:** Stores X and Y corner coordinates in the probe results table.

---

### G6510: Single Surface Probe

Probes exactly one axis. **Z** is G6512 **raw trigger** (no deflection, no tip radius). With **`U`**, chains **`M6520 … Z1`** so that height becomes work **Z0**, then returns to jog **startZ** (`G53 G0 Z{startZ}`). Without **`U`**, Z cycles still return to **startZ**. DWC Probing Cycles UI for **Z** asks for a positive **travel distance** and converts to absolute machine `Z = currentMachineZ − travel` at execute; the meta still takes absolute `X|Y|Z`.

**Usage:** `G6510 P<index>|U<wcs> [X<target>|Y<target>|Z<target>] [F<speed>] [R<retries>]`

**Parameters:**
- `P`: Result table index (0-9), or **`U`** 1–9 (store at `U−1` and apply that WCS)
- `X|Y|Z`: Exactly one axis target coordinate - **REQUIRED**
- `F`: Optional speed override (mm/min)
- `R`: Number of retries for averaging

**Results:** Stores coordinate on specified axis in the probe results table.

---

### G6511: Reference Surface Probe

Emitted by Fusion/FreeCAD post-processors during job preamble / WCS changes, and by `tpost.g` after every probe install. Probes the **saved** touch-probe reference surface when **both** touch probe and toolsetter are enabled. No-op if already probed this session unless `R1`.

**Does not** jog-confirm over the reference — location is established in Phase 0 / `M5016` + Save. Tip install + trigger confirm happens in `tpre` / `nxt-probe-tool-ready`.

**Usage:** `G6511 [R1] [S0]`

**Parameters:**
- `R1`: Force re-probe (clears session skip)
- `S0`: Non-standalone — do not switch to probe tool (nested call from `tpost.g`)

**Requirements:** `nxtTouchProbeRefPos`, `nxtDeltaMachine` configured in DWC. V2 also needs `nxtToolSetterPos`.

**Speeds:** Fast find capped at **200 mm/min**, slow validate at **50 mm/min** (configured probe speeds clamped down to these maxima).

**Motion (V1 and V2):** `G53 Z0` → ref XY → drop to **Z max** → **fast** `G6512` (≤200 mm/min) → **short slow** validate (target ≈ fastHit − 2 mm, ≤50 mm/min, with pair averaging) → mean → `nxtLastProbeResult`. Clears Z deflection channel (`nxtProbeDeflection[2]=0`); does **not** propose rough Dz (`nxtCalDefZ` → null).

**Probe target:** V1 seeks toward saved **`refZ`**. V2 (`nxtToolSetterV2`) seeks toward **`Z_act − 8`** (deeper overtravel past the pad).

Temporarily zeros Z deflection during hits, then restores.

**Results:** Sets `global.nxtRefSurfaceProbed`, `global.nxtLastProbeResult`; clears `nxtCalDefZ`.

---

### G6512: Single-Axis Probing (Core)

Low-level single-axis probe move with compensation and averaging. Used by all probing cycles. Callers must pass **exactly one** of `X|Y|Z|A` (position with `G6550`/`G0` first). Enforced by `node dist/check-g6512-axis-contract.mjs`.

**Compensation** (touch probe only — when `I == global.nxtTouchProbeID`; toolsetter IDs skip tip/deflection):
- `global.nxtProbeDeflection = {X,Y,Z}` positive magnitudes (mm). Legacy scalar / `{X,Y}` still load (`Z` falls back to `X`).
- Approach direction `dir = sign(target − start)`.
- **X/Y surface:** `result = trigger + dir × (tipRadius − deflection)`
- **Z surface contact:** `result = trigger` (**no** deflection, **no** tip radius — Z D discarded for now)
- **A:** no linear tip/deflection compensation

**Limits:** `M6515` checks **only the probed axis** target (held axes are not pre-checked). After each touch, post-trigger **backoff** (`diveHeights`) is **clamped** into that axis soft `min`/`max` so a Z probe near Z max (often `0`) does not command G1 outside machine limits.

**Speeds (touch probe):** Fast/slow clamped to **≤200 / ≤50** mm/min (same caps as G6511), regardless of M558 or `F` override. Toolsetter IDs are not clamped here.

**Repeatability:** Defaults are **`macros/system/nxt-vars.g`** (`nxtProbeInnerSampleCount`, **`nxtProbeMaxSampleSpreadMm`** default **0.0075** mm, **`nxtProbeSampleOuterRetries`**). Override via **`0:/sys/nxt-user-overrides.g`** (loaded **last** in **`nxt.g`**; see **`nxt-user-overrides.g.example`**). When **`nxtProbeMaxSampleSpreadMm` > 0**, **`G6512`** runs **3** touches ( **`R`** is ignored), **`echo`s** each compensated value, and requires **both** consecutive pairs (1–2 and 2–3) to be within the limit. On failure it **`echo`s** the pair delta and over-limit amount, then repeats the whole 3-touch block up to **`1 + nxtProbeSampleOuterRetries`** cycles. On success it averages the three values into **`nxtLastProbeResult`**. Set **`nxtProbeMaxSampleSpreadMm`** to **0** to disable (honors **`R`** / **`nxtProbeInnerSampleCount`**, no pair checks).

**Usage:** `G6512 [X<pos>|Y<pos>|Z<pos>|A<pos>] I<probeID> [F<speed>] [R<retries>] [H<hit>]`

**Parameters:**
- `X|Y|Z|A`: Exactly ONE axis parameter must be provided - **REQUIRED**
- `I`: Probe ID (e.g., touch probe or tool setter) - **REQUIRED**
- `F`: Optional speed override (mm/min)
- `R`: Inner sample count for averaging (default: `global.nxtProbeInnerSampleCount`)
- `H`: Optional hit index 0..3 for `(X,Y)` into `global.nxtProbeHitXY`

**Results:** Stores compensated result in `global.nxtLastProbeResult`.

**Note:** After the direction-signed deflection fix, recalibrate Phase 1 deflection values — older stored deflections are not portable.

---

### G9000: Probe Travel Backlash (8 / 16 / 24)

Probe-mode travel residual test on one axis (TR8×8 legs). Estimates **backlash only** — use Phase 3 dual spans for steps/mm.

**Usage:** `G9000 X0 | Y0 | Z0 [J0] [H±1]`

**Parameters:**
- Exactly one of `X|Y|Z` (value ignored; axis select only)
- `J0`: skip jog `M291` when already at approach (e.g. after `M5018`)
- `H`: toward-surface direction (`+1` / `-1`); **required with `J0`**, otherwise prompted

**Calibration UI (XY):** save center → `M5018` to the − face (`O=15`, dive, probe-find, `R0` stay out) → `G9000 {axis}0 J0 H1` → raise + park at saved center. Z still uses the jog prompt.

**Results:** `global.nxtCalTravelCmd`, `nxtCalTravelMeas`, `nxtCalTravelAxis`.

---

### G6520: Vise Corner Probe

Runs a single surface Z probe for vise top, then outside corner probe for X/Y position. Ends at jog **startZ** (`G53 G0 Z{startZ}`); with **`U`**, **M6520** sets X/Y/Z WCS then XY travel to work 0 while Z returns to **startZ**.

**Usage:** `G6520 P<index> L<depth> [X<x-surface>] [Y<y-surface>] [I<probeID>] [F<speed>] [R<retries>] [C<clearance>] [O<overtravel>]`

**Parameters:**
- `P`: Result table index (0-9) - **REQUIRED**
- `L`: Probe depth below starting position - **REQUIRED**
- `X`: Target coordinate for X-axis surface probe (defaults to current X - overtravel)
- `Y`: Target coordinate for Y-axis surface probe (defaults to current Y - overtravel)
- `I`: Probe ID (defaults to global.nxtTouchProbeID if not specified)
- `F`: Optional speed override (mm/min)
- `R`: Number of retries for averaging
- `C`: Clearance distance between probes (default: 10mm)
- `O`: Overtravel distance beyond expected surfaces (default: 2mm)

**Results:** Stores X, Y, and Z coordinates in the probe results table.

---

### G6550: Protected Move

Performs a protected move with probe-aware safety checks. If a touch probe is triggered unexpectedly during movement, the move is aborted immediately.

If the stylus is **already triggered** when `G6550` starts (non–Z-only raise), it first **`G1` toward the commanded target** by up to the probe dive-height (clear/retract). Callers such as **`G6512.1`** pass the post-touch retract point as that target. It must **never** step away from the target while triggered — that drove into the bore wall after a hit.

**Usage:** `G6550 [X<pos>] [Y<pos>] [Z<pos>] [A<pos>] [I<probeID>] [F<speed>]`

**Parameters:**
- `X|Y|Z|A`: Target coordinates (any combination allowed)
- `I`: Probe ID to monitor (default: touch probe)
- `F`: Optional speed override (mm/min)

---

### G6600: Workpiece Probing Gateway

Emitted by Fusion/FreeCAD post-processors during job preamble / WCS changes. Pauses CAM setup for operator WCS probing. Primary workflow: **DWC nxt → Probing Cycles**. On-machine menu offers vise corner (**G6520**) or handoff after DWC probing. The vise-corner path prompts a jog first so **G6520** `L` dives from the jogged machine Z (no pre-probe park).

**Usage:** `G6600 [W<0..8>]`

**Parameters:**
- `W`: 0-indexed work offset (`W0` = G54). Omitted = current workplace after `G55`/`G56` switch.

**Requirements:** Touch probe enabled; uses `nxt-probe-tool-ready.g` for probe tool selection.

---

## M-codes

### M3.9, M4.9, M5.9: Spindle Control

Safe spindle start/stop with acceleration waits.

**Usage:**
- `M3.9 S<rpm>` - Start spindle clockwise
- `M4.9 S<rpm>` - Start spindle counter-clockwise
- `M5.9` - Stop spindle

---

### M7, M7.1, M8, M9: Coolant Control

**Usage:**
- `M7` - Mist coolant on (air blast steady; mist pin steady or pulsed per Configuration)
- `M7.1` - Air blast on
- `M8` - Flood coolant on (steady or pulsed per Configuration)
- `M9` - All coolant off (stops pulsing). `M9 R1` restores state saved on pause.

**Coolant pulse (optional):** When enabled in DWC Configuration for mist and/or flood, `M7`/`M8` cycle the relevant output using `global.nxtCoolantPulseOnSec` (default **5** s) and `global.nxtCoolantPulseOffSec` (default **25** s). Mist pulsing keeps air blast on continuously. Mixed mode is supported (e.g. steady mist + pulsed flood). Requires the nxt daemon loop (`global.nxtDaemonEnabled`, `global.nxtDaemonInterval`).

**Related globals:** `nxtCoolantMistPulseEnabled`, `nxtCoolantFloodPulseEnabled`, `nxtCoolantPulseOnSec`, `nxtCoolantPulseOffSec` (persisted in `nxt-user-vars.g`); runtime flags `nxtCoolantMistRequested`, `nxtCoolantFloodRequested`, `nxtCoolantPulseActive`.

---

### M80.9, M81.9: ATX Power Control

Safe, operator-confirmed ATX power control.

**Usage:**
- `M80.9` - Power on (with confirmation)
- `M81.9` - Power off (with confirmation)

---

### M4000: Define Tool

Registers a tool in RRF (`M563`) and stores CAM metadata in `global.mosTT` (radius, optional probe deflection, flute count/length). Used by CAM preamble and DWC Tool Library.

**Usage:** `M4000 P<index> R<radius> S"description" [I<spindle>] [X] [Y] [F] [L]`

**Parameters:**
- `P`: Tool index (0 … `limits.tools−1`) — **required**
- `R`: Cutter radius (mm) — **required**
- `S`: Description string — **required**
- `I`: Spindle ID (default `global.nxtSpindleID`)
- `X`, `Y`: Touch-probe deflection (mm) for probe tools
- `F`: Flute count; `L`: Flute length (mm)

When `global.nxtAutoPersistTools` is true, rewrites `0:/sys/nxt-user-tools.g` via `nxt-user-tools-sync.g`.

---

### M4001: Remove Tool

Removes tool index `P` from RRF and clears `mosTT` row.

**Usage:** `M4001 P<index>`

---

### M4005: Post-Processor Version Check

Soft-compares CAM post `V"…"` to `global.nxtVersion` on **major.minor line only** (leading `v`, patch, and `-beta`/`-rc` suffixes ignored), then runs **`M4006`**.

**Usage:** `M4005 V"<version>"`

**Examples:**
- `M4005 V"v0.7.0"` on firmware `v0.7.0-beta.1` — OK (same `0.7` line)
- `M4005 V"v0.7.0-rc1"` on firmware `v0.7.1` — OK
- `M4005 V"v0.6.0"` on firmware `v0.7.0` — abort (cross-line)

---

### M4006: Require Touch-Probe Deflection

When `nxtFeatureTouchProbe` is true, aborts unless `nxtProbeDeflection` is a non-zero `{X,Y,Z}` vector (factory `{0,0,0}` / unset = not calibrated). Invoked from `M4005` so CAM jobs cannot start without Phase 1 deflection.

**Usage:** `M4006` (usually via `M4005`)

---

### M5000: Get Machine Position

Retrieves the current tool-compensated machine position for all axes and stores in `global.nxtAbsPos`.

**Usage:** `M5000`

**Results:** Updates `global.nxtAbsPos` vector with current positions.

---

### M5015: Calibration Probe Assist (jog / G6512 / return)

Phase 3 face capture helper: optional jog-confirm near a face → `G6512` to target → return to approach.

**Usage:** `M5015 X|Y|Z<target> I<probeId> [J0]`

**Parameters:**
- Exactly one of `X|Y|Z`: machine-coordinate probe target
- `I`: probe tool / sensor ID (required)
- `J0`: skip the jog `M291` when already at approach (e.g. after `M5018`)

---

### M5017: Probe XY External Spans (deflection assist)

Phase 1 probe-mode assist: dive by `D`, **3-point CCW perimeter** on a 1-2-3 block (3″∥X), raise Z only between faces, park at probed XY center at the original safe Z.

**Usage:** `M5017 D<diveMm> [O<overshootMm>]`

**Parameters:**
- `D`: Z dive depth from the operator’s safe starting Z (required, > 0)
- `O`: Outside clearance beyond the nominal face (default **5** mm)
- Edge inset (corner clearance) for outer face points is fixed at **10** mm

**Behavior:** Operator jogs to approx **XY center at safe Z**. Starts at −Y/−X outside corner, probes 3 points along each face (stay at dive Z along the face), raises only when changing faces. Spans from **means** of the three hits per face (~76.2 mm X / ~50.8 mm Y). Echoes tip radius, current deflection, shortfalls, and proposed Dx/Dy; warns if proposed D > 0.5 mm or tip R ≥ 2.

**Results:** `global.nxtCalDefSpanX`, `global.nxtCalDefSpanY`; `nxtCalDefSpan` = X for compat. Calibration UI applies XY deflection math (Z channel stays 0).

---

### M5018: Phase 3 Safe Outside + Probe-Find Face

Safe helper for Phase 3 face capture (and G9000 pre-position). Assumes the probe is at **XY center / safe Z** after `M5017`. Raises, moves **outside** past the nominal face, dives, **G6512**-finds the edge, then either returns to the saved center or stays outside (`R0`).

**Usage:** `M5018 X|Y{±1} S<sizeMm> [O<clearanceMm>] [D<diveMm>] [I<probeId>] [R0]`

**Parameters:**
- Exactly one of `X|Y` with dir **`1`** (plus face) or **`-1`** (minus face)
- `S`: full nominal face length along that axis (e.g. 50.8 / 76.2) — required
- `O`: outside clearance beyond the face (default **15** mm)
- `D`: optional Z dive from safe Z (same meaning as `M5017 D`)
- `I`: probe tool ID (default `nxtTouchProbeID`)
- `R0`: stay at outside approach after find (for chaining `G9000`); default returns to saved center

**Behavior:** Confirm still at post-`M5017` center → save pose → raise → XY to `center ± (S/2 + O)` → optional dive → `G6512` toward face (`half − 2` mm into nominal) → backoff to outside → unless `R0`, raise and return to saved center. Result in `nxtLastProbeResult`.

**Locked pose:** X faces = 3″ ends; Y faces = 2″ sides — no reorient required for that primary size.

---

### M6515: Check Machine Limits

Validates that target coordinates are within machine limits.

**Usage:** `M6515 [X<pos>] [Y<pos>] [Z<pos>] [A<pos>]`

**Parameters:**
- `X|Y|Z|A`: Coordinates to validate

**Behavior:** Aborts with error if any coordinate exceeds machine limits.

---

### M6520: Set WCS Offset from Probe Result

Sets a Work Coordinate System (WCS) origin using coordinates from the probe results table (feature machine coordinates, minus current tool offsets), selects that workplace, travels to work **0** on flagged **X/Y/A** only (never work **Z0**), then optionally applies **G68** XY rotation when **both** `X` and `Y` are updated and the result vector has θ in `nxtProbeResults[P][#move.axes]`.

**Z:** Results are the **raw trigger** from G6512 (no deflection, no tip radius). **`M6520 … Z1`** sets that height as work **Z0** via **G10 L2** only — no post-apply **`G0 Z0`**. Cycles (**G6510** / **G6520**) return to jog **startZ**.

**Usage:** `M6520 P<resultIndex> W<wcsNumber> [X1] [Y1] [Z1] [A1] [Q<mode>] [T<maxSkewDeg>]`

**Parameters:**
- `P`: Probe results table index (0-9) — **required**
- `W`: WCS number (1-9 for `G10 L2 P` / G54⋯) — **required**
- `X1|Y1|Z1|A1`: Axis **presence** flags — at least one required. RRF meta needs a number after the letter (`X1`, not bare `X`); the value is ignored. See [`docs/RRF_META_PITFALLS.md`](docs/RRF_META_PITFALLS.md) §1c.
- `Q`: Rotation policy: **0** (default) = `M291` prompt to apply or skip **G68**; **1** = apply **G68** without prompt; **2** = translation only (no **G68**)
- `T`: Optional cap on `|θ|` in degrees (default `global.nxtProbeMaxSkewDeg`); abort **M6520** if exceeded

**Post-apply travel** (after **G10 L2** + selecting **G54⋯**), only flagged **X/Y/A** move to work **0**:
- **X+Y** (bore/boss/corner, with or without Z flag): **`G0 X0 Y0`** — keep current Z; never **`G0 Z0`**
- **Z only** (top surface / `G6510 Z`): **no travel** — WCS Z set; caller returns to **startZ**
- **X or Y only** (side surface / `G6510 X|Y`): **`G0`** on that axis only — leave the others unchanged

**Rotation:** Uses RRF **G68 X0 Y0 R** after **G10 L2** and selecting the target workplace. **G68** rotation direction was corrected in **RRF 3.6.1** (anticlockwise **R**); nxt on branch **`v0.7.0`** targets **RRF 3.7.x** ([`docs/RRF_REFERENCE.md`](docs/RRF_REFERENCE.md)). See `docs/DETAILS.md` (nxt native probing section).

**Job scope:** When **G68** is applied, nxt stores **`nxtJobG68Deg`** / **`nxtJobG68Wcs`** for the current job. Rotation **persists across toolchanges** (`tpost` re-asserts via `nxt-job-g68-restore.g` after paths that may `G69`). It is **cleared on cancel** and on **job finish** via `stop.g` (not while paused). Not written to `nxt-user-vars.g`.

**Probe cycles:** With **`U`** on **G650x**/`G6510`, the macro stores results at row **`U−1`** and calls **`M6520 P{U−1} W{U} …`** directly at the end (not via **`M98`**, which cannot pass **`P`**) so the operator does not run **M6520** separately.

**Example:**
```gcode
; Auto chain (recommended from UI): bore + apply G54 + optional G68
G6500 U1 D25.4 L10 Q0

; Manual legacy: measure only into P3, then apply to G55
G6500 P3 D25.4 L10
M6520 P3 W2 X1 Y1 Q0
```

**How it works:**
- Reads the probe result from `P`, issues **G10 L2 P{W}** for flagged axes as `machine − toolOffset` (presence of the letter matters; **0** is a valid origin; unflagged axes untouched)
- Selects workplace via **`M98 P"nxt-select-wcs.g" W{W}`** (literal **G54…G59.3**; RRF forbids `G{53+W}`)
- If **X** and **Y** are flagged and `|θ|` is non-trivial and within **T**, applies **Q** (prompt / force / skip) then **G69**/**G68** as needed
- Travels to work **0** on flagged **X/Y/A** only (**XY** → keep Z; **Z flag** → WCS only, no Z travel; **side X|Y** → that axis only). **G6510**/**G6520** return Z to **startZ**.

---

### M6521: Clear Probe Result

Clears one or all entries in the probe results table.

**Usage:** `M6521 [P<resultIndex>]`

**Parameters:**
- `P`: Probe results table index (0-9) to clear. If omitted, clears all results.

**Examples:**
```gcode
M6521 P0    ; Clear result at index 0
M6521       ; Clear all results
```

---

### M6522: Average Probe Results

Averages two probe results and stores the result in the first index. Only averages axes that have non-zero values in BOTH results.

**Usage:** `M6522 P<index1> Q<index2>`

**Parameters:**
- `P`: First probe results table index - receives the averaged result - **REQUIRED**
- `Q`: Second probe results table index to average with P - **REQUIRED**

**Example:**
```gcode
; Probe same feature twice for accuracy
G6500 P0 D25.4 L10    ; First bore probe
G6500 P1 D25.4 L10    ; Second bore probe
M6522 P0 Q1           ; Average results into index 0
M6520 P0 W1 X1 Y1       ; Push averaged result to G54
```

---

### M6523: Probe Cycle Output Calibration (repeatability)

Runs multiple full **G6512** Z probe cycles at a fixed reference surface (touch probe or toolsetter), then reports **min**, **max**, **range**, and **mean** of the compensated Z results. Use to validate or tune probe repeatability limits (`nxtTouchProbe*` / `nxtToolSetter*` or `nxt-user-overrides.g`). See [docs/CALIBRATION.md](docs/CALIBRATION.md).

**Usage:** `M6523 [B<0|1>] [C<count>] [Z<targetZ>] [F<feed>] [L<limitMm>] [O<outerRetries>]`

**Parameters:**
- `B`: Reference probe — **0** = touch probe, **1** = toolsetter (default: touch if feature enabled, else toolsetter)
- `C`: Number of **G6512** cycles (default **10**, max **50**)
- `Z`: Machine Z target for **G6512** (default: reference surface Z from `nxtTouchProbeRefPos` or `nxtToolSetterPos`)
- `F`, `L`, `O`: Passed through to **G6512** (`L`/`O`: optional `nxtTouchProbe*` / `nxtToolSetter*` overrides, else `nxtProbeMaxSampleSpreadMm` / `nxtProbeSampleOuterRetries`)

Approach height before each cycle is **Z max** (`move.axes[2].max`).

**Requirements:**
- **B0:** Touch probe enabled (`nxtFeatureTouchProbe` or legacy `mosFeatTouchProbe`), `nxtTouchProbeRefPos` set, valid `nxtTouchProbeID` sensor; selects **`T{global.nxtProbeToolID}`** if another tool is active (runs normal tool-change macros); prompts until the probe input reads active
- **B1:** Toolsetter enabled (`nxtFeatureToolSetter` or legacy `mosFeatToolSetter`), `nxtToolSetterPos` set, current tool over setter (same as **G37**)

**Examples:**
```gcode
M6523 B0 C10            ; selects probe tool if needed, then 10 cycles at touch reference
M6523 B1 C10            ; 10 cycles at toolsetter
M6523 B0 C20 Z120.5 L0.01
```

Does not modify globals or `nxt-user-overrides.g` (report only).

---

### M6524: Set RGB Work Light

Sets the addressable RGB work light via **M150** when the RGB light feature is enabled.

**Usage:** `M6524 R<0-255> U<0-255> B<0-255>`

**Parameters:**
- `R`, `U`, `B`: Color components (each clamped to 0–255; default 0 if omitted).  
  Green is **`U`**, not `G` — RRF treats `Gnnn` on the same line as a G-code (e.g. `G102`).

**Requirements:** `nxtFeatureRgbLight`; strip created with `M950` (`nxtRGBPin` from board pack / daemon).

**Behavior:** Ensures `M950` if needed, then `M150 E{nxtRGBStrip} R… U… B… W0 P255 S{nxtRGBCount} F0`.

---

### M6525: Prepare for Plugin Update

Pauses or resumes the nxt daemon forever-loop so DWC/DSF can install or upgrade the plugin ZIP without failing on an open `0:/sys/daemon.g`.

**Usage:** `M6525 [S1]`

**Parameters:**
- `S1`: Apply pending `0:/sys/daemon.install` (via `nxt-daemon-install.g`) if present, then set `global.nxtDaemonEnabled = true`
- (default): Set `nxtDaemonEnabled = false`, wait `2 × nxtDaemonInterval`, leave paused

**When to use:** Before upgrading from a build that still shipped `sd/sys/daemon.g` in the plugin file list (DSF uninstall must delete that open file). Newer ZIPs ship `daemon.install` instead; after the one-time migration, routine updates usually do not need a pause. Reboot or `M98 P"nxt.g"` / `M6525 S1` applies a pending install.

---

## Global Variables

### Probe Results Table

- **`global.nxtProbeResults`**: Vector storing up to 10 probe results
  - Each entry is a vector: `[X, Y, Z, A, rotation]`
  - Coordinates in mm, rotation in degrees
  - `null` indicates empty slot

### Last Probe Result

- **`global.nxtLastProbeResult`**: Single value from most recent G6512 probe
  - Used internally by probing cycles
  - X/Y: tip radius + deflection; Z: raw trigger (no deflection, no tip radius)

### Absolute Position

- **`global.nxtAbsPos`**: Current tool-compensated machine position
  - Updated by M5000
  - Vector: `[X, Y, Z, A]`

---

## Workflow Examples

### Basic Probing Workflow

```gcode
; 1. Bore probe to find center
G6500 P0 D25.4 L10

; 2. Z probe on same feature
G6510 P0 Z-20

; 3. Push complete coordinates to G54
M6520 P0 W1 X1 Y1 Z1
```

### Multi-Probe Averaging

```gcode
; Probe vise corner twice for accuracy
G6520 P0 N0          ; First probe
G6520 P1 N0          ; Second probe
M6522 P0 Q1          ; Average results
M6520 P0 W1 X1 Y1 Z1    ; Push to G54
```

### Sequential Feature Probing

```gcode
; Probe multiple features into different result slots
G6500 P0 D25.4 L10   ; Bore 1
G6500 P1 D12.7 L10   ; Bore 2
G6508 P2 N0 L5       ; Outside corner

; Push each to different WCS
M6520 P0 W1 X1 Y1      ; Bore 1 -> G54
M6520 P1 W2 X1 Y1      ; Bore 2 -> G55
M6520 P2 W3 X1 Y1      ; Corner -> G56
```
