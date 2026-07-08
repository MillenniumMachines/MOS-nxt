# Documentation index

All product documentation lives in **`docs/`** in this repository.

## Core reference

| Doc | Audience |
|-----|----------|
| [GCODE.md](../GCODE.md) | M/G-code reference |
| [FEATURES.md](FEATURES.md) | Feature checklist / status |
| [ROADMAP.md](ROADMAP.md) | Phases and backlog |
| [CODE.md](CODE.md) | Macro / meta G-code style |
| [plugin-spec.md](plugin-spec.md) | Plugin contract |
| [RRF_REFERENCE.md](RRF_REFERENCE.md) | RRF version pin (branch `v0.7.0` → 3.7.x) |
| [VERSIONING.md](VERSIONING.md) | nxt `v0.M.0` branch ↔ RRF/DWC `3.M.x` |
| [RRF_3.7_MIGRATION.md](RRF_3.7_MIGRATION.md) | Upgrading from RRF 3.6 to 3.7 with nxt |
| [NAMING.md](NAMING.md) | Product (`nxt`), repo (`MOS-nxt`), DWC wiring |
| [RRF_LINE_LENGTH.md](RRF_LINE_LENGTH.md) | Macro line-length limits (gates: `.cursor/rules/gcode-line-length.mdc`) |

## Machine setup and operation

| Doc | Audience |
|-----|----------|
| [TESTING.md](TESTING.md) | Live machine testing |
| [TOOLCHANGING.md](TOOLCHANGING.md) | tpre / tpost / tfree, tool library |
| [TOOLSETTING.md](TOOLSETTING.md) | Toolsetter workflow |
| [CALIBRATION.md](CALIBRATION.md) | Probe repeatability (M6523) |
| [NXT_BOARD_CONFIG.md](NXT_BOARD_CONFIG.md) | Board packs, platform profile |
| [NXT_BOARD_HOMING.md](NXT_BOARD_HOMING.md) | Homing deploy |
| [STOCK_PREPARATION.md](STOCK_PREPARATION.md) | Facing / stock prep feature |

## UI and plugin development

| Doc | Audience |
|-----|----------|
| [UI.md](UI.md) | UI architecture overview |
| [UI_DEVELOPMENT.md](UI_DEVELOPMENT.md) | DWC plugin dev loop |
| [UI_IMPLEMENTATION.md](UI_IMPLEMENTATION.md) | UI implementation notes |
| [CONFIGURATION_UI.md](CONFIGURATION_UI.md) | DWC Configuration panel |
| [LOCAL_PLUGIN_BUILD_AND_TEST.md](LOCAL_PLUGIN_BUILD_AND_TEST.md) | Multi-plugin build |
| [PLUGIN_LOAD_TROUBLESHOOTING.md](PLUGIN_LOAD_TROUBLESHOOTING.md) | Plugin load / 404 |
| [DEVELOPMENT.md](DEVELOPMENT.md) | PR workflow |

## Build, release, and history

| Doc | Audience |
|-----|----------|
| [BUILD.md](BUILD.md) | CI build policy; legacy MOS build notes |
| [DETAILS.md](DETAILS.md) | Legacy MillenniumOS reference (large; historical) |
| [PHASE3_SUMMARY.md](PHASE3_SUMMARY.md) | Historical probing phase summary |
| [future-state-plugin-template.md](future-state-plugin-template.md) | Future plugin template |
| [GEMINI.md](GEMINI.md) | Gemini notes |

## Editing policy

- Edit **`docs/<file>.md`** in this repository.
- Cursor rules (`.cursor/rules/*.mdc`) are authoritative for release gates and naming; keep linked docs in sync when rules change.
