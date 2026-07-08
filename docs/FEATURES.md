# nxt Feature Set

This document distills the requirements for the nxt rewrite, categorizing features into Critical, Nice-to-Have, and To Be Cut. The focus is on simplicity, accuracy, and a streamlined user experience.

---

## 1. Guiding Principles

- [x] **Simplicity & Accuracy:** The primary goal is to reduce complexity wherever possible. All implementation choices must prioritize accuracy, especially in probing and calculation-heavy operations.
- [x] **Numerical Stability:** Algorithms used for calculations (e.g., probe compensation, geometric calculations) must be chosen to minimize floating-point error accumulation.
- [x] **User Input and Warnings:** For actions requiring user confirmation or input, macros use `M291` dialogs and/or the Action Confirmation widget in DWC.
---

## 2. Critical Features

These features form the core of the new nxt system and must be implemented for the system to be considered functional.

#### **Core System & Structure**
- [x] **Simplified Loading Mechanism:** Retain the `nxt.g` entrypoint and `nxt-boot.g` sanity-check structure, but simplify the internal logic.
- [x] **Global Variable System:** Keep the concept of using global variables for state management, loaded from `nxt-vars.g` and `nxt-user-vars.g`.
- [x] **Reorganized Macro Folders:** The `macro/` directory will be restructured by purpose (e.g., `macros/probing`, `macros/tooling`, `macros/spindle`) to improve clarity and maintainability.

#### **Probing Engine & Safety**
- [x] **Single-Axis Probing Core:** A new, fundamental probing macro that *only* moves along a single specified axis (X, Y, Z, A, etc.) per command. All complex, multi-axis probe moves will be removed. In particular, this applies to Bore and Boss probes that previously would probe at 120 degree angles.
- [x] **Probe Compensation:** The core probing macro will be responsible for applying compensation for:
    - [x] **Probe Tip Radius:** Applied for all horizontal (X, Y, etc.) probing moves.
    - [x] **Probe Deflection:** Applied for all probing moves, including Z. The Z-axis compensation will be handled to avoid applying the radius. We may need to track a separate probe deflection value for Z as opposed to X/Y because the probe behaviour may be different.
- [x] **Probe Deflection Measurement:** A dedicated mechanism (UI component) to automatically measure probe deflection by probing a known-sized object. This will be part of the new UI-based configuration and not implemented in a macro.
- [x] **Manual Deflection Input:** The UI will allow operators to manually enter their own pre-calculated deflection values.
- [x] **Protected Moves:** A critical safety feature. If the touch probe is triggered unexpectedly during any non-probing move (e.g., jogging, travel moves), the movement must halt immediately and the running macro must be aborted.

#### **Probe Results Management**
- [x] **Decoupled Probing:** Probing cycles will **no longer** directly set a Work Coordinate System (WCS) origin. Their sole purpose is to find a coordinate and record it.
- [x] **Probe Results Table:** A new global variable (e.g., a vector) will be implemented to store a history of the last ~10 probe results. Each entry will record the axis/axes probed and the final, compensated coordinate(s).
- [x] **UI for WCS Application & Result Manipulation:** A new UI panel will display the Probe Results Table. From this panel, the user can:
    - [x] **Push to WCS:** Select a result row and apply its coordinates to a chosen WCS.
    - [x] **Merge Results:** Select a result row, run a new probe cycle for a different axis, and have the new result populate the selected row.
    - [x] **Overwrite Results:** If a new probe cycle's axis already exists in a selected row, the new value will overwrite the old one.
    - [x] **Average Results:** Select one row, then click an "average" button on another row to merge them by averaging their respective axis coordinates.

#### **Probing Cycles**
- [x] These will be re-implemented to log their results to the new Probe Results Table.
    - [x] Bore (`G6500`) - Probe both sides of the bore in X and Y and find the centre point (4 probe points total)
    - [x] Boss (`G6501`) - Probe both sides of the boss in X and Y and find the centre point (4 probe points total)
    - [x] Rectangle Pocket (`G6502`) - Probe all 4 edges of the pocket in X and Y, and find the centre point (4 probe points total)
    - [x] Rectangle Block (`G6503`) - Probe all 4 edges of the block in X and Y, and find the centre point (4 probe points total)
    - [x] Web (X/Y) (`G6504`) - Probe a block (web) in either X OR Y, and find the centre point on that axis (2 probe points total)
    - [x] Pocket (X/Y) (`G6505`) - Probe a pocket in either X OR Y, and find the centre point on that axis (2 probe points total)
    - [x] Rotation (`G6506`) - Probe 2 points along a single surface in X or Y to find the rotation of that surface against the relevant axis (2 probe points total)
    - [x] Outside Corner (`G6508`) - Probe each surface forming an assumed-90-degree outside corner, finding the intersection point of the two surfaces (2 probe points total)
    - [x] **New:** Inside Corner (`G6509`) - Probe each surface forming an assumed-90-degree inside corner, finding the intersection point of the two surfaces (2 probe points total)
    - [x] Single Surface (`G6510`) - Probe one surface in X, Y or Y, finding the location of the surface on the selected axis (1 probe point total)
    - [x] Vise Corner (`G6520`) - Run a single surface Z probe to find the top of a vise corner, then run an outside corner probe to find the corner point in X and Y (3 probe points total)

#### **Tool Change Logic**
- [x] **Probe-on-Removal:** Standard cutting tools will have their length measured by the toolsetter during the `tfree.g` (tool removal) phase.
- [x] **Relative Offset Calculation:** Tool offsets will be calculated relative to the previously used tool during the tool change process, eliminating reliance on a persistent, absolute datum between machine runs.
- [x] **Touch Probe Handling:** The touch probe is the exception. It will be measured against a reference surface upon installation (`tpost.g`) to establish its length relative to the toolsetter, ensuring accurate offsets for all subsequent tools.

#### **UI-Driven Workflow**
- [x] **Persistent UI Screen:** A new primary screen/view in DWC dedicated to nxt, containing always-visible widgets for core status and actions.
    - [x] **Status Widget:** A persistent widget displaying: selected tool name, tool offset, machine state, selected WCS, and spindle state (direction, RPM).
    - [x] **Action Confirmation Widget:** A persistent widget that replaces blocking `M291` dialogs. It will pause the job queue and display a confirmation request (e.g., "Start Spindle?") that the operator must interact with to resume the job.
- [x] **UI-Based Configuration:** A new settings panel within the UI plugin will completely replace the `G8000` configuration wizard, allowing for non-serial, direct editing of all settings. Includes directory-driven platform/board selection and **Apply platform sys files** for homing macros ([NXT_BOARD_HOMING.md](NXT_BOARD_HOMING.md)).
- [x] **UI-Driven Probing:** All probing cycles will be initiated and configured through the DWC UI.

#### **Machine Control**
- [x] **Spindle Control:** Core macros for safe spindle start/stop with acceleration waits (`M3.9`, `M4.9`, `M5.9`).
- [x] **Coolant Control:** Core macros for coolant control (`M7`, `M8`, `M9`, and `M7.1`).
- [x] **Coolant pulse:** Optional per-type pulsing for mist (`M7`) and flood (`M8`); defaults 5 s ON / 25 s OFF; configured in DWC Configuration.
- [x] **Parking (`G27`):** A critical macro for moving the machine to a safe, known position.
- [x] **Safety Net (ATX Power Control):** The `M80.9`/`M81.9` system for safe, operator-confirmed ATX power control.

---

## 2. Nice-to-Have Features

These features add value but are not part of the initial core rewrite. They can be implemented in a later phase after the critical systems are stable.

- [x] **Drilling Canned Cycles:** `G80`, `G81`, `G73`, `G83`, plus `G82`, `G85`, `G89`, and `G98`/`G99` retract mode (see `docs/CODE.md` §8.1). LinuxCNC-oriented; absolute XY/Z only in v1.
- [ ] **Variable Spindle Speed Control (VSSC):** Planned for a later phase; not yet implemented in nxt (legacy MillenniumOS VSSC is not ported). See `docs/ROADMAP.md`.
- [ ] **Spindle Feedback:** Use sensor input to detect when the spindle has reached target speed or stopped.
- [x] **Stock Preparation UI (Issue #34):** A dedicated UI panel for generating facing toolpaths to prepare raw stock. Features include:
  - [x] Multiple pattern types: rectilinear, zigzag, and spiral
  - [x] Support for rectangular and circular stock geometries
  - [x] Configurable parameters: tool radius, stock dimensions, pattern angle, stepover/stepdown, feed rates, spindle speed
  - [x] Real-time 2D SVG plan-view preview (stock outline, rapids vs cuts); 3D preview off for plugin stability
  - [x] G-code generation with safety features (M3.9/M5.9 wrappers, parking)
  - [x] Save-as-file or run-immediately functionality
  - [ ] Future enhancement: Material-based feed/speed calculator with tool flutes and coating consideration

---

## 3. Features to Be Cut

These features and concepts from the old implementation will be explicitly removed to align with the goal of simplicity and to reduce complexity and potential sources of error.

- [x] **Dialog-Driven Probing System:** Removed in favor of the DWC probing UI (`ProbingCyclesPanel`, `ProbeResultsPanel`).
- [x] **Manual Probing (Jogging Dialogs):** Removed; operators use standard DWC jogging plus probe results / WCS push workflow.
- [x] **Multi-Axis Probing Moves:** Removed; `G6512` is strictly single-axis per command.
- [x] **G8000 Configuration Wizard:** Replaced by the Configuration panel in the nxt DWC plugin.
- [x] **Backwards Compatibility (legacy MOS runtime):** nxt does not run legacy MOS macros; optional one-shot import via `nxt-mos-import.g` maps settings into `nxt-user-vars.g`. On branch **`v0.7.0`**, RRF floor is **`3.7.*`** (`auto-major` in built `plugin.json`); DWC requires **exact** version (`auto` at build time, pin `3.7.0-beta.1`). See [VERSIONING.md](VERSIONING.md).