# nxt Rewrite Roadmap

This document outlines the development roadmap for the complete rewrite of MillenniumOS as **nxt**. The primary goal is to refactor the system for simplicity, accuracy, and maintainability, starting from a clean slate.

**Development repository:** [MillenniumMachines/MOS-nxt](https://github.com/MillenniumMachines/MOS-nxt) — active line on branch `v0.6.0`, pre-releases tagged `v0.6.0-beta.N`.

---

## Project Naming and Conventions

- **Product name:** **nxt** (lowercase). Unofficial repo name: **MOS-nxt**.
- **Variable Naming:** All global variables created for the nxt system must be prefixed with `nxt` to avoid conflicts with other plugins or user variables (e.g., `nxtDeltaMachine`).
- **File Naming:** Core system files should also adopt this prefix where appropriate (e.g., the main entrypoint will be `nxt.g`).

---

## Phase 0: Foundation & Cleanup ✅

The goal of this phase is to establish a clean and organized repository structure for the new implementation. **COMPLETED**

1.  **Branch Creation:** ✅
    *   The `next` branch has been created to house the new implementation.

2.  **Repository Cleanup:** ✅
    *   All existing macro, system, and UI code will be removed from the `next` branch. The following directories will be cleared:
        *   `macro/`
        *   `sys/`
        *   `ui/`
    *   Only documentation (`docs/`, `README.md`, etc.), build scripts, and GitHub workflow files will be retained.

3.  **New Directory Structure:** ✅
    *   A new, more intuitive directory structure for macros will be created. Instead of `machine` and `movement`, macros will be grouped by high-level purpose.
        *   `macros/system/` (for core boot, daemon, and variable files)
        *   `macros/probing/` (for all probing cycles)
        *   `macros/tooling/` (for tool changing and length measurement)
        *   `macros/spindle/` (for spindle control)
        *   `macros/coolant/` (for coolant control)
        *   `macros/utilities/` (for parking, reloading, power control etc.)

4.  **New Repository:** ✅
    *   The new directory structure lives in the MOS-nxt repository ([MillenniumMachines/MOS-nxt](https://github.com/MillenniumMachines/MOS-nxt)).
    *   This provides full control over development and refactoring without affecting legacy MillenniumOS macro sources in the old repo.
    *   Stable releases will merge to `main`; the `v0.6.0` branch carries the current beta line.

---

## Phase 1: Core System & Essential Backend ✅

This phase focuses on implementing the most critical, non-UI backend functionality. **COMPLETED**

1.  **Core Loading Mechanism:** ✅
    *   Re-implement the core loading scripts (`nxt.g`, `nxt-boot.g`) and the global variable system (`nxt-vars.g`).

2.  **Essential Control Macros:** ✅
    *   Implement core macros for Spindle Control (`M3.9`, `M4.9`, `M5.9`), Coolant Control (`M7`, `M7.1`, `M8`, `M9`), ATX Power Control (`M80.9`, `M81.9`), and Parking (`G27`).

3.  **Basic Utility Macros:** ✅
    *   Machine information queries (`M5000`) and limit checking (`M6515`).
    *   Tool measurement (`G37`) and basic probing functionality (`G6512`).

4.  **Simplified Probing Engine:** ✅
    *   Develop a new, single-axis probing macro, guided by the principle of numerical stability.
    *   Implement robust compensation logic within this core macro for both probe tip radius and probe deflection.
    *   Implement the **Protected Moves** logic to halt on unexpected probe triggers.
    *   Implement the backend global variable (vector) for the **Probe Results Table**. ✅
    *   Design all probing cycle macros (`G6500`, `G6501`, etc.) to log their compensated results to this table instead of setting a WCS origin directly.

5.  **Redesigned Tool Change Logic:** ✅
    *   Implement the "probe-on-removal" logic in `tfree.g` for standard tools.
    *   Implement the relative offset calculation in `tpre.g`.
    *   Implement the special case for the touch probe in `tpost.g` (probing a reference surface).

---

## Phase 1.5: Probing Result Management Enhancement ✅

This phase bridges Phase 1 and Phase 2 by implementing UI-controlled result management for probing macros. **COMPLETED**

1.  **Result Index Parameter Implementation:** ✅
    *   Add mandatory `P<index>` parameter to all probing macros (`G6500`, `G6501`, `G6502`, etc.).
    *   UI specifies exact result table index (0-based) for storing probe results.
    *   Remove auto-slot-finding logic from probing macros.
    *   Enable precise result management workflows:
        *   Select result row → run X/Y probe (populates coordinates in specified row)
        *   Keep same row selected → run Z probe (adds Z coordinate to same row)
        *   Keep same row selected → run rotation probe (adds rotation angle to same row)

2.  **Enhanced Result Storage:** ✅
    *   Probing macros directly overwrite specified result index.
    *   Each macro populates only the axes/rotation it measures.
    *   UI controls result row selection and workflow management.
    *   Clear separation: macros execute probing, UI manages result workflow.

3.  **Updated Documentation:** ✅
    *   Document result index parameter requirement in `CODE.md`.
    *   Update all probing macro usage documentation.
    *   Establish UI integration patterns for result management.

---

## Phase 2: Settings UI & Configuration ✅

**COMPLETED** for configuration and probing workflow UI. Optional control panels remain in the backlog (see Outstanding Work).

1.  **UI Scaffolding & Core Layout:** ✅
    *   Set up a new, clean Vue 2.7 plugin structure within the `ui/` directory.
    *   Design and implement the new **Persistent UI Screen**, including the core **Status Widget** (Tool, WCS, Spindle, etc.) and the **Action Confirmation Widget**.

2.  **UI-Based Configuration (CRITICAL):** ✅
    *   Implement a new "Settings" or "Configuration" view within the UI plugin to replace the `G8000` wizard.
    *   This view will allow direct editing of all settings and include the UI for the probe deflection measurement process.
    *   **Priority:** This configuration UI is essential for defining the user variables that the backend macros require (`nxt-user-vars.g`).

3.  **Probe Deflection Measurement UI:** ✅
    *   Create a dedicated UI component to guide the user through measuring probe deflection automatically.
    *   Include manual deflection input capability for operators who have pre-calculated values.

4.  **Essential Status & Control Panels:** ✅ (core) / backlog (optional)
    *   **Done:** `MachineStatusPanel.vue` (system and axis status); WCS selection and push-to-WCS via `ProbeResultsPanel.vue` and `ProbingCyclesPanel.vue`.
    *   **Backlog:** Dedicated spindle and coolant **control** panels (macros `M3.9` / `M7`–`M9` exist; no separate UI panels yet). Status widget shows spindle state only.

---

## Phase 3: Advanced Probing & Results Management ✅

This phase implements the advanced probing functionality and result management system. **COMPLETED**

1.  **Complete Probing Engine:** ✅
    *   Finish the single-axis probing macro implementation.
    *   Implement robust compensation logic and protected moves.

2.  **Probe Results UI & Workflow:** ✅
    *   Implement the UI panel to display the **Probe Results Table**.
    *   Implement the core user interactions for the results table:
        *   Pushing results to a WCS.
        *   Merging new probe results into existing rows.
        *   Averaging results between rows.

3.  **Probing Cycle UI:** ✅
    *   Create a new, intuitive UI for initiating all required probing cycles. This UI will trigger the backend macros that populate the Probe Results Table.

4.  **Complete Probing Cycles:** ✅
    *   Re-implement all probing cycles (`G6500`, `G6501`, etc.) to log results to the Probe Results Table.

---

## Phase 4: Tool Change & Advanced Features

This phase focuses on completing the tool change system and advanced features. **PARTIAL**

1.  **Complete Tool Change Logic:** ✅ (baseline)
    *   Implemented in `macros/tooling/tfree.g`, `tpre.g`, `tpost.g` — manual install/remove via `M291`, probe-on-removal / toolsetter (`G37`), relative offsets and touch-probe path in `tpost.g`. Optional ATC magazine pack remains separate; see `docs/TOOLCHANGING.md`.

2.  **Drilling Canned Cycles:** ✅ (see `docs/CODE.md` §8.1)
    *   `G80`, `G81`, `G73`, `G83`, `G82`, `G85`, `G89`, `G98`, `G99` in `macros/canned/` (LinuxCNC-oriented, absolute coordinates).

3.  **VSSC (Variable Spindle Speed Control):** ⬜ Not started
    *   Re-implement VSSC as a self-contained feature that can be enabled via the new UI configuration.
    *   Legacy MillenniumOS VSSC is **not** ported; `README.md` still mentions VSSC as a planned feature.

4.  **Machine Calibration System:** ⬜ Design only
    *   Implement UI-based calibration wizard in Settings panel for guided step-by-step workflow.
    *   Create backend M-code macros for querying and updating calibration parameters (M9001-M9004).
    *   Implement automated steps-per-mm calibration using dual-dimension measurement method.
    *   Implement automated backlash measurement and compensation workflow.
    *   Implement automated probe deflection measurement procedure.
    *   Add calibration verification tests and accuracy reporting.
    *   Store calibration data and history in nxt-user-vars.g.
    *   Design documentation: `docs/CALIBRATION.md` (macros not yet implemented).

5.  **Stock Preparation UI (Issue #34):** ✅
    *   Panel: `ui/src/components/panels/StockPreparationPanel.vue` (facing toolpaths, worker-backed generation).
    *   Algorithms: `ui/src/utils/toolpath.ts` — rectilinear, zigzag, spiral; rectangular and circular stock.
    *   Preview: 2D **SVG** plan view (rapids vs cuts) via `ui/src/utils/stockPreparationSvgPreview.ts`; 3D viewer stays off for plugin stability.
    *   G-code: `ui/src/utils/gcode.ts` (M3.9/M5.9-style headers, metadata, validation).
    *   Parameters: tool radius, stock size/origin, pattern angle, stepover/stepdown, depth, feeds, spindle speed, finishing options.
    *   Save to SD (`/rr_upload`) and run via `M98 P"..."`; form validation and `validateGCodeParameters`.
    *   Design and parameters: `docs/STOCK_PREPARATION.md`.

---

## v0.6.0 beta release track (in progress)

Pre-releases on `v0.6.0` (`v0.6.0-beta.1` …). Themes shipped in recent betas:

| Theme | Status |
|-------|--------|
| Strict consecutive-pair probe tolerance (`G6512`, 3 touches, default 0.0075 mm) | ✅ beta.5+ |
| MOS → nxt configuration migration (`nxt-mos-import.g`, auto-detect on boot) | ✅ |
| `auto-major` DWC/RRF compatibility in built `plugin.json` | ✅ |
| Configuration panel save to SD via DWC upload API | ✅ |
| CI: nxt-only checkout; DWC via read-only tarball (`ci/dwc-build-ref` → v3.6.2) | ✅ beta.6+ |

Manual DWC install and smoke-test remain required before treating a beta as release-ready (see `.cursor/rules/release-plugin-verify.mdc`).

---

## Outstanding work (excluding end-to-end testing)

| Priority | Item | Notes |
|----------|------|--------|
| High | **Public site manual** | [millenniummachines.github.io](https://github.com/MillenniumMachines/millenniummachines.github.io) `millennium-os/` chapters still describe legacy MOS (G8000 wizard, old repo links). Staging branch: `next-docs`. |
| High | **Migration guide** | `nxt-mos-import.g` exists; user-facing `docs/MIGRATION.md` not written. |
| Medium | **VSSC** | Not implemented under `nxt*`; see Phase 4. |
| Medium | **Machine calibration** | `docs/CALIBRATION.md` only; M9001–M9004 macros missing. |
| Medium | **`M4005` post version check** | Documented in `DETAILS.md`; macro not implemented (post-processors in `post-processors/`). |
| Low | **Spindle/coolant control UI** | Optional panels beyond status widget. |
| Low | **Spindle feedback** | Nice-to-have (`FEATURES.md`). |
| Low | **Stock prep material calculator** | Future enhancement. |

---

## Phase 5: Finalization & Release

This phase focuses on testing, documentation, and preparing for a public release.

1.  **Testing:**
    *   Conduct thorough end-to-end testing of all features, with a strong focus on the accuracy and reliability of the new probing and tool change systems.
    *   Each `v0.6.0-beta.N` tag should be validated on hardware (plugin load, Configuration save, G37 / probing echoes) before promotion.

2.  **Documentation:**
    *   Update all documentation (`README.md`, `DETAILS.md`, `UI.md`, etc.) to reflect the new architecture, features, and UI workflow.
    *   Create a migration guide for existing MillenniumOS users (`docs/MIGRATION.md`).
    *   Rewrite [millennium-os manual](https://millenniummachines.github.io/docs/millennium-os/) on `next-docs` branch (install nxt ZIP, Configuration panel, probing tolerance, MOS import).
    *   Align README / FEATURES with implemented vs planned items (e.g. VSSC).

3.  **Release Preparation:**
    *   Utilize the existing build and release scripts to package the new version (`dist/build-plugin.sh`, `dist/release.sh`; CI on tag push).
    *   Prepare release notes detailing the changes, improvements, and breaking changes.
