# Stock Preparation UI - Implementation Approach

This document details the comprehensive approach for implementing the Stock Preparation UI feature (Issue #34) for NeXT. This feature will enable operators to generate facing toolpaths for stock preparation directly from the DWC UI, with visual preview and direct execution capabilities.

---

## 1. Overview

### Purpose
The Stock Preparation UI provides a guided interface for generating facing operations to prepare raw stock material before machining. This eliminates the need for external CAM software for simple facing operations and provides immediate feedback through visual toolpath preview.

### Key Capabilities
- Interactive UI for configuring facing operations
- Real-time toolpath visualization (SVG or WebGL)
- Multiple facing pattern support (rectilinear, zigzag, spiral)
- G-code generation for direct execution or file saving
- Integration with current tool and WCS settings

---

## 2. Input Parameters

### 2.1 Tool Configuration
**Tool Radius** (`toolRadius`)
- **Type:** Number (mm)
- **Default:** Current tool radius from `global.nxtToolRadius[nxtCurrentTool]` if tool is selected
- **Range:** 0.1mm - 50mm
- **Purpose:** Determines stepover calculations and toolpath boundaries
- **Source:** Read from NeXT's tool radius vector (RRF does not store tool radius)
- **Validation:** 
  - Must be positive
  - Should be less than stock dimensions
  - Warning if no tool selected

### 2.2 Stock Geometry

#### Rectangular Stock
**Shape Type** (`stockShape`)
- **Type:** Enum
- **Values:** `rectangular`, `circular`
- **Default:** `rectangular`

**X Dimension** (`stockX`)
- **Type:** Number (mm)
- **Range:** 1mm - 1000mm
- **Required:** Yes (for rectangular)
- **Purpose:** Stock width along X axis

**Y Dimension** (`stockY`)
- **Type:** Number (mm)
- **Range:** 1mm - 1000mm
- **Required:** Yes (for rectangular)
- **Purpose:** Stock depth along Y axis

**Origin Position** (`originPosition`)
- **Type:** Enum
- **Values:** 
  - `front-left` (X min, Y max)
  - `front-center` (X center, Y max)
  - `front-right` (X max, Y max)
  - `center-left` (X min, Y center)
  - `center-center` (X center, Y center)
  - `center-right` (X max, Y center)
  - `back-left` (X min, Y min)
  - `back-center` (X center, Y min)
  - `back-right` (X max, Y min)
- **Default:** `front-left`
- **Purpose:** Defines stock coordinate reference point relative to current WCS origin

#### Circular Stock
**Diameter/Radius** (`stockDiameter`)
- **Type:** Number (mm)
- **Range:** 1mm - 500mm
- **Required:** Yes (for circular)
- **Purpose:** Circular stock size
- **Note:** Can input as diameter or radius with toggle

**Origin Constraint** (`circularOrigin`)
- **Type:** Fixed
- **Value:** `center-center` (always)
- **Purpose:** Circular stock must be centered on WCS origin

### 2.3 Facing Pattern

**Pattern Type** (`facingPattern`)
- **Type:** Enum
- **Values:** 
  - `rectilinear` - Parallel passes back and forth
  - `zigzag` - Continuous alternating direction passes
  - `spiral` - Spiraling from outside to inside or vice versa
- **Default:** `zigzag`

**Pattern Angle** (`patternAngle`)
- **Type:** Number (degrees)
- **Range:** 0° - 360°
- **Default:** 0° (aligned with X axis)
- **Purpose:** Rotates facing pattern relative to stock orientation
- **Common Values:** 0°, 45°, 90° for different cutting strategies

**Milling Direction** (`millingDirection`)
- **Type:** Enum
- **Values:**
  - `climb` - Tool rotates in direction of feed (recommended for most materials)
  - `conventional` - Tool rotates opposite to feed direction
- **Default:** `climb`
- **Purpose:** Controls cutting direction relative to tool rotation
- **Benefits:**
  - **Climb milling:** Better surface finish, reduced tool wear, less heat buildup
  - **Conventional milling:** Better for machines with backlash, more forgiving for soft materials
- **Note:** Toolpath direction will be reversed based on spindle rotation direction (CW/CCW) to maintain selected milling type

### 2.4 Cutting Parameters

**Stepover** (`stepover`)
- **Type:** Number (mm or %)
- **Range:** 0.1mm - tool diameter
- **Default:** 75% of tool diameter
- **Purpose:** Lateral distance between adjacent passes
- **Note:** Can be specified as absolute mm or percentage of tool diameter
- **Validation:** Must be less than tool diameter

**Stepdown** (`stepdown`)
- **Type:** Number (mm)
- **Range:** 0.01mm - 10mm
- **Default:** 1mm
- **Purpose:** Depth of cut per Z level pass
- **Validation:** Must be positive

**Z Offset** (`zOffset`)
- **Type:** Number (mm)
- **Range:** -100mm to +100mm
- **Default:** 0mm
- **Purpose:** Starting Z height offset from current WCS Z origin
- **Note:** Positive values start above origin, negative below

**Total Depth** (`totalDepth`)
- **Type:** Number (mm)
- **Range:** 0.01mm - 100mm
- **Default:** 1mm
- **Purpose:** Total material to remove (calculated from zOffset)
- **Validation:** Must be positive

**Clear Stock Exit** (`clearStockExit`)
- **Type:** Boolean
- **Default:** `false`
- **Purpose:** Controls whether tool completely exits stock area during direction changes and stepdowns
- **Behavior:**
  - When `true`: Tool moves outside stock boundary by full tool diameter + 1mm clearance
  - When `false`: Tool stays within stock boundary (moves to tool radius from edge)
- **Benefits:** 
  - Cleaner surface finish when enabled
  - Direction changes and stepdowns occur without stock contact
  - Reduces marking from tool engagement/disengagement
  - Prevents witness marks at pass boundaries
- **Considerations:**
  - Increases cycle time due to additional travel moves
  - Requires adequate clearance around stock
  - May trigger protective boundaries if stock near machine limits

**Safe Z Height** (`safeZHeight`)
- **Type:** Number (mm)
- **Range:** 0mm - 100mm above current cutting depth
- **Default:** 5mm
- **Purpose:** Clearance height for rapid moves and retracts between passes
- **Behavior:** Height above current cutting depth (currentZ + safeZHeight)
- **Note:** Relative to current Z level - lowers as tool steps down to avoid large retractions
- **Example:** At -10mm depth, safe Z = -10mm + 5mm = -5mm (not back to stock top)
- **Validation:** Must be positive and sufficient to clear fixtures at all depths

**Finishing Pass** (`finishingPass`)
- **Type:** Boolean
- **Default:** `false`
- **Purpose:** Enables an additional finishing pass after roughing passes complete
- **Benefits:**
  - Better surface finish with reduced stepdown
  - Removes remaining material from previous passes
  - Can use different feed rates for better quality
  - Compensates for tool deflection
- **Note:** Runs after all roughing Z levels complete

**Finishing Pass Height** (`finishingPassHeight`)
- **Type:** Number (mm)
- **Range:** 0.01mm - 5mm
- **Default:** 0.2mm
- **Purpose:** Amount of material left for finishing pass
- **Behavior:** Final pass removes this amount from the bottom surface
- **Validation:** Must be less than stepdown value
- **Note:** Only active when finishingPass is enabled

**Finishing Pass Offset** (`finishingPassOffset`)
- **Type:** Number (mm)
- **Range:** -2mm to +2mm
- **Default:** 0mm
- **Purpose:** XY offset for finishing pass toolpath
- **Behavior:** Shifts the finishing pass toolpath inward (negative) or outward (positive)
- **Benefits:**
  - Compensates for tool wear or deflection
  - Fine-tunes final dimensions
  - Improves surface finish on edges
  - Accounts for spring pass effect
- **Validation:** Total offset must not exceed stock boundaries
- **Note:** Only active when finishingPass is enabled

### 2.5 Feed and Speed

**Horizontal Feed Rate** (`feedRateXY`)
- **Type:** Number (mm/min)
- **Range:** Dynamic - read from `move.axes[].maxFeedrate` in object model
- **Default:** 1000 mm/min (or minimum of axis max feed rates)
- **Purpose:** Feed rate for XY cutting moves
- **Validation:** Must not exceed minimum of X and Y axis maximum feed rates

**Vertical Feed Rate** (`feedRateZ`)
- **Type:** Number (mm/min)
- **Range:** Dynamic - read from `move.axes[2].maxFeedrate` in object model (Z axis)
- **Default:** 300 mm/min (or 50% of Z axis max feed rate)
- **Purpose:** Feed rate for Z plunge/ramp moves
- **Validation:** Must not exceed Z axis maximum feed rate

**Spindle Speed** (`spindleSpeed`)
- **Type:** Number (RPM)
- **Range:** Dynamic - read from `spindles[nxtSpindleID].min` to `spindles[nxtSpindleID].max` in object model
- **Default:** 10000 RPM (or midpoint of spindle range)
- **Purpose:** Spindle RPM during operation
- **Validation:** Must be within configured spindle's min/max range
- **Note:** Range determined by `global.nxtSpindleID` setting

---

## 3. Toolpath Generation Algorithms

### 3.1 Coordinate System Transformation

All calculations are performed in a normalized coordinate space and transformed to machine coordinates at generation time.

**Stock Coordinate System:**
- Origin at specified `originPosition`
- X+ to the right
- Y+ away from operator (into machine)
- Z+ upward

**Transformation Pipeline:**
1. Generate toolpath in stock coordinates (0,0 at origin position)
2. Apply pattern rotation if `patternAngle` != 0
3. Translate to current WCS position
4. Apply tool radius compensation
5. Generate G-code with absolute coordinates

### 3.2 Rectilinear Pattern

**Algorithm:**
```
Input: stockX, stockY, toolRadius, stepover, patternAngle, clearStockExit
Output: Array of toolpath points

1. Calculate effective cutting width = toolRadius * 2 * (stepover / 100)
2. Calculate number of passes = ceil(stockY / effective cutting width)
3. Compensate boundaries for tool radius:
   - If clearStockExit is true:
     - xMin = -(toolRadius * 2 + 1)  // Exit stock by full diameter + 1mm
     - xMax = stockX + (toolRadius * 2 + 1)
     - yMin = -(toolRadius * 2 + 1)
     - yMax = stockY + (toolRadius * 2 + 1)
   - If clearStockExit is false:
     - xMin = toolRadius  // Standard tool center compensation
     - xMax = stockX - toolRadius
     - yMin = toolRadius
     - yMax = stockY - toolRadius

4. For each pass i from 0 to numPasses:
   a. Calculate Y position = yMin + (i * effective cutting width)
   b. If Y > yMax, clamp to yMax
   c. If pass is even (i % 2 == 0):
      - Move from (xMin, Y) to (xMax, Y)
   d. If pass is odd:
      - Move from (xMax, Y) to (xMin, Y)
   e. Add retract move to Z safe height between passes if needed

5. Apply pattern rotation around stock center
6. Transform to WCS coordinates
```

**Optimization Considerations:**
- Minimize retracts by using continuous zigzag motion
- Maintain selected climb/conventional milling by adjusting toolpath direction based on spindle rotation
- Add lead-in/lead-out moves for smoother entry/exit
- When clearStockExit is true, ensure adequate clearance around stock
- Use rapid moves (G0) for moves outside stock boundary

### 3.3 Zigzag Pattern

The zigzag pattern is similar to rectilinear but ensures continuous motion without retracts between passes.

**Algorithm:**
```
Input: stockX, stockY, toolRadius, stepover, patternAngle
Output: Array of toolpath points

**Algorithm:**
```
Input: stockX, stockY, toolRadius, stepover, patternAngle, clearStockExit
Output: Array of toolpath points

1. Calculate effective cutting width = toolRadius * 2 * (stepover / 100)
2. Calculate number of passes = ceil(stockY / effective cutting width)
3. Compensate boundaries for tool radius:
   - If clearStockExit is true:
     - xMin = -(toolRadius * 2 + 1)
     - xMax = stockX + (toolRadius * 2 + 1)
     - yMin = -(toolRadius * 2 + 1)
     - yMax = stockY + (toolRadius * 2 + 1)
   - If clearStockExit is false:
     - xMin = toolRadius
     - xMax = stockX - toolRadius
     - yMin = toolRadius
     - yMax = stockY - toolRadius

4. Start at (xMin, yMin) - bottom left
5. For each pass i from 0 to numPasses:
   a. Calculate Y position = yMin + (i * effective cutting width)
   b. If Y > yMax, clamp to yMax
   c. If pass is even:
      - Cut from current X to xMax at Y
      - If not last pass, move to (xMax, Y + effective cutting width)
   d. If pass is odd:
      - Cut from current X to xMin at Y
      - If not last pass, move to (xMin, Y + effective cutting width)

6. Apply pattern rotation around stock center
7. Transform to WCS coordinates
```

**Key Differences from Rectilinear:**
- No Z retracts between passes
- Continuous helical or ramping motion
- Better for finishing operations
- More efficient for large areas
- When clearStockExit is true, step-over movements occur completely outside stock

### 3.4 Spiral Pattern

Spiral patterns work from outside to inside (or vice versa) in a continuous spiral motion.

**Algorithm (Outside-In):**
```
Input: stockX, stockY, toolRadius, stepover, patternAngle, spiralDirection, clearStockExit
Output: Array of toolpath points

1. Calculate effective cutting width = toolRadius * 2 * (stepover / 100)
2. Initialize boundary rectangle:
   - If clearStockExit is true:
     - xMin = -(toolRadius * 2 + 1)
     - xMax = stockX + (toolRadius * 2 + 1)
     - yMin = -(toolRadius * 2 + 1)
     - yMax = stockY + (toolRadius * 2 + 1)
   - If clearStockExit is false:
     - xMin = toolRadius
     - xMax = stockX - toolRadius
     - yMin = toolRadius
     - yMax = stockY - toolRadius

3. Current position = (xMin, yMin) - bottom left corner

4. While boundary rectangle has area > 0:
   a. Move right along bottom edge: (xMin, yMin) to (xMax, yMin)
   b. Move up along right edge: (xMax, yMin) to (xMax, yMax)
   c. Move left along top edge: (xMax, yMax) to (xMin, yMax)
   d. Move down along left edge: (xMin, yMax) to (xMin, yMin + effective cutting width)
   
   e. Shrink boundary inward by effective cutting width:
      - xMin += effective cutting width
      - xMax -= effective cutting width
      - yMin += effective cutting width
      - yMax -= effective cutting width
   
   f. If boundary invalid (xMin >= xMax or yMin >= yMax), break

5. For circular stock, clip toolpath to circular boundary
6. Apply pattern rotation
7. Transform to WCS coordinates
```

**Circular Stock Optimization:**
- Calculate spiral based on radius
- Use polar coordinates for generation
- Convert to Cartesian for G-code output
- Ensure smooth radius reduction per revolution
- When clearStockExit is true, start spiral outside stock diameter

### 3.5 Circular Stock Considerations

For circular stock, toolpaths must be clipped to stay within the circular boundary:

**Boundary Clipping:**
```
For each toolpath point (x, y):
1. Calculate distance from center: d = sqrt((x - centerX)^2 + (y - centerY)^2)
2. Calculate max radius: maxR = stockRadius - toolRadius
3. If d > maxR:
   a. Calculate angle: θ = atan2(y - centerY, x - centerX)
   b. Clip to boundary: 
      - x = centerX + maxR * cos(θ)
      - y = centerY + maxR * sin(θ)
```

### 3.6 Z Level Management

**Multi-Pass Depth Strategy:**
```
Input: totalDepth, stepdown, zOffset, safeZHeight, finishingPass, finishingPassHeight, finishingPassOffset
Output: Array of Z levels with retract heights

1. If finishingPass is enabled:
   a. Adjust roughing depth = totalDepth - finishingPassHeight
   b. Calculate number of roughing passes: numPasses = ceil(roughingDepth / stepdown)
   c. For each roughing pass i from 0 to numPasses:
      - Calculate Z depth = zOffset - min(i * stepdown, roughingDepth)
      - Calculate safe Z for this level = Z depth + safeZHeight (relative to cutting depth)
      - Generate XY toolpath at this Z level
      - Add lead-in at beginning of level
      - Add lead-out and retract to safe Z if not final roughing pass
   d. Generate finishing pass:
      - Z depth = zOffset - totalDepth (final depth)
      - Calculate safe Z = Z depth + safeZHeight
      - Generate XY toolpath at finishing depth with finishingPassOffset applied
      - Apply offset: shift all XY coordinates by finishingPassOffset (inward/outward)
      - Use same pattern as roughing but potentially different feed rate

2. If finishingPass is disabled:
   a. Calculate number of Z passes: numPasses = ceil(totalDepth / stepdown)
   b. For each pass i from 0 to numPasses:
      - Calculate Z depth = zOffset - min(i * stepdown, totalDepth)
      - Calculate safe Z for this level = Z depth + safeZHeight (relative to cutting depth)
      - Generate XY toolpath at this Z level
      - Add lead-in at beginning of level
      - Add lead-out and retract to safe Z if not final pass
```

**Safe Z Height Behavior:**
- Safe Z is calculated relative to current cutting depth: `safeZ = currentCuttingZ + safeZHeight`
- As tool steps down, retract height lowers proportionally
- Example with 5mm safe height:
  - Pass 1 at Z=-1mm: Retract to Z=-1+5 = +4mm
  - Pass 2 at Z=-2mm: Retract to Z=-2+5 = +3mm
  - Pass 3 at Z=-3mm: Retract to Z=-3+5 = +2mm
- Avoids unnecessary large retractions when cutting deep
- Maintains constant clearance above cutting surface

**Plunge Strategies:**
- **Ramp Entry (over stock):** Linear or helical ramp into material when starting position is over stock
- **Direct Plunge (at edge):** Rapid to Z safe height, then rapid to cutting depth at feedRateZ when starting at stock edge
- **Preferred:** Ramp entry when possible for better tool life and finish; direct plunge when starting position is outside stock

---

## 4. G-code Generation

### 4.1 G-code Structure

**Header Section:**
```gcode
; NeXT Stock Preparation - Generated Facing Operation
; Stock: [Rectangular/Circular] [dimensions]
; Pattern: [pattern type] at [angle]°
; Tool: T[number] R[radius]mm
; Feed: XY=[feedRateXY] Z=[feedRateZ] mm/min
; Spindle: [spindleSpeed] RPM

G21 ; Metric units
G90 ; Absolute positioning
G94 ; Feed rate per minute
```

**Setup Section:**
```gcode
; Setup
G54 ; Use current WCS (or specified WCS)
T[currentTool] ; Confirm tool selection
M3.9 S[spindleSpeed] ; Start spindle with safety wrapper (handles acceleration wait)
```

**Positioning Section:**
```gcode
; Position to start
G0 Z[zOffset + safeZHeight] ; Move to safe height above stock top
G0 X[startX] Y[startY] ; Rapid to start position
```

**Cutting Section:**
For each roughing Z level:
```gcode
; Roughing Z Level [i]: [currentZ]mm (Safe Z: [currentZ + safeZHeight]mm)
G1 Z[currentZ] F[feedRateZ] ; Plunge to depth

; XY toolpath
G1 X[x1] Y[y1] F[feedRateXY]
G1 X[x2] Y[y2]
G1 X[x3] Y[y3]
; ... (all toolpath points)

G0 Z[currentZ + safeZHeight] ; Retract to safe height relative to current depth
```

**Finishing Pass Section (if enabled):**
```gcode
; Finishing Pass: [finalZ]mm (Safe Z: [finalZ + safeZHeight]mm)
; Offset: [finishingPassOffset]mm
G1 Z[finalZ] F[feedRateZ] ; Plunge to final depth

; XY toolpath (with offset applied if finishingPassOffset != 0)
G1 X[x1 + offset] Y[y1 + offset] F[feedRateXY]
G1 X[x2 + offset] Y[y2 + offset]
G1 X[x3 + offset] Y[y3 + offset]
; ... (all toolpath points with offset)

G0 Z[finalZ + safeZHeight] ; Retract to safe height
```

**Cleanup Section:**
```gcode
; Cleanup
G0 Z[zOffset + safeZHeight] ; Final retract to safe height above stock top
M5.9 ; Stop spindle with safety wrapper
G27 Z1 ; Park machine
; Program ends automatically at end of file
```

**Note on Safe Z Heights:**
- During cutting: Safe Z is relative to each cutting depth (currentZ + safeZHeight)
- At cleanup: Safe Z returns to stock top reference (zOffset + safeZHeight)
- Example with zOffset=0, safeZHeight=5mm:
  - Level 1 at Z=-1mm: Retract to -1+5 = +4mm
  - Level 2 at Z=-2mm: Retract to -2+5 = +3mm
  - Final cleanup: Retract to 0+5 = +5mm

### 4.2 Safety Features

**Pre-Operation Checks:**
- Verify all axes are homed
- Confirm tool is selected and radius is known
- Verify WCS is set and valid
- Check that stock dimensions fit within machine limits
- Validate all parameters are within safe ranges

**During Operation:**
- Use M3.9/M5.9 wrappers for spindle control (includes safety confirmations)
- Maintain minimum safe Z height between passes
- Avoid rapid moves while tool is in material
- Use appropriate feed rates for material type

**Post-Operation:**
- Always park machine (G27)
- Stop spindle before program end
- Provide completion confirmation via M291

### 4.3 G-code Optimization

**Efficiency Improvements:**
- Minimize Z retracts (use zigzag over rectilinear when possible)
- Combine adjacent collinear moves
- Remove redundant positioning moves
- Use G0 rapids for positioning, G1 for cutting
- Optimize move order to minimize travel distance

**Arc Support:**
For spiral patterns and circular stock:
- Use G2/G3 arc commands where beneficial
- Fall back to linear interpolation for complex curves
- Ensure arc center point accuracy

---

## 5. Visualization System

### 5.1 Rendering Technology Choice

**SVG Rendering (Recommended for Initial Implementation):**
- **Pros:**
  - Simple to implement
  - Good browser support
  - Easy debugging
  - Scales perfectly
  - Low overhead for moderate complexity
- **Cons:**
  - Performance degrades with very complex toolpaths (>10k points)
  - Limited 3D visualization

**WebGL/Three.js (Future Enhancement):**
- **Pros:**
  - Excellent performance for complex toolpaths
  - True 3D visualization
  - Can show multi-pass Z levels
  - Interactive rotation/zoom
- **Cons:**
  - More complex implementation
  - Larger dependency footprint
  - May require fallback for older browsers

**Initial Implementation:** SVG rendering with architecture designed to support WebGL upgrade in the future.

### 5.2 SVG Visualization Design

**Viewport Setup:**
- Aspect ratio matches stock dimensions
- Auto-scaling to fit available UI space
- Minimum size: 400x400px
- Maximum size: 800x600px (responsive)

**Visual Elements:**

**Stock Boundary:**
```svg
<rect x="0" y="0" width="[stockX]" height="[stockY]" 
      fill="none" stroke="#888888" stroke-width="2"/>
<!-- OR for circular: -->
<circle cx="[centerX]" cy="[centerY]" r="[radius]"
        fill="none" stroke="#888888" stroke-width="2"/>
```

**WCS Origin Indicator:**
```svg
<g id="origin">
  <line x1="-10" y1="0" x2="10" y2="0" stroke="red" stroke-width="1"/>
  <line x1="0" y1="-10" x2="0" y2="10" stroke="green" stroke-width="1"/>
  <circle cx="0" cy="0" r="3" fill="blue"/>
</g>
```

**Toolpath:**
```svg
<polyline points="[x1],[y1] [x2],[y2] [x3],[y3]..."
          fill="none" stroke="#2196F3" stroke-width="2"
          stroke-linecap="round" stroke-linejoin="round"/>
```

**Tool Indicator (current position during simulation):**
```svg
<circle cx="[currentX]" cy="[currentY]" r="[toolRadius]"
        fill="rgba(33, 150, 243, 0.3)" stroke="#2196F3" stroke-width="1"/>
```

### 5.3 Visualization Features

**Static Preview:**
- Display complete toolpath for one Z level
- Show tool boundary compensation
- Highlight start point (green) and end point (red)
- Show cutting direction with arrows at regular intervals

**Interactive Features:**
- Pan: Click and drag to move view
- Zoom: Scroll wheel or pinch to zoom in/out
- Reset view button to return to auto-fit
- Toggle grid overlay for dimension reference

**Animation (Optional Enhancement):**
- Play/pause button to animate tool movement
- Speed slider (1x to 10x)
- Progress indicator showing percentage complete
- Estimated time display

**Multi-Level View (Future):**
- Slider to select which Z level to display
- 3D isometric view showing all Z levels
- Color coding by Z depth

### 5.4 Real-time Update

**Reactive Rendering:**
```javascript
watch: {
  toolRadius: 'regenerateToolpath',
  stockX: 'regenerateToolpath',
  stockY: 'regenerateToolpath',
  stockShape: 'regenerateToolpath',
  facingPattern: 'regenerateToolpath',
  patternAngle: 'regenerateToolpath',
  millingDirection: 'regenerateToolpath',
  stepover: 'regenerateToolpath',
  safeZHeight: 'regenerateToolpath',
  clearStockExit: 'regenerateToolpath',
  finishingPass: 'regenerateToolpath',
  finishingPassHeight: 'regenerateToolpath',
  finishingPassOffset: 'regenerateToolpath'
},
methods: {
  regenerateToolpath() {
    // Debounce to avoid excessive recalculation
    clearTimeout(this.regenerateTimer);
    this.regenerateTimer = setTimeout(() => {
      this.toolpath = this.generateToolpath();
      this.renderSVG();
    }, 250);
  }
}
```

**Performance Optimization:**
- Debounce input changes (250ms delay)
- Only recalculate affected components
- Use requestAnimationFrame for smooth animation
- Limit point density for preview (can be full resolution for actual G-code)

---

## 6. UI/UX Design

### 6.1 Component Structure

**Main Component: `StockPreparationPanel.vue`**

Layout structure:
```
┌─────────────────────────────────────────────┐
│ Stock Preparation                           │
├─────────────────────────────────────────────┤
│ [Step 1: Setup] [Step 2: Preview & Run]    │
├─────────────────────────────────────────────┤
│                                             │
│  Step Content Area                          │
│                                             │
│                                             │
└─────────────────────────────────────────────┘
```

### 6.2 Step 1: Setup

**Section 1: Tool Configuration**
```
Tool Configuration
┌─────────────────────────────────────────┐
│ Current Tool: T1 - 6mm End Mill        │
│ Tool Radius: [6.0] mm                   │
│ [✓] Use current tool radius             │
└─────────────────────────────────────────┘
```

**Section 2: Stock Geometry**
```
Stock Geometry
┌─────────────────────────────────────────┐
│ Shape: ● Rectangular  ○ Circular        │
│                                         │
│ [If Rectangular:]                       │
│   X Dimension: [100.0] mm               │
│   Y Dimension: [75.0] mm                │
│   Origin Position: [Front Left ▼]      │
│                                         │
│ [If Circular:]                          │
│   Diameter: [100.0] mm                  │
│   ● Diameter  ○ Radius                  │
│   Origin: Center (fixed)                │
└─────────────────────────────────────────┘
```

**Section 3: Facing Pattern**
```
Facing Pattern
┌─────────────────────────────────────────┐
│ Pattern: [Zigzag ▼]                     │
│   Options: Rectilinear, Zigzag, Spiral  │
│ Angle: [0]° ═══●═══ [slider 0-360]     │
│                                         │
│ Milling: ● Climb  ○ Conventional        │
└─────────────────────────────────────────┘
```

**Section 4: Cutting Parameters**
```
Cutting Parameters
┌─────────────────────────────────────────┐
│ Stepover: [4.5] mm (75%) ═══●═══        │
│ Stepdown: [1.0] mm                      │
│ Total Depth: [2.0] mm                   │
│ Z Offset: [0.0] mm                      │
│ Safe Z Height: [5.0] mm                 │
│                                         │
│ [✓] Clear Stock Exit                    │
│     (Tool exits stock completely)       │
│                                         │
│ [✓] Finishing Pass                      │
│     Finishing Height: [0.2] mm          │
│     Finishing Offset: [0.0] mm          │
└─────────────────────────────────────────┘
```

**Section 5: Feed and Speed**
```
Feed and Speed
┌─────────────────────────────────────────┐
│ Horizontal Feed: [1000] mm/min          │
│ Vertical Feed: [300] mm/min             │
│ Spindle Speed: [10000] RPM              │
└─────────────────────────────────────────┘
```

**Action Buttons:**
```
┌─────────────────────────────────────────┐
│  [Generate Preview & G-code →]          │
└─────────────────────────────────────────┘
```

### 6.3 Step 2: Preview & Run

**Layout:**
```
┌─────────────────────────────────────────┐
│ Toolpath Preview                        │
├─────────────────────────────────────────┤
│                                         │
│       [SVG Visualization Area]          │
│                                         │
│                                         │
├─────────────────────────────────────────┤
│ Statistics:                             │
│   Roughing Passes: 10                   │
│   Finishing Pass: Yes (0.2mm)           │
│   Total Distance: 1,234.5 mm            │
│   Est. Time: 5 min 23 sec               │
│   Material Removed: 15.0 cm³            │
├─────────────────────────────────────────┤
│ View Controls:                          │
│ [Reset View] [Toggle Grid] [Zoom In]    │
│ [Zoom Out]                              │
│                                         │
│ Z Level: [1] ═══●═══ (of 2 levels)     │
├─────────────────────────────────────────┤
│ G-code Preview (expandable):            │
│ ▼ Show G-code (1,234 lines)            │
│ ┌─────────────────────────────────────┐ │
│ │ ; NeXT Stock Preparation           │ │
│ │ ; Stock: Rectangular 100x75mm      │ │
│ │ ; Pattern: Zigzag at 0°            │ │
│ │ G21                                │ │
│ │ G90                                │ │
│ │ M3.9 S10000                        │ │
│ │ ...                                │ │
│ │ [Scrollable code area]             │ │
│ └─────────────────────────────────────┘ │
├─────────────────────────────────────────┤
│ File Management:                        │
│ Filename: [stock-prep-001.gcode]        │
│ Save Location: [/gcodes/ ▼]            │
│                                         │
│ [💾 Save as File]  [▶ Run Immediately] │
└─────────────────────────────────────────┘
```

**Action Buttons:**
```
┌─────────────────────────────────────────┐
│ [← Back to Setup]         [Close Panel] │
└─────────────────────────────────────────┘
```

### 6.4 Validation and Error Handling

**Input Validation:**
- Real-time validation as user types
- Red border + error message for invalid values
- Disable "Generate Preview" until all inputs valid
- Show warning icon next to problematic fields

**Error Messages:**
```
⚠ Tool radius exceeds stock dimensions
⚠ Stepover must be less than tool diameter  
⚠ Total depth must be positive
⚠ Feed rate below recommended minimum (500 mm/min)
⚠ Spindle speed above maximum (check your machine)
⚠ Finishing pass height must be less than stepdown value
⚠ Finishing pass height must be less than total depth
```

**Warnings (non-blocking):**
```
ℹ No tool selected - using manual radius
ℹ Pattern angle is not a multiple of 45°
ℹ High stepdown may cause excessive tool load
ℹ Consider reducing spindle speed for harder materials
ℹ Clear Stock Exit enabled - verify adequate clearance around stock
ℹ Clear Stock Exit may increase cycle time significantly
ℹ Finishing pass enabled - cycle time will increase
ℹ Finishing pass removes only [X]mm - consider adjusting height
ℹ Safe Z height is relative to cutting depth - retracts lower as tool steps down
```

### 6.5 Responsive Design

**Note:** Follow Duet Web Control's Vuetify breakpoints for consistency with the existing UI.

**Vuetify Breakpoints (DWC Standard):**
- **xs:** <600px (extra small / mobile)
- **sm:** 600px - 960px (small / tablet portrait)
- **md:** 960px - 1264px (medium / tablet landscape)
- **lg:** 1264px - 1904px (large / desktop)
- **xl:** >1904px (extra large / wide desktop)

**Large Screens (lg and up: ≥1264px):**
- Side-by-side layout: Setup on left, Preview on right
- Full-sized visualization
- All controls visible simultaneously
- G-code preview collapsible to save space

**Medium Screens (md: 960px - 1264px):**
- Two-step interface (tabs/buttons to switch between steps)
- Visualization scales proportionally
- Collapsed control groups with expand/collapse
- G-code preview collapsed by default

**Small Screens (sm and down: <960px):**
- Fully stacked vertical layout
- Visualization scales to screen width
- Simplified controls with essential parameters only
- "Advanced" section for additional parameters
- G-code preview hidden by default with show/hide button

---

## 7. Implementation Components

### 7.1: Backend - Toolpath Generation

**Tasks:**
1. Create toolpath generation utilities in `ui/src/utils/toolpath.ts`
2. Implement rectilinear pattern generator
3. Implement zigzag pattern generator
4. Implement spiral pattern generator
5. Create coordinate transformation functions
6. Add circular stock boundary clipping
7. Implement Z level management
8. Add comprehensive unit tests for algorithms

**Deliverables:**
- `toolpath.ts` with all generation functions
- `toolpath.test.ts` with test coverage
- Documentation of algorithm implementations

### 7.2: UI Component - Basic Structure

**Tasks:**
1. Create `StockPreparationPanel.vue` component
2. Implement two-step interface structure (Setup and Preview/Run steps)
3. Create Setup step with all input fields
4. Add form validation logic
5. Integrate with NeXT store for current tool/WCS
6. Add input field change handlers
7. Create computed properties for validation state

**Deliverables:**
- Working Setup step with all inputs
- Validation feedback system
- Integration with machine state

### 7.3: Visualization - SVG Rendering

**Tasks:**
1. Create `ToolpathPreview.vue` component
2. Implement SVG viewport with auto-scaling
3. Add stock boundary rendering
4. Add toolpath rendering
5. Implement WCS origin indicator
6. Add zoom and pan controls
7. Create reset view functionality
8. Add grid overlay toggle
9. Integrate G-code preview with collapsible display

**Deliverables:**
- Working Preview & Run step with SVG visualization
- Interactive view controls
- Responsive scaling
- Collapsible G-code display

### 7.4: G-code Generation

**Tasks:**
1. Create G-code generator in `ui/src/utils/gcode.ts`
2. Implement header/footer generation
3. Add setup section generation
4. Implement cutting move generation from toolpath
5. Add Z level iteration logic
6. Implement lead-in/lead-out moves
7. Add safety features (M3.9/M5.9 wrappers)
8. Create G-code preview component

**Deliverables:**
- `gcode.ts` generator utility
- G-code preview display
- Complete G-code output with safety features

### 7.5: File Management & Execution

**Tasks:**
1. Integrate with RRF file upload API
2. Add filename input and validation
3. Implement "Save as File" functionality
4. Implement "Run Immediately" functionality
5. Add error handling for file operations
6. Echo completion message to DWC console log

**Note:** Progress tracking during execution is handled by RRF's job view - no separate progress indicator needed.

### 7.6: Testing & Refinement

**Tasks:**
1. End-to-end testing with real machine
2. Validate generated toolpaths
3. Test all pattern types and parameters
4. Verify G-code safety features
5. Performance testing with complex toolpaths
6. UI/UX refinement based on user feedback
7. Documentation updates

**Deliverables:**
- Tested, production-ready feature
- Updated documentation
- User guide additions

---

## 8. Future Enhancements

### Future Enhancements

**Advanced Toolpath Features:**
- Multiple tools support (roughing + finishing passes with different tools)
- Adaptive stepover based on remaining material
- Rest machining for areas missed by previous tool

**Material Database:**
- Material type selection (aluminum, steel, plastic, wood, etc.)
- Automatic feed and speed calculation
- Tool coating consideration (uncoated, TiN, TiAlN, etc.)
- Number of flutes input
- Chip load calculation and recommendation

**Advanced Patterns:**
- Trochoidal milling for difficult materials
- Adaptive clearing strategies

**Measurement Integration:**
- Auto-detect stock dimensions using probing
- Verify stock placement before operation
- Post-operation verification (measure result)
- Report actual material removed

**Advanced G-code Options:**
- High-speed machining (G5 or G5.1 for smoothing)
- Dynamic feed rate adjustment
- Corner rounding control
- Arc fitting for smoother motion
- Lookahead optimization hints

---

## 9. Technical Considerations

### 9.1 Performance

**Target Performance:**
- Toolpath generation: <500ms for typical operations
- SVG rendering: <200ms for toolpaths up to 5000 points
- UI responsiveness: 60fps during input changes
- G-code generation: <1000ms for complete program

**Optimization Strategies:**
- Implement progressive rendering for complex toolpaths
- Cache computed toolpaths until parameters change
- Use virtual scrolling for long G-code preview
- Debounce input changes to reduce recalculation

**Note on Web Workers:** Only consider if DWC already uses them for heavy computation. Otherwise, keep toolpath generation in the UI thread for simplicity.

### 9.2 Memory Constraints

**Typical Toolpath Complexity:**
- Simple facing: ~500-2000 points
- Complex multi-level: ~10,000-50,000 points
- Memory per point: ~40 bytes (x, y, z, feed, type)
- Total memory: 400KB - 2MB (acceptable)

**Memory Management:**
- Release previous toolpath when generating new
- Use typed arrays for point storage (Float32Array)
- Implement toolpath simplification for preview
- Full resolution only for final G-code generation

### 9.3 Browser Compatibility

**Minimum Requirements:**
- ES6 support (Chrome 51+, Firefox 54+, Safari 10+, Edge 15+)
- SVG 1.1 support (all modern browsers)
- Web Workers (for performance)
- File API (for G-code download)

**Fallback Strategies:**
- Detect Web Worker support, fallback to main thread
- SVG preferred, Canvas fallback if needed
- Progressive enhancement for advanced features

### 9.4 Integration Points

**NeXT Backend Integration:**
- Read current tool from `global.nxtCurrentTool`
- Read tool radius from `global.nxtToolRadius[nxtCurrentTool]` (indexed vector)
- **Note:** RRF does not store tool radius. NeXT uses `global.nxtToolRadius` vector to track tool radius for each tool
- **Example:** `set global.nxtToolRadius[state.currentTool] = radius`
- Read active WCS from `move.workplaceNumber`
- Read spindle configuration from `spindles[global.nxtSpindleID]`
- Read axis feed rate limits from `move.axes[].maxFeedrate`
- Send G-code via `store.dispatch('machine/sendCode', code)`
- Save files via RRF HTTP API: `rr_upload`

**Object Model Queries:**
```javascript
// Get current tool and radius from NeXT tool radius vector
const currentToolNum = this.$store.state.machine.model.global.nxtCurrentTool;
const toolRadiusVector = this.$store.state.machine.model.global.nxtToolRadius;
const toolRadius = toolRadiusVector && toolRadiusVector[currentToolNum] 
  ? toolRadiusVector[currentToolNum]
  : null;

// Get spindle min/max speeds
const spindleId = this.$store.state.machine.model.global.nxtSpindleID;
const spindle = this.$store.state.machine.model.spindles[spindleId];
const minSpeed = spindle.min || 0;
const maxSpeed = spindle.max || 30000;

// Get axis feed rate limits
const axes = this.$store.state.machine.model.move.axes;
const maxFeedXY = Math.min(axes[0].maxFeedrate, axes[1].maxFeedrate);
const maxFeedZ = axes[2].maxFeedrate;

// Get spindle rotation direction
const spindleDirection = spindle.current < 0 ? 'CCW' : 'CW';
```

**Store Integration:**
```javascript
computed: {
  currentTool() {
    return this.$store.state.machine.model.tools[this.nxtCurrentTool];
  },
  toolRadius() {
    return this.currentTool?.offsets[0] / 2 || 0;
  },
  activeWCS() {
    return this.$store.state.machine.model.move.workplaceNumber;
  }
}
```

**File Upload:**
```javascript
async saveGCodeFile(filename, gcode) {
  const formData = new FormData();
  const blob = new Blob([gcode], { type: 'text/plain' });
  formData.append('file', blob, filename);
  
  const response = await fetch(
    `/rr_upload?name=${encodeURIComponent(`/gcodes/${filename}`)}`,
    {
      method: 'POST',
      body: formData
    }
  );
  
  return response.ok;
}
```

---

## 10. Testing Strategy

### 10.1 Unit Tests

**Toolpath Generation:**
- Test each pattern type with known inputs
- Verify boundary compensation
- Validate coordinate transformations
- Test circular clipping
- Verify Z level calculations

**G-code Generation:**
- Verify correct command syntax
- Validate move sequences
- Check safety feature inclusion
- Test parameter substitution

### 10.2 Integration Tests

**UI Components:**
- Test input validation
- Verify reactive updates
- Test step navigation (Setup to Preview & Run)
- Validate error display

**File Operations:**
- Test file save success/failure
- Verify G-code upload
- Test immediate execution

### 10.3 End-to-End Tests

**Manual Testing Checklist:**
- [ ] Generate rectilinear pattern
- [ ] Generate zigzag pattern
- [ ] Generate spiral pattern
- [ ] Test with rectangular stock
- [ ] Test with circular stock
- [ ] Verify all origin positions
- [ ] Test pattern rotation (0°, 45°, 90°)
- [ ] Save G-code file
- [ ] Run G-code immediately
- [ ] Verify safety features trigger (M3.9/M5.9)
- [ ] Test with real machine (air cut)
- [ ] Test with real material (soft material first)

### 10.4 Validation Tests

**Toolpath Accuracy:**
- Measure actual stock dimensions after facing
- Verify surface flatness
- Check corner accuracy
- Validate material removal amount

**G-code Compliance:**
- Parse with G-code validator
- Verify syntax correctness
- Check coordinate limits
- Validate move sequences

---

## 11. Documentation Requirements

### 11.1 User Documentation

**Quick Start Guide:**
- How to access Stock Preparation panel
- Basic parameter setup
- Generating and previewing toolpaths
- Running a facing operation

**Parameter Reference:**
- Detailed explanation of each input
- Recommended values for common scenarios
- Pattern type comparison and selection guide
- Feed and speed guidelines

**Troubleshooting:**
- Common error messages and solutions
- Performance issues and fixes
- Visualization problems
- G-code execution issues

### 11.2 Developer Documentation

**Architecture Overview:**
- Component structure
- Data flow diagram
- Algorithm implementations
- Integration points

**API Reference:**
- Toolpath generation functions
- G-code generator API
- Component props and events
- Store integration methods

**Contributing Guide:**
- How to add new pattern types
- Testing requirements
- Code style guidelines
- Pull request process

---

## 12. Success Criteria

### Minimum Viable Product (MVP)

- [ ] All input fields functional with validation
- [ ] Rectilinear and zigzag patterns implemented
- [ ] SVG preview displays toolpath accurately
- [ ] G-code generation produces valid output
- [ ] File save functionality works
- [ ] Run immediately functionality works
- [ ] Safety features (M3.9/M5.9) included
- [ ] Basic error handling implemented
- [ ] Responsive UI works on desktop
- [ ] Documentation created

### Full Feature Set

- [ ] All three pattern types (rectilinear, zigzag, spiral)
- [ ] Both stock shapes (rectangular, circular)
- [ ] All origin positions supported
- [ ] Pattern rotation works correctly
- [ ] Interactive visualization (zoom, pan)
- [ ] Statistics display (time, distance, etc.)
- [ ] Multi-level Z preview
- [ ] Mobile-responsive design
- [ ] Comprehensive testing completed
- [ ] Performance targets met

### Quality Benchmarks

- [ ] Zero critical bugs
- [ ] All unit tests passing (>90% coverage)
- [ ] Integration tests passing
- [ ] End-to-end testing with real machine successful
- [ ] User feedback positive
- [ ] Documentation complete and clear
- [ ] Performance within targets
- [ ] Code review approved

---

## 13. Risk Assessment

### Technical Risks

**Toolpath Generation Complexity:**
- **Risk:** Algorithms may be more complex than anticipated
- **Mitigation:** Start with simple patterns, iterate to complex
- **Fallback:** Reduce pattern options in MVP

**Performance Issues:**
- **Risk:** Complex toolpaths may cause UI lag
- **Mitigation:** Use Web Workers, implement progressive rendering
- **Fallback:** Limit toolpath complexity, simplify preview

**Browser Compatibility:**
- **Risk:** Older browsers may not support required features
- **Mitigation:** Use polyfills, provide fallbacks
- **Fallback:** Require modern browser, document requirements

### Integration Risks

**RRF API Changes:**
- **Risk:** File upload API may change or be unavailable
- **Mitigation:** Abstract API calls, implement adapter pattern
- **Fallback:** Manual G-code copy/paste option

**Store State Management:**
- **Risk:** Machine state may not be available or accurate
- **Mitigation:** Validate all state reads, provide manual overrides
- **Fallback:** Manual input for all parameters

### User Experience Risks

**Complexity Overload:**
- **Risk:** Too many parameters may confuse users
- **Mitigation:** Provide presets, sane defaults, progressive disclosure
- **Fallback:** Simplified UI with "Advanced" section

**Preview Accuracy:**
- **Risk:** Preview may not match actual machine behavior
- **Mitigation:** Extensive testing, clear disclaimers
- **Fallback:** Provide warning about preview limitations

---

## Conclusion

The Stock Preparation UI represents a significant enhancement to NeXT, providing operators with a powerful, integrated tool for common facing operations. By following this comprehensive implementation approach, we can deliver a feature that is:

1. **User-Friendly:** Intuitive interface with visual feedback
2. **Powerful:** Flexible pattern types and parameter control
3. **Safe:** Integrated safety features and validation
4. **Performant:** Optimized for responsive UI and fast generation
5. **Extensible:** Architecture supports future enhancements

The detailed technical specifications provide clear guidance for development, while the success criteria and risk assessment help manage expectations and provide contingency plans.

This feature will significantly improve the NeXT user experience and reduce dependency on external CAM software for basic stock preparation operations.
