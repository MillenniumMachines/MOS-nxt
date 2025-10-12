# NeXT Rewrite Roadmap

This document outlines the development roadmap for the complete rewrite of MillenniumOS, codenamed "NeXT" (Next-Gen Extended Tooling). The primary goal is to refactor the system for simplicity, accuracy, and maintainability, starting from a clean slate.

---

## Project Naming and Conventions

- **Project Name:** The official name for this rewrite is **NeXT**.
- **Variable Naming:** All global variables created for the NeXT system must be prefixed with `nxt` to avoid conflicts with other plugins or user variables (e.g., `nxtDeltaMachine`).
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
    *   The new directory structure has been committed to the dedicated NeXT repository: `benagricola/NeXT`
    *   This provides full control over development and refactoring without affecting existing MillenniumOS code.
    *   All future development will target this repository's `main` branch.
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

## Phase 2: Settings UI & Configuration (HIGH PRIORITY)

**This phase has been elevated in priority** as it has become clear that the settings UI will be very important to get done earlier than the more complex functionality. The settings UI is critical for proper system configuration and operation.

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

4.  **Essential Status & Control Panels:** ⚠️ Partial
    *   Develop core UI panels for machine status, spindle control, and coolant control.
    *   Implement basic WCS management interface.
    *   **Note:** Machine status panel completed. Spindle/coolant control and WCS management to be implemented in Phase 3.

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

This phase focuses on completing the tool change system and advanced features.

1.  **Complete Tool Change Logic:**
    *   Implement the "probe-on-removal" logic in `tfree.g` for standard tools.
    *   Implement the relative offset calculation in `tpre.g`.
    *   Implement the special case for the touch probe in `tpost.g` (probing a reference surface).

2.  **Drilling Canned Cycles:**
    *   Re-implement `G73`, `G81`, and `G83` for convenience.

3.  **VSSC (Variable Spindle Speed Control):**
    *   Re-implement VSSC as a self-contained feature that can be enabled via the new UI configuration.

4.  **Machine Calibration System:**
    *   Implement UI-based calibration wizard in Settings panel for guided step-by-step workflow.
    *   Create backend M-code macros for querying and updating calibration parameters (M9001-M9004).
    *   Implement automated steps-per-mm calibration using dual-dimension measurement method.
    *   Implement automated backlash measurement and compensation workflow.
    *   Implement automated probe deflection measurement procedure.
    *   Add calibration verification tests and accuracy reporting.
    *   Store calibration data and history in nxt-user-vars.g.
    *   Full documentation provided in `docs/CALIBRATION.md`.

5.  **Stock Preparation UI (Issue #34):**
    *   Implement UI panel for generating facing toolpaths for stock preparation.
    *   Create toolpath generation algorithms for multiple pattern types (rectilinear, zigzag, spiral).
    *   Add SVG-based visualization for real-time toolpath preview.
    *   Implement G-code generation from toolpath data.
    *   Support both rectangular and circular stock geometries.
    *   Provide configurable parameters: tool radius, stock dimensions, pattern type/angle, stepover/stepdown, feed rates, spindle speed.
    *   Include save-as-file and run-immediately functionality.
    *   Add comprehensive input validation and safety features.
    *   Full documentation and implementation approach in `docs/STOCK_PREPARATION.md`.

---

## Phase 5: Finalization & Release

This phase focuses on testing, documentation, and preparing for a public release.

1.  **Testing:**
    *   Conduct thorough end-to-end testing of all features, with a strong focus on the accuracy and reliability of the new probing and tool change systems.

2.  **Documentation:**
    *   Update all documentation (`README.md`, `DETAILS.md`, `UI.md`, etc.) to reflect the new architecture, features, and UI workflow.
    *   Create a migration guide for existing users.

3.  **Release Preparation:**
    *   Utilize the existing build and release scripts to package the new version.
    *   Prepare release notes detailing the changes, improvements, and breaking changes.