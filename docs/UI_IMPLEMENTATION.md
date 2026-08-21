# nxt UI Plugin

This directory contains the Vue.js-based UI plugin for **nxt** that integrates with Duet Web Control (DWC).

## Phase 2.1 Implementation Status

✅ **Completed:**
- Plugin scaffolding and directory structure
- `plugin.json` manifest file for DWC registration
- Main Vue plugin entry point (`src/index.ts`)
- Base component with common functionality (`BaseComponent.vue`)
- Main layout component (`nxt.vue`)
- Core Status Widget for persistent machine status display
- Action Confirmation Widget (kept; not mounted — stock DWC modal owns M291)
- Component registration system for modular organization
- Localization support (English)
- Integration with nxt global variables

## Phase 2.2 Implementation Status

✅ **Completed:**
- Configuration Panel component for direct settings editing
- Feature toggle system (Touch Probe, Tool Setter, Coolant Control)
- Spindle configuration interface
- Touch probe configuration interface
- Tool setter configuration interface
- Coolant control pin mapping interface
- Probe Deflection Measurement Wizard with step-by-step workflow
- Manual deflection input capability
- Real-time configuration updates to object model
- Configuration save/reload functionality
- Localization strings for configuration UI

## Components

### Core Components
- **`nxt.vue`**: Main dashboard layout with tabbed interface
- **`BaseComponent.vue`**: Foundation component with common properties and methods

### Panel Components
- **`StatusWidget.vue`**: Persistent status bar showing tool, WCS, spindle, and position
- **`ActionConfirmationWidget.vue`**: Unused on dashboard (kept for a future DWC MessageBox hook); stock DWC modal owns M291 ack
- **`MachineStatusPanel.vue`**: Detailed machine and nxt system status
- **`ConfigurationPanel.vue`**: Comprehensive settings interface replacing G8000 wizard

### Wizard Components
- **`ProbeDeflectionWizard.vue`**: Guided wizard for measuring probe deflection using reference blocks

### Override Components
- **`MessageBoxDialog.vue`**: Inert under Vue 3 (stock DWC modal wins); kept for a future override hook

### Placeholder Components
- **`overrides/panels/`**: Ready for DWC panel replacement components
- **`overrides/routes/`**: Ready for DWC route override implementation

## Key Features

1. **Vue 2.7 Architecture**: Clean, modern Vue.js structure
2. **DWC Integration**: Proper plugin registration and store integration
3. **Persistent UI**: Non-blocking status and dialog widgets
4. **Global Variable Integration**: Direct access to nxt backend variables
5. **Modular Design**: Component-based architecture for easy extension
6. **Localization Ready**: i18n support with English strings

# Dialog System Integration

Under DWC 3.7 (Vue 3), **stock DWC `MessageBoxDialog`** is the only M291/M292 ack UI. nxt’s
`MessageBoxDialog` override is inert (App.vue binds DWC’s own import). The nxt dashboard does
**not** mount a second Action Required widget — that caused double `M292` and hung macros
(Calibration / M5016).

`ActionConfirmationWidget.vue` / `nxtMessageBoxRespond.ts` remain in the tree for a future DWC
override hook. Do not re-enable a second ack path until the stock modal can be suppressed.
## Configuration UI Details

The Configuration Panel provides a complete replacement for the G8000 wizard with the following features:

### Feature Management
- Toggle switches for enabling/disabling major features:
  - Touch Probe
  - Tool Setter
  - Coolant Control
- Changes applied immediately to object model

### Spindle Configuration
- Spindle ID selection
- Acceleration time configuration
- Deceleration time configuration

### Touch Probe Configuration
- Sensor ID configuration
- Probe tip radius input (for horizontal compensation)
- Probe deflection value input
- "Measure Probe Deflection" wizard button

### Tool Setter Configuration
- Sensor ID configuration
- Position vector editor [X, Y, Z]

### Coolant Control Configuration
- Air blast pin ID mapping
- Mist coolant pin ID mapping
- Flood coolant pin ID mapping

### Probe Deflection Wizard
The wizard guides users through a 5-step process:
1. **Setup**: Prerequisites check (homed, probe configured, reference block)
2. **Block Dimensions**: Input known dimensions of reference block
3. **Measure X**: Probe X axis and record measurement
4. **Measure Y**: Probe Y axis and record measurement
5. **Results**: Calculate deflection, show warnings if needed, apply result

The wizard:
- Uses G6504 (Web probe) to measure block dimensions
- Calculates deflection as difference between measured and known dimensions
- Averages X and Y deflection for final value
- Provides warnings for unusual values (>0.1mm) or inconsistent measurements
- Applies result directly to nxtProbeDeflection variable

## Next Phases

- **Phase 3**: Probing interface and result management
- **Later**: Panel and route overrides for full DWC integration

## Build Process

The UI requires compilation using the DuetWebControl build system. See `docs/BUILD.md` for historical build process documentation.