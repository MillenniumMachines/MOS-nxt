# nxt — extended tooling for RepRapFirmware (MOS-nxt)

## ⚠️ ⚠️ ⚠️ Please download nxt from the [Releases](https://github.com/MillenniumMachines/MOS-nxt/releases) page only

## Introduction

Cheap and easy manual and automatic work-piece probing, toolchanges, toolsetting and more!

This is an "operations system" rather than an "operating system" in the traditional sense.

We build _on top of_ RepRapFirmware, providing operators of the Millennium Machines Milo V1.5 with a new-machinist-friendly workflow for work-piece and tool probing, and safe, effective tool changes.

## Features

- Canned probing cycles usable directly from gcode or via Duet Web Control as named macros.
- Fallbacks to guided manual probing when touch probe and / or toolsetter is not available.
- Safety checks at every step to instill confidence in novice machinists.
- Variable Spindle Speed Control (planned; not yet in v0.6 betas).
- Compatible with Millennium Machines Milo GCode Dialect.

## Usage

Please follow the installation instructions on our [documentation](https://millenniummachines.github.io/docs/millennium-os/) site.

If you have not already installed a supported RRF configuration, then you should follow the instructions for the [Milo](https://millenniummachines.github.io/docs/milo/).

If you are not using a Millennium Machine, you will need to create a compatible configuration yourself.

## Liability

You are fully responsible for running the code contained in this library on your own machine. It has been tested on a number of different machines by different people, and is written from a safety-first perspective, but it is a fool who thinks that they can write software without bugs, and it is a (somewhat lesser) fool to _use_ that software and not expect occasional shenanigans. These shenanigans might cost you money in the best case, and blood in the worst - and by using this software you agree that we are not liable for any losses that might occur to you or others during your use of the software.

It is up to you, and only you, to take the relevant precautions when using nxt - run your tool paths without a workpiece installed and spindle disabled, test the probing routines with soft(er) items (e.g. a roll of tape for bore probe, a cardboard box for block or corner probes), stay away from the machine when it is moving and ___ALWAYS WEAR EYE PROTECTION___!

Remember that this is designed for machines that can really hurt you if you're not careful. This software tries its best to protect you but nothing can stand in the way of a really determined idiot :sweat_smile:

## Bugs, Issues, Support

If you find any bugs or issues, please create an issue on this repository. Best-effort support is available via our [Discord](https://discord.gg/ya4UUj7ax2).

---

## Information for Advanced users and Developers

The information contained here is for advanced users who want to understand further how nxt works, and what it is capable of. For normal usage, all the information you need is in the [documentation](https://millenniummachines.github.io/docs/millennium-os/manual/installation/).

### Notes

- You _must_ be using RRF **3.7.x** on branch **`v0.7.0`** (minimum **3.7.0-beta.1** while upstream is in beta). nxt uses meta G-code features that do not exist in earlier versions. For **3.6.x** machines, stay on nxt **`v0.6.0`** releases.

**Reference firmware for development:** When reviewing or extending nxt on branch **`v0.7.0`**, treat **[RepRapFirmware 3.7.0-beta.1](docs/RRF_REFERENCE.md)** as the evaluation baseline. See [`docs/RRF_REFERENCE.md`](docs/RRF_REFERENCE.md) and [`docs/VERSIONING.md`](docs/VERSIONING.md).
- nxt includes its own `daemon.g` file for repetitive tasks (VSSC is planned but not yet implemented). If you want to implement your own repetitive tasks, create a `user-daemon.g` file in the `/sys` directory, which nxt will run during its daemon loop. Do not use long-running loops inside `user-daemon.g` as this will interfere with nxt's daemon behaviour.

### RRF Config

You need a working RRF config with all of your machine axes moving in the right direction before you start.

If you can't home your machine, make that work first - following the nxt configuration wizard will be impossible without a machine that moves correctly.

You need to configure your Toolsetter and optionally, Touch Probe, in RRF before trying to use them in nxt.

This involves configuring both of them as Z probes, which can be done with the `M558` command.

You would add line(s) similar to these to your RRF `config.g` file, above where the nxt file (`nxt.g`) is included.

```gcode

; Configure the touch probe as Z-Probe 0 on pin "probe" - mainboard specific, DO NOT COPY AND PASTE!
; Type P5             = filtered digital
; Dive Height H5      = back-off 5mm before repeat probing
; Max Retries A10     = retry probe a maximum of 10 times
; Tolerance S0.01     = when tolerance is reached, stop probing
; Travel Speed T1200  = travel moves run at this speed to the start of the probing location
; Probe Speed F300:50 = initial probe speed runs at 300mm/min, subsequent at 50mm/min
M558 K0 P5 C"probe" H2 A10 S0.01 T1200 F300:50

; Configure the toolsetter as Z-Probe 1 on pin "xstopmax" - mainboard specific, DO NOT COPY AND PASTE!
; Type P8             = unfiltered digital
; Dive Height H10     = back-off 10mm before repeat probing
; Max Retries A10     = retry probe a maximum of 10 times
; Tolerance S0.01     = when tolerance is reached, stop probing
; Travel Speed T1200  = travel moves run at this speed to the start of the probing location
; Probe Speed F300:60 = initial probe speed runs at 300mm/min, subsequent at 60mm/min
M558 K1 P8 C"xstopmax" H10 A10 S0.01 T1200 F300:60

```

#### Tool Definition

You will also want to remove any manual tool definitions from your configuration, as nxt manages tools through the `M4000` and `M4001` custom M-codes - remove any lines in your `config.g` that use the `M563` command, and also any lines which refer to tools which would have been created by these commands (e.g. `G10 P<toolnumber>`).

#### Touch Probe Type Configuration

Some touch probes may not filter their outputs, which means they can be subject to bouncing. This is where, when the switch or detection mechanism inside the touch probe changes state, it flaps between the two states before settling into its' final position. This can cause issues in nxt with protected moves, as we stop moving when the probe is activated or deactivated but by the time we check the probe status, it might have flipped.

The solution for this is to define the touch probe as ID _Zero_ and the probe type as 5 (`M558 K0 P5 C"probe"...`), as in the above example configuration line. This enables filtering in RRF which debounces the probe input. The downside of this is that the probe may respond more slowly, but this is not necessarily a problem as the delay is likely to be accounted for in the deflection values calculated for X and Y. It is also not possible to define more than one probe as type 5, so if you already have a probe that requires type 5 that is _not_ your touch probe then this may be an issue.

Your touch probe may not need filtering, and you can test this by moving it to a different probe ID (2, for example) and changing the type to 8 like the toolsetter definition.

### Warnings and Known Issues

Due to some issues with RRF as it currently stands, there are a small number of situations where you can shoot yourself in the foot when running nxt macros outside of a print file. These are:

- Clicking Cancel on a messagebox to abort a probing routine may trigger undesired behaviour when running a probe **outside** of a print file. This is because clicking cancel on a message box, if outside of a print, simply returns from the macro that created the box. There is no way to easily detect this from any calling macros so we could end up running moves that were unexpected. This is something that ideally will need to be fixed by the RRF devs and is documented [here](https://forum.duet3d.com/topic/34945/meta-gcode-result-variable-inconsistent-with-docs?_=1707734672834). When clicking cancel from _within_ a print, the whole print is aborted from that point so this behaviour should not be an issue when executing actual CAM code produced by our post-processor.

- Toolchanges cannot currently be cancelled, so if a touch probe is not detected during the touch probe installation routine, then the active tool number will still be set to the probing tool. This will not affect print files because an aborted toolchange aborts the print (but still sets the active tool number). We use the tool number as a guard to not execute probing routines unless the touch probe is installed, so this leaves some window of vulnerability where it could _appear_ like a touch probe is connected when it actually wasn't detected. Again, this is likely something that should be fixed in RRF but if we absolutely _have_ to work around it by tracking touchprobe connectivity ourselves then we can implement this.

- If the touch probe is activated during a protected move, then due to how this is implemented in RRF it is _possible_ that the speeds of the probe were not reset correctly. Subsequent probes will run at the same speed which might be very slow, or very fast (if the interrupted move was a travel move). You should be aware of this when restarting from a collision during a protected move. We are currently looking for options as to how to improve this behaviour, but it may involve underlying changes to RRF to allow this.

- Memory limits on the `stm32f4` chip are very restrictive - nxt uses quite a lot of global variables for communication between macros and configuration, and is pushing the limits of this chip. You may receive `OutOfMemory` crashes (check `M122` after an unexpected reboot to confirm) if you use global variables in other places in your configuration. The only way around this issue at the moment is to reduce the number and size of global variables in other locations - nxt is already about as efficient as it can be.

#### Troubleshooting

To help us work out any issues, please run `M7600 D1` and paste the whole output into any issue you create, or attach with any help request in Discord. This output includes the value of nxt specific variables and also the contents of the RRF object model - specifically the limits, move, sensors, spindles, state and tool keys which are essential for debugging nxt functionality (or lack thereof).

---

## Installation

To install the nxt plugin on your physical machine:

1. **Download** the `nxt-vX.X.X.zip` package.
2. In Duet Web Control, navigate to **Settings → Plugins**.
3. Click **Install Plugin** and upload the ZIP. Start the plugin once installed.
4. **Mandatory Firmware Step:** Open your `0:/sys/config.g` via the System Directory and add `M98 P"nxt.g"` to the end of the file. (If you are upgrading from `mos`, ensure you remove the old `M98 P"mos.g"` and replace it with `nxt.g`).
5. Run `M999` to restart the board and load the new nxt globals.
6. In **Configuration**, select your **platform** (`v1.5` or `v1.6_v2`), then **Apply platform sys files** so `0:/sys/home*.g` match that platform ([homing requirements](docs/NXT_BOARD_HOMING.md)).
7. Optional tuning: the plugin installs `0:/sys/nxt-user-overrides.g.example`; copy it to `nxt-user-overrides.g` to override globals after the rest of nxt has loaded (probe repeatability, etc.).

## DWC Plugin Development

The nxt UI is a **Vue 2.7 / Vuetify 2.x** plugin for [Duet Web Control](https://github.com/Duet3D/DuetWebControl) **3.7.x** on branch **`v0.7.0`** (`dwcVersion` in [`ui/plugin.json`](ui/plugin.json)). See [docs/VERSIONING.md](docs/VERSIONING.md).

For building and testing **additional** nxt-compatible plugins (sibling repos, catalog, plugin ZIP), see [docs/LOCAL_PLUGIN_BUILD_AND_TEST.md](docs/LOCAL_PLUGIN_BUILD_AND_TEST.md).

### Quick Start

**Prerequisites:** A local clone of [DuetWebControl](https://github.com/Duet3D/DuetWebControl) matching [`ci/dwc-build-ref`](ci/dwc-build-ref) (currently **`v3.7.0-beta.1`**) with `npm install` completed. Run `./dist/ci-fetch-dwc.sh` to fetch the pinned tree.

```powershell
# 1. Create a directory junction (Windows) — folder name MUST match plugin.json "id"
mklink /J "<DWC_ROOT>\src\plugins\nxt" "<THIS_REPO>\ui"

# On Linux/macOS use a symlink instead:
# ln -s <THIS_REPO>/ui <DWC_ROOT>/src/plugins/nxt

# 2. Start the dev server from the DWC root
cd <DWC_ROOT>
npm run dev
# → http://localhost:8080/
```

On first load: cancel the "Connect to Machine" dialog → **Settings → Plugins → Start "nxt"** → it appears under **Control** in the sidebar.

### What the Plugin Provides

| Tab | Features |
|-----|----------|
| **Status** | Live axis positions (machine + work coords), nxt system health (`nxtLoaded`), feature flags (touch probe, tool setter, coolant) |
| **Configuration** | Globals snapshot, board pack / platform selection (`docs/NXT_BOARD_CONFIG.md`), feature config |
| **Probing** | 11 probing cycles (bore, boss, pocket, block, web, corner, rotation, vise corner, single surface) with parameter forms and result-to-WCS push |
| **Tool Library** _(separate sidebar item)_ | Lists all RRF-configured tools with number, description, radius, status |

### Key Gotcha: `tsconfig.json`

Webpack resolves junctions/symlinks to their **real path**. When `ts-loader` walks up the MOS-nxt repo tree looking for `tsconfig.json`, it won't find one (it's in the DWC root, not here). The included `ui/tsconfig.json` solves this — it mirrors the DWC TypeScript config and maps `@/*` imports back to the DWC source tree. **Don't delete it.**

### Project Structure

```
ui/
├── index.ts                  # Plugin entry point (re-exports src/index.ts)
├── plugin.json               # DWC plugin manifest (id: "nxt")
├── tsconfig.json             # TS config for junction-based dev
├── package.json              # Peer dependencies (three.js for 3D viewer)
└── src/
    ├── index.ts              # Route + i18n + plugin data registration
    ├── nxt.vue              # Main dashboard component (3 tabs)
    ├── components/
    │   ├── base/             # BaseComponent.vue — shared store access
    │   ├── inputs/           # Input components (Phase 2.2)
    │   ├── panels/           # Status, Config, Probing, Tool Mgmt panels
    │   └── overrides/        # DWC component overrides (disabled by default)
    ├── locales/en.json       # English translations
    ├── utils/                # Object model helpers, gcode utils
    └── workers/              # Web worker for toolpath parsing
```

For detailed development workflow, see [docs/UI_DEVELOPMENT.md](docs/UI_DEVELOPMENT.md).

---

## Documentation

- **[docs/NAMING.md](docs/NAMING.md)** - Product (`nxt`), repository (`MOS-nxt`), and DWC plugin wiring
- **[GCODE.md](GCODE.md)** - Complete reference for all nxt G-codes and M-codes
- **[docs/CALIBRATION.md](docs/CALIBRATION.md)** - Comprehensive guide to machine calibration (steps-per-mm, backlash, probe deflection)
- **[docs/STOCK_PREPARATION.md](docs/STOCK_PREPARATION.md)** - Stock preparation UI implementation approach and technical specifications
- **[docs/ROADMAP.md](docs/ROADMAP.md)** - Development roadmap and feature implementation plan
- **[docs/FEATURES.md](docs/FEATURES.md)** - Feature requirements and implementation status
- **[docs/CODE.md](docs/CODE.md)** - Coding standards and style guide for contributors
- **[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)** - Development workflow and PR process
- **[docs/TESTING.md](docs/TESTING.md)** - Testing procedures and guidelines

---

## In Depth

### Implemented G- and M- codes

See [GCODE.md](GCODE.md) for a description of all nxt implemented G- and M- codes.

### Post-processor

nxt is designed to work with a specific gcode dialect, designed for the Millennium Machines Milo. It does not support any other gcode dialects.

The following is an example gcode style that nxt is designed to understand:

```gcode
(Exported by Fusion360)
(Post Processor: Milo v1.5 by Millennium Machines, version: Unknown)
(Output Time: Thu, 05 Oct 2023 20:03:20 GMT)

(Begin preamble)
(Pass tool details to firmware)
M4000 P2 R1.5 S"3mm Flat Endmill F=1 L=12.0 CR=0.0"
M4000 P3 R3 S"6mm Flat Endmill F=1 L=20.0 CR=0.0"

(Home before start)
G28

(Movement Configuration)
G90
G21
G94

(Probe origin corner and save in WCS 3)
G6600 W3

(Switch to WCS 3)
G56

(Enable Variable Spindle Speed Control)
M7000 P2000 V100

(TC: 3mm Flat Endmill L=12)
T2

(Start spindle and wait for it to accelerate)
M3.9 S19000


(Begin operation adaptive2d: 2D Adaptive1)
(Move to starting position in Z)
G0 Z15.0
...

(Stop spindle and wait for it to decelerate)
M5.9

(End Job)
M0
```
