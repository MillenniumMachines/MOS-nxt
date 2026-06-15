# nxt Configuration UI Guide

## Overview

The nxt Configuration UI is a comprehensive web-based interface that replaces the legacy G8000 configuration wizard. It provides direct, real-time editing of all nxt settings through an intuitive interface within Duet Web Control.

## Accessing the Configuration UI

1. Open Duet Web Control in your browser
2. Navigate to **Control** → **nxt**
3. Select the **Configuration** tab

## Configuration Sections

### 1. Features

Toggle switches to enable or disable major nxt features:

- **Touch Probe**: Enable automated touch probe operations
- **Tool Setter**: Enable automatic tool length measurement
- **Coolant Control**: Enable coolant system control

**Changes are applied immediately** to the object model when toggled.

### 2. Spindle Configuration

Configure your CNC spindle parameters:

| Setting | Description | Example |
|---------|-------------|---------|
| Spindle ID | RRF spindle index (0-based) | `0` |
| Acceleration Time | Time for spindle to reach target speed | `3.0` seconds |
| Deceleration Time | Time for spindle to stop | `2.5` seconds |

**Usage Notes:**
- Spindle ID should match your RRF configuration
- Acceleration/deceleration times are used by M3.9/M4.9/M5.9 macros to wait for spindle speed changes

### 3. Touch Probe Configuration

Configure your touch probe settings:

| Setting | Description | Example |
|---------|-------------|---------|
| Touch Probe Sensor ID | RRF probe index | `0` |
| Probe Tip Radius | Radius of probe tip for horizontal compensation | `1.5` mm |
| Probe Deflection | Measured deflection compensation value | `0.025` mm |

**Additional Features:**
- **"Measure Probe Deflection" Button**: Launches the deflection measurement wizard
- Manual input supported for pre-calculated deflection values

### 4. Tool Setter Configuration

Configure your tool setter (for automatic tool length measurement):

| Setting | Description | Example |
|---------|-------------|---------|
| Tool Setter Sensor ID | RRF probe index | `1` |
| Tool Setter Position | Position vector [X, Y, Z] in machine coordinates | `[150.0, 150.0, -5.0]` |

**Position Editor:**
- Click the pencil icon to open the position editor dialog
- Enter X, Y, and Z coordinates separately
- Position is stored in machine coordinates (not work coordinates)

### 5. Board & platform

Select the machine platform and board pack that match your hardware. Platforms are listed from the build-time manifest (`macros/nxt-config/`).

| Control | Description |
|---------|-------------|
| **Platform** | e.g. `v1.5` or `v1.6_v2` — sets `global.nxtPlatformProfile` |
| **Board profile** | Override `global.nxtBoardShortNameOverride` or leave Auto (first board in object model) |
| **Scylla motor voltage** | Required for Scylla packs: `24` or `48` V variant |
| **Bootstrap mode** | **Auto** — Save creates `0:/sys/nxt-board-bootstrap.requested`. **Off** — Save removes it. |
| **Apply platform sys files** | Uploads `homeall.g`, `homex.g`, `homey.g`, `homez.g` from `nxt-config/machine/<profile>/` to `0:/sys/` (deploy-only, not boot) |
| **Check SD board packs** | Compares bundled manifest to `0:/sys/nxt-config/` (stale plugin warning) |
| **Save Configuration** | Writes `nxt-user-vars.g` including `nxtBoardPackExpectedEntry` and syncs bootstrap sentinels |

When you change platform, the UI may prompt to deploy homing files for that platform immediately. Homing direction requirements differ between v1.5 and v1.6_v2 — see [NXT_BOARD_HOMING.md](NXT_BOARD_HOMING.md).

**Reload** re-runs `M98 P"nxt-user-vars.g"` and shows warnings if bootstrap files or pack paths do not match saved intent (`nxtBoardPackExpectedEntry` vs `nxtBoardPackEntry`).

The **Platform bundle on SD** list shows deployable sys files and board `entry.g` paths for the selected platform.

Pack loading vs homing deploy: [NXT_BOARD_CONFIG.md](NXT_BOARD_CONFIG.md).

### 6. Coolant Control Configuration

Configure GPIO pins for coolant control:

| Setting | Description | Example |
|---------|-------------|---------|
| Air Blast Pin ID | GP Output port for air blast | `0` |
| Mist Coolant Pin ID | GP Output port for mist coolant | `1` |
| Flood Coolant Pin ID | GP Output port for flood coolant | `2` |
| Pulse mist (M7) | Cycle mist output on/off; air blast stays on | off |
| Pulse flood (M8) | Cycle flood output on/off | off |
| Pulse ON duration | Seconds coolant output stays on per cycle | `5` |
| Pulse OFF duration | Seconds coolant output stays off per cycle | `25` |

**Usage Notes:**
- Pin IDs correspond to RRF general purpose output ports
- Set to `null` or leave empty if not using that coolant type
- Used by M7, M8, M9 coolant control macros
- Pulse timing requires `macros/system/daemon.g` (enabled by default via `global.nxtDaemonEnabled`)
- When pulsing is enabled for a type, `M7`/`M8` turn that output on in cycles; `M9` stops pulsing immediately
- Pause saves coolant **intent** (not instantaneous OFF phase) so resume restores pulsing correctly

## Configuration Actions

### Save Configuration

The **"Save Configuration"** button writes the full generated contents to **`/sys/nxt-user-vars.g`** (HTTP path for **`rr_upload`**, same on-board file as `0:/sys/nxt-user-vars.g`) in a single **`rr_upload`** POST with a raw body per the RRF HTTP API. That **replaces** the file each time, avoiding growth from line-by-line `echo` G-code.

Runtime values are still updated immediately via `set global.*` when you change fields; use **Save Configuration** when you want those values persisted across reboots in `nxt-user-vars.g`.

### Reload Configuration

The **"Reload"** button:

- If **`nxt-user-vars.g` exists** on SD (`global.nxtUserVarsPresent`): runs **`M98 P"nxt-user-vars.g"`**, then syncs the form from the object model.
- If the file is **missing** (first install): **no error** — the form is rebuilt from live nxt globals, MillenniumOS `mos*` globals (when present), and singleton auto-picks (e.g. one spindle → ID 0). Use **Save Configuration** to create `nxt-user-vars.g`.

Use Reload to apply hand-edits on the SD card, discard unsaved form changes, or refresh after external `set global.*` changes.

**Note:** Field edits apply to the object model on every change (`set global.*`). You do **not** need to tab out of a field before **Save** — Save writes the current form (`configDraft`), not stale values from blur-only sync.

## Probe Deflection Measurement Wizard

The wizard provides a step-by-step process for accurately measuring probe deflection using a precision reference block.

### Prerequisites

Before starting the wizard, ensure:
1. ✅ Machine is homed (all axes)
2. ✅ Touch probe is installed and configured
3. ✅ Precision reference block is secured to work surface (e.g., 1-2-3 block)
4. ✅ Machine is jogged to position probe over block center

### Wizard Steps

#### Step 1: Setup
- Reviews prerequisites
- Checks machine homing status
- Verifies probe tool configuration

#### Step 2: Block Dimensions
- Enter known dimensions of your reference block
- X Dimension: Width in X direction (default: 25.4mm / 1 inch)
- Y Dimension: Width in Y direction (default: 50.8mm / 2 inches)

**Tip:** Use precision-ground blocks like 1-2-3 blocks for best results.

#### Step 3: Measure X
- Click **"Probe X Surfaces"** button
- Wizard executes G6504 to probe both X sides of the block
- Measures actual X dimension
- Displays result when complete

#### Step 4: Measure Y
- Click **"Probe Y Surfaces"** button
- Wizard executes G6504 to probe both Y sides of the block
- Measures actual Y dimension
- Displays result when complete

#### Step 5: Results
View measurement results and calculated deflection:

| Axis | Known Dimension | Measured Dimension | Deflection |
|------|----------------|-------------------|------------|
| X | (entered value) | (measured value) | (difference) |
| Y | (entered value) | (measured value) | (difference) |

**Average Deflection:** The final value applied to `nxtProbeDeflection`

### Deflection Warnings

The wizard provides automatic validation:

| Condition | Warning | Action |
|-----------|---------|--------|
| Deflection > 0.1mm | ⚠️ Excessive deflection | Check probe spring tension |
| X and Y differ > 0.02mm | ⚠️ Inconsistent measurements | Verify reference block or measurement |

### Applying Results

Click **"Apply Deflection"** to:
1. Set `nxtProbeDeflection` to the average value
2. Close the wizard
3. Update the configuration panel

## How Configuration is Stored

### Object Model (Runtime)
All configuration values are stored as RRF global variables:
- Changes are immediate and affect running macros
- Values persist until machine restart
- Accessed via `global.variableName` in G-code

### File Persistence

On the machine, configuration lives on the SD card as **`0:/sys/nxt-user-vars.g`**; the UI saves it via **`rr_upload?name=/sys/nxt-user-vars.g`** (full-file HTTP upload):

- Loads automatically when nxt starts (`M98 P"nxt-user-vars.g"` from `nxt.g`) when the file exists
- If the file is missing at boot, nxt still loads (`global.nxtConfigPending = true`) so this panel is available — review settings and **Save** to create the file
- Survives machine restarts
- Can be edited manually on the SD card if needed
- **Probe repeatability** (G6512 sample count, pair tolerance, retries) is **not** in `nxt-user-vars.g` — defaults live in **`nxt-vars.g`**. The plugin ships **`0:/sys/nxt-user-overrides.g.example`** on SD; copy it to **`nxt-user-overrides.g`** to enable overrides. Only **`nxt-user-overrides.g`** is loaded (never the `.example` file), and only **last** in `nxt.g` after board pack and boot.

### Configuration Flow
```
User edits field
    ↓
Value validated in UI
    ↓
G-code sent: set global.variableName = value
    ↓
Object model updated
    ↓
"Save Configuration" button → `rr_upload` full replace of `/sys/nxt-user-vars.g`
```

## Best Practices

### Initial Setup
1. Start with all features disabled
2. Configure spindle parameters first
3. Enable and configure one feature at a time
4. Test each feature before enabling the next

### Touch Probe Setup
1. Configure touch probe sensor ID and tip radius
2. Install touch probe on machine
3. Run probe deflection wizard with precision reference block
4. Verify deflection value is reasonable (typically 0.01-0.05mm)
5. Enable touch probe feature

### Tool Setter Setup
1. Configure tool setter sensor ID
2. Install datum tool (known length tool)
3. Jog to tool setter center position
4. Record position using position editor
5. Probe tool setter height with G6512
6. Enable tool setter feature

### Troubleshooting

**Problem: Changes not saved after restart**
- Solution: Click "Save Configuration" button to persist to file

**Problem: Probe deflection seems incorrect**
- Solution: Re-run wizard with different reference block orientation
- Verify reference block dimensions are accurate
- Check that probe tip radius is set correctly

**Problem: Tool setter position incorrect**
- Solution: Re-jog to tool setter and update position
- Verify position is in machine coordinates, not work coordinates

**Problem: Feature toggle doesn't enable**
- Solution: Check that required settings are configured first
- Verify sensor IDs are valid
- Check RRF configuration matches

## Advanced Configuration

### Manual Variable Setting
You can also set configuration variables manually via G-code:

```gcode
; Enable touch probe
set global.nxtFeatureTouchProbe = true

; Set probe deflection
set global.nxtProbeDeflection = 0.025

; Set spindle parameters
set global.nxtSpindleID = 0
set global.nxtSpindleAccelSec = 3.0
```

### Configuration Backup
To backup your configuration:
1. Copy `macros/system/nxt-user-vars.g` to a safe location
2. Or use M500.1 to save a restore point

### Configuration Restore
To restore configuration:
1. Copy backed up file back to `macros/system/nxt-user-vars.g`
2. Or use M501.1 to load a restore point
3. Click "Reload" in Configuration UI

## Related Documentation

- [Board configuration & pack layout](NXT_BOARD_CONFIG.md)
- [Homing requirements (v1.5 vs v1.6_v2)](NXT_BOARD_HOMING.md)
- [UI Implementation Details](UI_IMPLEMENTATION.md)
- [Features Overview](FEATURES.md)
- [Development Roadmap](ROADMAP.md)
- [Legacy G8000 Wizard](DETAILS.md#g8000-mos-configuration-wizard)
