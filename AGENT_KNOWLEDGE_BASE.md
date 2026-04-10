# MOS Fourth Axis: Agent Knowledge Base

This document summarizes the custom architecture, development environment, and deployment strategies used for the **MOS Fourth Axis (DJR Fork)**. Use this as a primer for future AI chat agents or developers.

---

## 🏗 Architecture Overview

### Layers
| Layer | Location | Purpose |
| :--- | :--- | :--- |
| **RRF Macros** | `sys/*.g` | G-code macros for initialization, probing, and status |
| **DWC Plugin** | `dwc-plugin/` | Vue 2 / Vuetify UI panel for Duet Web Control |
| **Plugin SD** | `sd/plugins/mos-fourth-axis/` | Bootstrap script (`init.g`) + daemon hook |
| **Build Scripts** | `scripts/` | Shell scripts for plugin ZIP packaging |
| **Pre-built Release** | `dist/` | Ready-to-install plugin ZIP |

### Firmware Globals (set in `M4800.g` / `mos-fourth-axis-init.g`)
- `rotaryEnabled` (bool) — master enable flag
- `rotaryAOffsetDeg`, `rotaryATiltCompDeg`, `rotaryAHomeDeg` (float) — axis calibration values
- `rotaryMeasuredErrorDeg`, `rotarySuggestedAdjustDeg` (float) — error tracking
- `rotaryLastCalStatus` (string) — last calibration result
- `rotaryCenterY` (float) — **not** initialized on boot; created exclusively by `M4910` on first probe run, then updated on subsequent runs. Shows "Not set" in the UI until the user runs a probe cycle. Survives DWC reloads (firmware global lives in memory), but resets on board reboot.

---

## 🏗 High-Precision Probing (`M4910.g`)
- **Iterative Loop**: Uses a `while` loop (default: 5 iterations, configurable via `R` param, clamped 1–5).
- **Statistical Output**: Computes and displays **Mean Center Y** and **Standard Deviation**. High Std Dev indicates mechanical issues or probe inconsistency.
- **Safety Rollbacks**: Implements `G38.2` result verification. If the probe fails to trigger, it executes a safe retract/rollback routine (Z safe, X retract, A rotate back, return to start Y).
- **Workspace Zeroing**: Uses `G10 L20 P0 Y0` to zero the active workspace regardless of which P-number (G54–G59.3) the user is currently in.
- **Persistent Center**: Writes `global.rotaryCenterY` using create-or-set pattern (`exists()` check) so it works on both first and subsequent runs.

---

## 🎨 DWC Plugin UI

### Component: `MosFourthAxisControl.vue`
- **Vue 2 + Vuetify** single-file component registered via `index.ts` at route `/Plugins/MosFourthAxis`.
- **Left Panel — "Rotary Status"**: Two-row table showing:
  - **Steps / degree**: Read live from `model.move.axes[].stepsPerMm` where `letter === 'A'`. Shows "—" if no A-axis is configured (e.g., simulation mode).
  - **Rotary Center Y**: Read from `global.rotaryCenterY`. Shows "Not set" before first probe.
- **Right Panel — Wizard Stepper**: 3-step flow (Select Macro → Input Values → Confirm + Execute).
  - Available macros: Probe Y Center (M4910), Probe X Flatness (M4911), Probe Y Flatness (M4912).
  - Reference images shown inline for M4910 and M4912 (Base64-encoded).
- **Firmware Global Access**: Uses a `readFirmwareGlobal()` helper that handles both `Map` and plain `Object` shapes from the DWC store (`$store.state.machine.model.global`).

### Base64 Image Bundling
- DWC's build scripts ignore static image directories in plugin folders, so reference PNGs are converted to Base64 data strings in `m4910_image.js` and `m4912_image.js`.
- Images are processed (via Python/Pillow, gitignored) to remove white backgrounds and autocrop margins for a premium "floating" look.
- UI diagrams scaled at **50% width** (`style="width: 50%"`) for optimal dashboard balance.

---

## 🚀 "Rapid Fire" Dev Environment

### Setup Steps
1. **DWC Location**: Local DWC 3.6 dev tree at `C:\Users\jonat\Downloads\DuetWebControl-3.6-dev\DuetWebControl-3.6-dev`.
2. **Directory Junction**: Link plugin source into DWC's plugin tree:
   ```powershell
   mklink /J "<DWC_ROOT>\src\plugins\MosFourthAxis" "<REPO>\dwc-plugin"
   ```
   **Critical**: The junction folder name must match the `"id"` field in `plugin.json` (i.e., `MosFourthAxis`, not `mos-fourth-axis`). DWC's auto-imports plugin asserts `dir.name === manifest.id`.
3. **Webpack Symlink Patch**: `webpack/lib/auto-imports-plugin.js` line 25 must support junctions:
   ```javascript
   if ((!file.isDirectory() && !file.isSymbolicLink()) || ...) { continue; }
   ```
4. **Launch**: `npm run dev` from the DWC root → serves at `http://localhost:8080`.

### CNC Mode
DWC's default dashboard is forced to **CNC Mode** by default in `src/store/settings.ts`.

### Plugin Discovery
The `plugin.json` must exist at the **root** of the linked plugin folder for the DWC auto-scanner to detect it.

---

## 📦 Building a Release ZIP

### The Problem
DWC's `scripts/build-plugin.js` follows junctions to the real path. When it detects the plugin is "external" (outside `src/plugins/`), it looks for a `dwc-src/` or `src/` subdirectory — which our layout doesn't have (files are at the root of `dwc-plugin/`). This causes build failures or stale builds.

### The Workaround
1. **Remove the junction** temporarily.
2. **Copy source files** directly into `src/plugins/MosFourthAxis/` (plugin.json, index.ts, .vue, image .js files).
3. **Run** `npm run build-plugin -- MosFourthAxis` from the DWC root.
4. **Add SD files** to the resulting ZIP using .NET `System.IO.Compression` in PowerShell (the bash script uses `zip -ur`).
5. **Restore the junction** for dev hot-reload.
6. **Copy final ZIP** to `dist/MosFourthAxis-1.0.0.zip`.

### SD File Staging
Before building, stage macro files into `dwc-plugin/sd/`:
```
dwc-plugin/sd/sys/*.g       ← copied from repo sys/
dwc-plugin/sd/plugins/...   ← copied from repo sd/plugins/
```
The build script (or manual process) merges these into the ZIP under the `sd/` prefix.

---

## 🐙 Git & Forking Strategy
- **Fork**: [jayem1427/djr-mos-fourth-axis](https://github.com/jayem1427/djr-mos-fourth-axis), forked from [kadders/mos-fourth-axis](https://github.com/kadders/mos-fourth-axis).
- **Forking from ZIP**: The project was initialized from a ZIP download but grafted to the upstream history using a "Git Soft Reset" technique.
- **Primary Branch**: `main`. Feature branches (e.g., `clean-up`) are used for batched changes before merge.
- **Excluded from Git**: Python helper scripts (`*.py`), `dwc-plugin/sd/` (staged at build time), `node_modules/`, loose `.zip` files.
- **Included in Git**: `dist/*.zip` — pre-built plugin releases are tracked so users can download directly from the repo.

---

## 🔧 Key Gotchas & Lessons Learned
1. **Junction name must match plugin ID**: `MosFourthAxis` not `mos-fourth-axis`. The webpack auto-imports plugin asserts an exact match.
2. **Build-plugin resolves symlinks**: It follows the junction to the real path, then applies external-plugin logic. Must copy files directly for production builds.
3. **`stepsPerMm` = steps/degree for rotary**: RRF uses the same property name for both linear and rotary axes. For the A-axis, the value represents steps per degree.
4. **Firmware globals survive DWC reload but not board reboot**: They live in firmware memory. The init script re-creates them on boot, but `rotaryCenterY` is intentionally left out of init so the UI can distinguish "never probed" from "probed at zero".
5. **A-axis index is not always 3**: The Vue component searches by `axes[].letter === 'A'` for robustness across different machine configs.
6. **Base64 image bundling is required**: DWC's build pipeline strips static assets from plugin directories. Encode images into JS modules as data URIs.

---
*Created by Antigravity (Advanced Agentic Coding)*
