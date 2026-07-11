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
  - [M4000](#m4000-define-tool) … [M6524](#m6524-set-rgb-work-light)
- [Global Variables](#global-variables)
- [Workflow Examples](#workflow-examples)

---

## G-codes

### G27: Parking

Moves the machine to a safe, known parking position.

RRF homing uses `0:/sys/homeall.g`, `homex.g`, `homey.g`, and `homez.g`. nxt vendors homing sources under `nxt-config/machine/<profile>/` and deploys them from the Configuration panel (not loaded at boot). See [docs/NXT_BOARD_HOMING.md](docs/NXT_BOARD_HOMING.md) for axis directions and verification.

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

Uses **three** inward touches (+X, −X, +Y) on the bore wall; the circle center is the **circumcenter** of the three contacts (minimum geometry for a circle in 2D). Skew is still derived from the ±X chord vs machine **X**.

**Usage:** `G6500 P|U D<diameter> L<depth> [F<speed>] [R<retries>] [O<overtravel>] [T] [Q]`

**Parameters:**
- `P` or `U`: Result row **`P`** (0–9) **or** target workplace **`U`** (1–9) — **REQUIRED** (one of)
- `D`: Bore diameter for move planning (mm) - **REQUIRED**
- `L`: Depth to move down into bore before probing (mm) - **REQUIRED**
- `F`: Optional speed override (mm/min)
- `R`: Inner sample count per **`G6512`** touch (default: `global.nxtProbeInnerSampleCount`)
- `O`: Overtravel distance beyond expected surface (default: 2mm)
- `T`: Max |skew| in degrees (default: `global.nxtProbeMaxSkewDeg`)
- `Q`: **`M6520`** rotation policy when **`U`** is used

**Results:** Stores X and Y center coordinates in the probe results table.

---

### G6501: Boss Probe

Probes a circular boss from the outside with **three** OD touches (+X, −X, +Y at the X midpoint), then the same **circumcenter** fit as **`G6500`**.

**Usage:** `G6501 P|U D<diameter> L<depth> [F<speed>] [R<retries>] [C<clearance>] [O<overtravel>] [T] [Q]`

**Parameters:**
- `P` or `U`: Result row **`P`** (0–9) **or** target workplace **`U`** (1–9) — **REQUIRED** (one of)
- `D`: Boss diameter for move planning (mm) - **REQUIRED**
- `L`: Depth to move down before probing (mm) - **REQUIRED**
- `F`: Optional speed override (mm/min)
- `R`: Inner sample count per **`G6512`** touch (default: `global.nxtProbeInnerSampleCount`)
- `C`: Clearance distance from boss edge for starting position (default: 5mm)
- `O`: Overtravel distance beyond expected surface (default: 2mm)
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

Probes all 4 edges of a rectangular block from outside to find the center.

**Usage:** `G6503 P<index> W<width> H<height> L<depth> [F<speed>] [R<retries>] [C<clearance>] [O<overtravel>]`

**Parameters:**
- `P`: Result table index (0-9) - **REQUIRED**
- `W`: Block width in X direction (mm) - **REQUIRED**
- `H`: Block height in Y direction (mm) - **REQUIRED**
- `L`: Depth to move down before probing (mm) - **REQUIRED**
- `F`: Optional speed override (mm/min)
- `R`: Number of retries for averaging per probe point
- `C`: Clearance distance (default: 5mm)
- `O`: Overtravel distance (default: 2mm)

**Results:** Stores X and Y center coordinates in the probe results table.

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

Probes one surface in X, Y, or Z to find the surface location.

**Usage:** `G6510 P<index> [X<target>|Y<target>|Z<target>] [F<speed>] [R<retries>]`

**Parameters:**
- `P`: Result table index (0-9) - **REQUIRED**
- `X|Y|Z`: Exactly one axis target coordinate - **REQUIRED**
- `F`: Optional speed override (mm/min)
- `R`: Number of retries for averaging

**Results:** Stores coordinate on specified axis in the probe results table.

---

### G6511: Reference Surface Probe

Emitted by Fusion/FreeCAD post-processors during job preamble / WCS changes. Probes the touch-probe reference surface when **both** touch probe and toolsetter are enabled. No-op if already probed this session unless `R1`.

**Usage:** `G6511 [R1] [S0]`

**Parameters:**
- `R1`: Force re-probe (clears session skip)
- `S0`: Non-standalone — do not switch to probe tool (nested call from `tpost.g`)

**Requirements:** `nxtTouchProbeRefPos`, `nxtDeltaMachine` configured in DWC.

**Results:** Sets `global.nxtRefSurfaceProbed`; Z touch in `global.nxtLastProbeResult`.

---

### G6512: Single-Axis Probing (Core)

Low-level single-axis probe move with compensation and averaging. Used by all probing cycles.

**Repeatability:** Defaults are **`macros/system/nxt-vars.g`** (`nxtProbeInnerSampleCount`, **`nxtProbeMaxSampleSpreadMm`** default **0.0075** mm, **`nxtProbeSampleOuterRetries`**). Override via **`0:/sys/nxt-user-overrides.g`** (loaded **last** in **`nxt.g`**; see **`nxt-user-overrides.g.example`**). When **`nxtProbeMaxSampleSpreadMm` > 0**, **`G6512`** runs **3** touches ( **`R`** is ignored), **`echo`s** each compensated value, and requires **both** consecutive pairs (1–2 and 2–3) to be within the limit. On failure it **`echo`s** the pair delta and over-limit amount, then repeats the whole 3-touch block up to **`1 + nxtProbeSampleOuterRetries`** cycles. On success it averages the three values into **`nxtLastProbeResult`**. Set **`nxtProbeMaxSampleSpreadMm`** to **0** to disable (honors **`R`** / **`nxtProbeInnerSampleCount`**, no pair checks).

**Usage:** `G6512 [X<pos>|Y<pos>|Z<pos>|A<pos>] I<probeID> [F<speed>] [R<retries>] [H<hit>]`

**Parameters:**
- `X|Y|Z|A`: Exactly ONE axis parameter must be provided - **REQUIRED**
- `I`: Probe ID (e.g., touch probe or tool setter) - **REQUIRED**
- `F`: Optional speed override (mm/min)
- `R`: Inner sample count for averaging (default: `global.nxtProbeInnerSampleCount`)
- `H`: Optional hit index 0..3 for `(X,Y)` into `global.nxtProbeHitXY`

**Results:** Stores compensated result in `global.nxtLastProbeResult`.

---

### G6520: Vise Corner Probe

Runs a single surface Z probe for vise top, then outside corner probe for X/Y position.

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

**Usage:** `G6550 [X<pos>] [Y<pos>] [Z<pos>] [A<pos>] [I<probeID>] [F<speed>]`

**Parameters:**
- `X|Y|Z|A`: Target coordinates (any combination allowed)
- `I`: Probe ID to monitor (default: touch probe)
- `F`: Optional speed override (mm/min)

---

### G6600: Workpiece Probing Gateway

Emitted by Fusion/FreeCAD post-processors during job preamble / WCS changes. Pauses CAM setup for operator WCS probing. Primary workflow: **DWC nxt → Probing Cycles**. On-machine menu offers vise corner (**G6520**) or handoff after DWC probing.

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

Compares CAM post `V"…"` string to `global.nxtVersion` (exact match).

**Usage:** `M4005 V"<version>"`

**Example:** `M4005 V"v0.6.0"` in job preamble.

---

### M5000: Get Machine Position

Retrieves the current tool-compensated machine position for all axes and stores in `global.nxtAbsPos`.

**Usage:** `M5000`

**Results:** Updates `global.nxtAbsPos` vector with current positions.

---

### M6515: Check Machine Limits

Validates that target coordinates are within machine limits.

**Usage:** `M6515 [X<pos>] [Y<pos>] [Z<pos>] [A<pos>]`

**Parameters:**
- `X|Y|Z|A`: Coordinates to validate

**Behavior:** Aborts with error if any coordinate exceeds machine limits.

---

### M6520: Set WCS Offset from Probe Result

Sets a Work Coordinate System (WCS) origin using coordinates from the probe results table (machine coordinates), then optionally applies **G68** XY coordinate rotation when **both** `X` and `Y` are updated and the result vector has a rotation value in `nxtProbeResults[P][#move.axes]`.

**Usage:** `M6520 P<resultIndex> W<wcsNumber> [X] [Y] [Z] [A] [Q<mode>] [T<maxSkewDeg>]`

**Parameters:**
- `P`: Probe results table index (0-9) — **required**
- `W`: WCS number (1-9 for `G10 L2 P` / G54⋯) — **required**
- `X|Y|Z|A`: Axis flags — at least one required
- `Q`: Rotation policy: **0** (default) = `M291` prompt to apply or skip **G68**; **1** = apply **G68** without prompt; **2** = translation only (no **G68**)
- `T`: Optional cap on `|θ|` in degrees (default `global.nxtProbeMaxSkewDeg`); abort **M6520** if exceeded

**Rotation:** Uses RRF **G68 X0 Y0 R** after **G10 L2** and selecting the target workplace. **G68** rotation direction was corrected in **RRF 3.6.1**; nxt on branch **`v0.7.0`** targets **RRF 3.7.x** ([`docs/RRF_REFERENCE.md`](docs/RRF_REFERENCE.md)). See `docs/DETAILS.md` (nxt native probing section).

**Probe cycles:** With **`U`** on **G650x**/`G6510`, the macro stores results at row **`U−1`** and calls **`M6520`** via **`M98`** at the end so the operator does not run **M6520** separately.

**Example:**
```gcode
; Auto chain (recommended from UI): bore + apply G54 + optional G68
G6500 U1 D25.4 L10 Q0

; Manual legacy: measure only into P3, then apply to G55
G6500 P3 D25.4 L10
M6520 P3 W2 X Y Q0
```

**How it works:**
- Reads the probe result from `P`, issues **G10 L2 P{W}** for flagged non-zero axes
- If **X** and **Y** are flagged and `|θ|` is non-trivial and within **T**, applies **Q** (prompt / force / skip) then **G69**/**G68** as needed

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
M6520 P0 W1 X Y       ; Push averaged result to G54
```

---

### M6523: Probe Cycle Output Calibration (repeatability)

Runs multiple full **G6512** Z probe cycles at a fixed reference surface (touch probe or toolsetter), then reports **min**, **max**, **range**, and **mean** of the compensated Z results. Use to validate or tune probe repeatability limits (`nxtTouchProbe*` / `nxtToolSetter*` or `nxt-user-overrides.g`). See [docs/CALIBRATION.md](docs/CALIBRATION.md).

**Usage:** `M6523 [B<0|1>] [C<count>] [Z<targetZ>] [F<feed>] [L<limitMm>] [O<outerRetries>]`

**Parameters:**
- `B`: Reference probe — **0** = touch probe, **1** = toolsetter (default: touch if feature enabled, else toolsetter)
- `C`: Number of **G6512** cycles (default **10**, max **50**)
- `Z`: Machine Z target for **G6512** (default: reference surface Z from `nxtTouchProbeRefPos` or `nxtToolSetterPos`)
- `F`, `L`, `O`: Passed through to **G6512** (`L`/`O` default from probe-specific globals)

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

## Global Variables

### Probe Results Table

- **`global.nxtProbeResults`**: Vector storing up to 10 probe results
  - Each entry is a vector: `[X, Y, Z, A, rotation]`
  - Coordinates in mm, rotation in degrees
  - `null` indicates empty slot

### Last Probe Result

- **`global.nxtLastProbeResult`**: Single value from most recent G6512 probe
  - Used internally by probing cycles
  - Compensated for probe tip radius and deflection

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
M6520 P0 W1 X Y Z
```

### Multi-Probe Averaging

```gcode
; Probe vise corner twice for accuracy
G6520 P0 N0          ; First probe
G6520 P1 N0          ; Second probe
M6522 P0 Q1          ; Average results
M6520 P0 W1 X Y Z    ; Push to G54
```

### Sequential Feature Probing

```gcode
; Probe multiple features into different result slots
G6500 P0 D25.4 L10   ; Bore 1
G6500 P1 D12.7 L10   ; Bore 2
G6508 P2 N0 L5       ; Outside corner

; Push each to different WCS
M6520 P0 W1 X Y      ; Bore 1 -> G54
M6520 P1 W2 X Y      ; Bore 2 -> G55
M6520 P2 W3 X Y      ; Corner -> G56
```
