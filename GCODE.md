# NeXT Custom G-Code and M-Code Reference

This document provides reference documentation for custom G-codes and M-codes implemented in NeXT.

## Table of Contents

- [Probing Cycles](#probing-cycles)
- [Utility Macros](#utility-macros)
- [Movement Control](#movement-control)
- [Machine Control](#machine-control)

---

## Probing Cycles

### G6500: Bore Probe

Probes a circular bore by probing in 4 directions (±X, ±Y) to find the center.

**Usage:** `G6500 P<index> D<diameter> L<depth> [F<speed>] [R<retries>] [O<overtravel>]`

**Parameters:**
- `P`: Result table index (0-9) where results will be stored - **REQUIRED**
- `D`: Bore diameter for move planning (mm) - **REQUIRED**
- `L`: Depth to move down into bore before probing (mm) - **REQUIRED**
- `F`: Optional speed override (mm/min)
- `R`: Number of retries for averaging per probe point
- `O`: Overtravel distance beyond expected surface (default: 2mm)

**Results:** Stores X and Y center coordinates in the probe results table.

---

### G6501: Boss Probe

Probes a circular boss from outside in 4 directions (±X, ±Y) to find the center.

**Usage:** `G6501 P<index> D<diameter> L<depth> [F<speed>] [R<retries>] [C<clearance>] [O<overtravel>]`

**Parameters:**
- `P`: Result table index (0-9) where results will be stored - **REQUIRED**
- `D`: Boss diameter for move planning (mm) - **REQUIRED**
- `L`: Depth to move down before probing (mm) - **REQUIRED**
- `F`: Optional speed override (mm/min)
- `R`: Number of retries for averaging per probe point
- `C`: Clearance distance from boss edge for starting position (default: 5mm)
- `O`: Overtravel distance beyond expected surface (default: 2mm)

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

### G6512: Single-Axis Probing (Core)

Low-level single-axis probe move with compensation and averaging. This is the core probing engine used by all probing cycles.

**Usage:** `G6512 [X<pos>|Y<pos>|Z<pos>|A<pos>] I<probeID> [F<speed>] [R<retries>]`

**Parameters:**
- `X|Y|Z|A`: Exactly ONE axis parameter must be provided - **REQUIRED**
- `I`: Probe ID (e.g., touch probe or tool setter) - **REQUIRED**
- `F`: Optional speed override (mm/min)
- `R`: Number of retries for averaging (default: probe.maxProbeCount + 1)

**Results:** Stores compensated result in `global.nxtLastProbeResult`.

---

### G6520: Vise Corner Probe

Runs a single surface Z probe for vise top, then outside corner probe for X/Y position.

**Usage:** `G6520 P<index> N<axis> [F<speed>] [R<retries>]`

**Parameters:**
- `P`: Result table index (0-9) - **REQUIRED**
- `N`: Primary axis for corner (0=X, 1=Y) - **REQUIRED**
- `F`: Optional speed override (mm/min)
- `R`: Number of retries for averaging

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

## Utility Macros

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

Sets a Work Coordinate System (WCS) origin using coordinates from the probe results table. The probe result coordinates (in machine coordinates) are used directly as the WCS origin.

**Usage:** `M6520 P<resultIndex> W<wcsNumber> [X] [Y] [Z] [A]`

**Parameters:**
- `P`: Probe results table index (0-9) to read from - **REQUIRED**
- `W`: WCS number (1-6 for G54-G59) - **REQUIRED**
- `X|Y|Z|A`: Axis flags - at least one required

**How it works:**
- Reads the probe result from the specified index
- For each flagged axis, sets the WCS origin to the probe result coordinate
- Uses `G10 L2` internally to set the WCS origin

**Example:**
```gcode
; Probe bore center and set as G54 origin
G6500 P0 D25.4 L10    ; Probe bore, result stored at index 0
M6520 P0 W1 X Y       ; Set G54 origin to bore center

; Probe Z surface and add to same WCS
G6510 P0 Z-20         ; Probe Z, adds to result 0
M6520 P0 W1 X Y Z     ; Update G54 with X, Y, and Z
```

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

## Movement Control

### G27: Parking

Moves the machine to a safe, known parking position.

**Usage:** `G27 [X<level>] [Y<level>] [Z<level>]`

**Parameters:**
- `X|Y|Z`: Parking level (0-2), where higher levels are safer/further from workpiece

---

## Machine Control

### M3.9, M4.9, M5.9: Spindle Control

Safe spindle start/stop with acceleration waits.

**Usage:**
- `M3.9 S<rpm>` - Start spindle clockwise
- `M4.9 S<rpm>` - Start spindle counter-clockwise
- `M5.9` - Stop spindle

---

### M7, M7.1, M8, M9: Coolant Control

**Usage:**
- `M7` - Mist coolant on
- `M7.1` - Air blast on
- `M8` - Flood coolant on
- `M9` - All coolant off

---

### M80.9, M81.9: ATX Power Control

Safe, operator-confirmed ATX power control.

**Usage:**
- `M80.9` - Power on (with confirmation)
- `M81.9` - Power off (with confirmation)

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
