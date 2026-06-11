# Legacy MillenniumOS Build Process (Historical Reference)

> **nxt (current):** Build the DWC plugin with `./dist/build-plugin.sh <path-to-DuetWebControl>` from the repository root; tagged releases use `dist/release.sh` (same plugin ZIP layout, versioned `nxt-<version>.zip` name). **Release workflow** (manifest alignment, successful build, manual plugin load in DWC before tags): see [`.cursor/rules/release-plugin-verify.mdc`](../.cursor/rules/release-plugin-verify.mdc) and [`.github/copilot-instructions.md`](../.github/copilot-instructions.md) (Build & Release Process).

## nxt CI build policy

| Workflow | Triggers | Output |
|----------|----------|--------|
| [`.github/workflows/check.yml`](../.github/workflows/check.yml) | Push/PR to `main` or version branches | Macro line length + DWC pin checks only |
| [`.github/workflows/release.yml`](../.github/workflows/release.yml) | Push/PR to version branches (e.g. `v0.6.0`, `v0.6.0-beta.13`) or push of **`v*`** tags | Full build via `dist/release.sh` |

- **`main`** does not trigger a full CI build. Merge there for integration; open a PR to a version branch or push a tag for downloadable ZIPs.
- **Version branches** (`vMAJOR.MINOR.PATCH` or `vMAJOR.MINOR.PATCH-beta.N`): push or PR → Actions **Artifacts** include `nxt-*.zip` (plugin + macros).
- **Tags** (`v0.6.0-beta.N`, etc.): draft **GitHub Release** with `nxt-<version>.zip` plus post-processors; no Actions artifacts (use the Release page).
- Local release publishing: [`dist/publish-release.sh`](../dist/publish-release.sh).

This document outlines the build and release process for the legacy version of MillenniumOS. This is for reference purposes only, as the nxt rewrite will use an updated process.

---

## Overview

The legacy build process consists of two main parts:
1.  **UI Plugin Compilation:** Compiling the Vue.js user interface components into a single plugin file that can be loaded by Duet Web Control (DWC).
2.  **Release Packaging:** Gathering all the macros, system files, post-processors, and the compiled UI plugin into a single `.zip` archive for distribution.

This entire process was orchestrated by the `dist/release.sh` script.

---

## 1. UI Plugin Compilation

The UI was a standard DWC plugin built using Vue.js. The compilation was handled by the DuetWebControl build system itself.

#### **Prerequisites:**
*   A local clone of the official `DuetWebControl` repository was required.
*   The path to this local repository was passed to the release script or defaulted to a sibling directory named `DuetWebControl`.

#### **Build Steps (as performed by `release.sh`):**

1.  **Navigate to DWC Repo:** The script would change into the `DuetWebControl` repository directory.
2.  **Install Dependencies:** It would run `npm install` to ensure all dependencies for the DWC build system were present.
3.  **Run Build Script:** It would then execute `npm run build-plugin <path_to_mos_ui_source>`, passing the path to a temporary directory containing the MillenniumOS `ui/` source code.
4.  **Output:** The DWC build script would compile, bundle, and output a complete plugin package named `MillenniumOS-VERSION.zip` into the `DuetWebControl/dist/` directory.

---

## 2. Release Packaging (`dist/release.sh`)

The main release script handled gathering all necessary files into a final `mos-sd-release.zip` archive.

#### **Packaging Steps:**

1.  **Create Temp Directory:** A temporary directory was created to stage the files.
2.  **Copy Files:** `rsync` was used to copy all the necessary files from the MillenniumOS repository into the correct structure within the temporary directory:
    *   `sys/*` -> `sd/sys/`
    *   `macro/public/*` -> `sd/macros/MillenniumOS/`
    *   `macro/private/*` -> `sd/sys/mos/`
    *   Other `macro` subdirectories -> `sd/sys/`
    *   `post-processors/**/*` -> `posts/`
    *   `ui/*` -> (root of temp dir, for the build process)
3.  **Versioning:** The script used `sed` to replace the `%%MOS_VERSION%%` placeholder with the current Git commit ID in all `.g` files and the `plugin.json`.
4.  **UI Integration:**
    *   After the UI plugin was built (as described above), the script would copy the final `MillenniumOS-VERSION.zip` to the main project's `dist/` folder.
    *   It would then `unzip` only the `dwc/*` contents from that plugin zip into the `sd/` directory being staged for the final release. This embedded the compiled UI assets into the main package.
    *   **Plugin Activation (`dwc-plugins.json`):** The script would then extract the names of the generated Webpack chunk files from the UI build. These details were written to a `dwc-plugins.json` file, which was placed in the `sd/sys/` folder. This file served to "activate" the plugin, allowing DWC to automatically enable it upon first boot after extracting the SD card contents.
5.  **Final Zip Creation:** The script would navigate into the `sd/` directory and create the final `mos-sd-release.zip`, containing the macros, system files, and the compiled UI, ready for distribution.
