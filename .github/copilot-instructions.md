# NeXT AI Coding Guidelines

## Project Overview
NeXT (Next-Gen Extended Tooling) is a complete rewrite of the legacy MillenniumOS that extends RepRapFirmware (RRF) v3.6+ with meta G-code macros for CNC operations. This is designed specifically for CNC machines, not 3D printers.

**RRF reference for code review:** Target **RepRapFirmware 3.6.2** when evaluating macro behavior, G/M-codes, and object-model usage (see [`docs/RRF_REFERENCE.md`](../docs/RRF_REFERENCE.md)).

### Core Architecture
- **Macros** (`macros/`): G-code files with logic organized by function:
  - `macros/system/`: Core initialization (`nxt-boot.g`), globals (`nxt-vars.g`), daemon tasks
  - `macros/probing/`: All probing cycles and probe-related functionality
  - `macros/spindle/`: Spindle control and safety wrappers
  - `macros/coolant/`: Coolant control (mist, flood, air blast)
  - `macros/tooling/`: Tool changing and length measurement
  - `macros/utilities/`: Parking, power control, general utilities
- **UI** (`ui/`): JavaScript plugin for Duet Web Control integration
- **Post-Processors** (`post-processors/`): Fusion360/FreeCAD scripts that may output extended G-codes when standard NIST codes are insufficient
- **Documentation** (`docs/`): Comprehensive guides for development, testing, and features

### Data Flow & Design Philosophy
- Global variables with `nxt*` prefix for state management (e.g., `nxtProbeResults`)
- **Object Model**: RRF's object model is the source of truth for machine information (https://github.com/Duet3D/RepRapFirmware/wiki/Object-Model-Documentation)
- **DRY Macros**: Common information (e.g., compensated positions) abstracted into reusable macros, balanced against memory usage
- **Simplicity First**: Wrapper macros add safety to RRF commands without complexity
- **Numerical Stability**: Algorithms prioritize accuracy, especially in probing operations
- **Single-Axis Probing**: Core principle - one axis movement per probing command

## Development Repository & Workflow

### Repository Structure
**Current Repository**: `benagricola/NeXT` - All development targets the `main` branch.

### Branching Strategy
- **Feature Branches**: Create from `main` for all new features
- **Direct Commits**: Only for documentation, initial scaffolding, or core loading scripts
- **Clean History**: Squash commits when merging; aim for one commit per feature

### Development Process
1. **Feature Planning**: Scope work to specific features from `docs/FEATURES.md`
2. **Branch Creation**: Descriptive names like `feature/probing-engine` or `fix/tool-change-logic`
3. **Implementation**: Follow phase-based approach from `docs/ROADMAP.md`
4. **Testing**: Live machine testing required (see `docs/TESTING.md`)
5. **Pull Request**: Self-review mandatory using `gh pr diff --json`
6. **Merge**: Squash and merge to `main`

### GitHub CLI Best Practices
- **Avoid Pagers**: Use `gh pr diff 220 | tee` or `export PAGER=` to prevent hanging
- **Structured Output**: Use `--json` flags for machine-readable data
- **Self-Review Focus**: Look for logic errors, complexity, dead code, and typos

## Technical Standards

**IMPORTANT: Always read ALL documentation files in the `docs/` directory before starting any work, especially `docs/CODE.md` for complete coding conventions and style requirements.**

### RRF Meta G-Code Development
- **System G/M-Codes**: Reference https://docs.duet3d.com/User_manual/Reference/Gcodes
- **Meta G-Code**: Leverage RRF's extended language features (variables, conditionals, loops)
- **Documentation**: https://docs.duet3d.com/User_manual/Reference/Gcode_meta_commands
- **Line length (hard stop):** No `macros/**/*.g` line may exceed **200 characters** (non-comment lines). RRF reports `GCode command too long` and aborts startup — `nxt.g` never sets `global.nxtLoaded`. Split long `if`/`echo`/`abort`/`M291` into `var` steps. Run `node dist/check-gcode-line-length.mjs` before any plugin build or macro PR; fix all failures. See [`docs/RRF_LINE_LENGTH.md`](../docs/RRF_LINE_LENGTH.md). **Never** commit macro changes that fail this check.

### Coding Conventions
**ALL coding conventions, style requirements, and technical standards are documented in `docs/CODE.md`. Read this file completely before making any code changes.**

## Testing & Quality Assurance

### Testing Strategy
- **Live Machine Testing**: Primary testing method (see `docs/TESTING.md`)
- **No Automated Tests**: Use `echo` statements for debugging
- **Safety First**: Always test with soft materials first
- **Operator Confirmation**: Required for any machine movement

### Build & Release Process (NeXT DWC plugin)
- **Authoritative guidance:** `.cursor/rules/release-plugin-verify.mdc` (always-on for Cursor agents).
- **Plugin manifest:** `ui/plugin.json` — `rrfVersion` and `dwcVersion` must stay aligned with the supported stack; bump together and sync short mentions in README, `ui/src/index.ts`, `docs/UI_DEVELOPMENT.md`, and `docs/RRF_REFERENCE.md` as needed.
- **Before any release commit or version tag:**
  1. From NeXT repo root: `./dist/build-plugin.sh <path-to-DuetWebControl>` — **must exit 0** (DWC tree matching `dwcVersion`, e.g. 3.6.2).
  2. **User must explicitly confirm** manual verification: plugin ZIP installs, NeXT loads in DWC, smoke-test OK. Do not tag on build success alone.
- **Betas:** Incremental annotated tags `vMAJOR.MINOR.PATCH-beta.N`; do not force-move stable tags without explicit user request.
- **CI:** Push of `v*` tags triggers [`.github/workflows/release.yml`](.github/workflows/release.yml), which checks out **NeXT only** and fetches DWC via read-only tarball ([`dist/ci-fetch-dwc.sh`](../dist/ci-fetch-dwc.sh), pin [`ci/dwc-build-ref`](../ci/dwc-build-ref)) — no `actions/checkout` or push to external repos. Local build + manual load confirmation still required before tagging.
- **Full SD / release zip:** `dist/release.sh` (see script docs); plugin-only zip: `dist/build-plugin.sh`

## Integration & Compatibility

### RRF Integration
- **Version requirement (machines)**: RRF v3.6+ for meta G-code features (see README for stated minimum)
- **Reference version (development / review)**: **RRF 3.6.2** — [`docs/RRF_REFERENCE.md`](../docs/RRF_REFERENCE.md)
- **Axis Support**: Assumes 3-4 axes, ignores extras in commands
- **Position Queries**: Use `M5000` macro, not `lastStopPosition`
- **Daemon Integration**: Uses `daemon.g` for repetitive tasks (VSSC, etc.)

### UI Integration
- **Fallback Strategy**: Check `global.nxtLoaded` for NeXT firmware boot success (not a DWC handshake flag)
- **Manual Alternatives**: Always provide M291 dialogs as fallback
- **Plugin System**: Integrates with Duet Web Control plugin architecture

### External Tool Integration
- **Post-Processors**: Output extended G-codes for enhanced functionality
- **CAD Workflows**: Documented in `docs/` directory
- **Version Checking**: Post-processors validate NeXT version compatibility

## Development Phases & Feature Implementation

### Feature Tracking
- Use `docs/FEATURES.md` for feature requirements and status
- Mark completed features with checkboxes
- Reference specific features in commit messages and PRs

## Key Reference Documents
- **Coding Style**: `docs/CODE.md` - Complete style guide and conventions
- **Development Process**: `docs/DEVELOPMENT.md` - Detailed workflow and PR process
- **Feature Requirements**: `docs/FEATURES.md` - Complete feature list and priorities
- **Implementation Roadmap**: `docs/ROADMAP.md` - Phase-based development plan
- **Testing Procedures**: `docs/TESTING.md` - Live machine testing guidelines
- **Legacy Documentation**: `docs/DETAILS.md` - Understanding existing MillenniumOS functionality
- **G-Code Reference**: `GCODE.md` - Custom G-code and M-code documentation
- **UI Development**: `docs/UI_DEVELOPMENT.md` - Complete guide for developing the NeXT UI plugin in DuetWebControl

## Safety & Liability Considerations
- **Physical Hardware**: All testing involves real CNC machines
- **Safety First**: Operators must be present and ready for emergency stop
- **Incremental Testing**: Test with soft materials before actual workpieces
- **Clear Messaging**: Error messages must be descriptive and actionable
- **Confirmation Required**: Any machine movement requires explicit operator confirmation