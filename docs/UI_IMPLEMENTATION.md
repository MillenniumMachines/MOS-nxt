# NeXT UI Plugin

This directory contains the Vue.js-based UI plugin for NeXT (Next-Gen Extended Tooling) that integrates with Duet Web Control (DWC).

## Phase 2.1 Implementation Status

✅ **Completed:**
- Plugin scaffolding and directory structure
- `plugin.json` manifest file for DWC registration
- Main Vue plugin entry point (`src/index.ts`)
- Base component with common functionality (`BaseComponent.vue`)
- Main layout component (`NeXT.vue`)
- Core Status Widget for persistent machine status display
- Action Confirmation Widget for M291 dialog integration
- Component registration system for modular organization
- Localization support (English)
- Integration with NeXT global variables

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
- **`NeXT.vue`**: Main dashboard layout with tabbed interface
- **`BaseComponent.vue`**: Foundation component with common properties and methods

### Panel Components
- **`StatusWidget.vue`**: Persistent status bar showing tool, WCS, spindle, and position
- **`ActionConfirmationWidget.vue`**: Non-blocking dialog interface for M291 dialogs
- **`MachineStatusPanel.vue`**: Detailed machine and NeXT system status
- **`ConfigurationPanel.vue`**: Comprehensive settings interface replacing G8000 wizard

### Wizard Components
- **`ProbeDeflectionWizard.vue`**: Guided wizard for measuring probe deflection using reference blocks

### Override Components
- **`MessageBoxDialog.vue`**: Replaces DWC's MessageBoxDialog with conditional rendering (persistent vs modal)

### Placeholder Components
- **`overrides/panels/`**: Ready for DWC panel replacement components
- **`overrides/routes/`**: Ready for DWC route override implementation

## Key Features

1. **Vue 2.7 Architecture**: Clean, modern Vue.js structure
2. **DWC Integration**: Proper plugin registration and store integration
3. **Persistent UI**: Non-blocking status and dialog widgets
4. **Global Variable Integration**: Direct access to NeXT backend variables
5. **Modular Design**: Component-based architecture for easy extension
6. **Localization Ready**: i18n support with English strings

## Dialog System Integration

The Action Confirmation Widget integrates with the M291 dialog system from PR #16:
- **MessageBoxDialog Override**: Replaces DWC's built-in MessageBoxDialog component with conditional rendering
- **Persistent Dialogs**: When NeXT UI is active, dialogs appear in the ActionConfirmationWidget instead of blocking modals
- **Critical Message Fallback**: Emergency/error messages still show as blocking modals for safety
- **Automatic Detection**: Uses `global.nxtLoaded` and message content analysis to determine MessageBox rendering mode
- Responds to dialogs using M292 commands
- Provides responsive button interface for user actions

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