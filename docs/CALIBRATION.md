# nxt Machine Calibration Guide

This document describes the resilient steps-per-mm calibration system for nxt, designed to eliminate the circular dependency between steps-per-mm accuracy, backlash compensation, and touch probe deflection measurement.

---

## 1. The Calibration Challenge

When setting up a CNC machine, three measurement errors can affect machine accuracy:

1. **Steps-per-mm** - The fundamental relationship between motor steps and actual distance traveled
2. **Backlash** - Mechanical slack that causes position error when changing direction
3. **Touch Probe Deflection** - The distance the probe tip moves before triggering

These three error sources create a circular dependency problem:

- **Touch probe deflection** cannot be accurately measured unless steps-per-mm are correct and backlash is compensated
- **Backlash** cannot be accurately measured unless steps-per-mm and probe deflection are correct
- **Steps-per-mm** can be calibrated manually, but doing it with automated touch probe measurements requires accurate backlash compensation and probe deflection

This creates a "chicken and egg" problem where each measurement depends on the others being accurate.

---

## 2. Theoretical Foundation

### 2.1 Understanding Each Error Source

#### Steps-per-mm Error
- **Cause**: Incorrect firmware configuration, mechanical tolerances in drive components
- **Effect**: Machine moves wrong distance when commanded (e.g., commanded 100mm, actually moves 99.8mm or 100.2mm)
- **Characteristics**: Proportional error - larger moves have larger absolute errors

#### Backlash Error
- **Cause**: Mechanical slack in couplings, lead screws, ball screws, or linear guides
- **Effect**: Position error when changing direction, until slack is "taken up"
- **Characteristics**: Fixed magnitude per axis, independent of move distance

#### Probe Deflection Error
- **Cause**: Physical deflection of probe tip and stylus before electrical trigger
- **Effect**: Probe appears to trigger before/after actual contact point
- **Characteristics**: 
  - Generally consistent magnitude for similar approach speeds
  - May vary slightly based on probe angle and surface material
  - Opposite when probing from opposite directions (deflects away from surface)

### 2.2 Key Insight: Breaking the Circular Dependency

The solution lies in exploiting different mathematical properties of each error source:

1. **Steps-per-mm error is proportional**: The error scales with distance
   - If steps-per-mm is 1% high, a 100mm move travels 101mm
   - By measuring TWO different dimensions and taking their difference, constant offsets (backlash + deflection) cancel out
   - The ratio `(d2_measured - d1_measured) / (d2_actual - d1_actual)` reveals only the steps-per-mm error

2. **Backlash is directional and consistent**: It only appears when changing direction
   - Repeated measurements from alternating directions create a bimodal (two-cluster) distribution
   - The separation between clusters equals the backlash magnitude
   - Probe deflection affects both clusters equally (constant offset)
   - Statistical analysis isolates backlash from deflection

3. **Probe deflection is symmetrical and constant**: When probing opposite sides of an object
   - From negative direction (e.g., X-): probe deflects in +X before triggering
   - From positive direction (e.g., X+): probe deflects in -X before triggering  
   - The measured distance includes deflection on BOTH sides
   - For a known-size object: `measured size = actual size + 2 × deflection`
   - Once steps-per-mm and backlash are correct, deflection can be isolated

**The Calibration Sequence**:
```
Phase 1: Manual rough steps-per-mm (±1-2% accuracy sufficient)
         ↓
Phase 2: Dual-dimension steps-per-mm (cancels backlash + deflection)
         ↓  
Phase 3: Statistical backlash measurement (clusters reveal backlash)
         ↓
Phase 4: Direct deflection measurement (now isolated from other errors)
         ↓
Phase 5: Verification
```

**Note**: The order of Phase 2 and Phase 3 has been optimized - we measure precise steps-per-mm BEFORE backlash because the dual-dimension method works regardless of backlash presence, whereas backlash measurement benefits from accurate steps-per-mm.

---

## 3. Calibration Procedure

### 3.1 Prerequisites

**Required Equipment:**
- Touch probe (configured in nxt)
- Precision reference object with known dimensions:
  - **Recommended**: 1-2-3 block (1" × 2" × 3" = 25.4mm × 50.8mm × 76.2mm)
  - **Alternative**: Any precision ground rectangular block with known dimensions
  - **Minimum requirement**: Known dimensions accurate to ±0.01mm or better

**Initial State:**
- Machine must be mechanically assembled and motion system functional
- RRF firmware installed and basic axis configuration completed
- Approximate steps-per-mm values entered in firmware (even if incorrect)
- nxt system loaded
- Touch probe configured (ID, tip radius estimated, deflection can be zero initially)

### 3.2 Procedure Overview

The calibration follows a specific sequence to break the circular dependency:

```
Phase 1: Rough Steps-per-mm Calibration (Manual)
         ↓
Phase 2: Precise Steps-per-mm Calibration (Automated, Dual-Dimension)
         ↓
Phase 3: Backlash Measurement & Compensation (Statistical Drift Analysis)
         ↓
Phase 4: Probe Deflection Measurement
         ↓
Phase 5: Verification & Refinement
```

**Why This Order Works**:
- **Phase 1** gets steps-per-mm "close enough" (±1-2%) for probing to work reliably
- **Phase 2** achieves precise steps-per-mm (<0.1%) using dual-dimension method that mathematically cancels out backlash and deflection
- **Phase 3** uses statistical analysis with accurate steps-per-mm to isolate backlash from deflection
- **Phase 4** measures deflection now that both steps-per-mm and backlash are correct
- **Phase 5** verifies all calibrations are working together correctly

### 3.3 Phase 1: Rough Steps-per-mm Calibration (Manual)

**Goal**: Get steps-per-mm accurate to within ~1-2% using manual measurement.

**Procedure**:
1. Home the machine
2. Jog to a known position and zero the work coordinate system (WCS)
3. Command a large move (e.g., 100mm) in X axis: `G0 X100`
4. Using calipers or dial indicator, measure the *actual* distance traveled
5. Calculate corrected steps-per-mm:
   ```
   new_steps = current_steps × (commanded_distance / actual_distance)
   ```
6. Update firmware configuration (M92 command in config.g)
7. Restart firmware or reload configuration
8. Repeat for Y, Z, and any other axes
9. Verify: commanding 100mm should now result in 99-101mm actual movement

**Why This Works**:
- Manual measurement doesn't depend on probe deflection or backlash
- Gets steps-per-mm "close enough" for automated methods to work
- 1-2% accuracy is sufficient for the next phases

### 3.4 Phase 2: Precise Steps-per-mm Calibration (Automated, Dual-Dimension)

**Goal**: Achieve high-precision steps-per-mm calibration using automated touch probe measurements.

**Concept**:
With approximately correct steps-per-mm from Phase 1, we can now achieve precision calibration using the dual-dimension method. This method works even with uncalibrated backlash and unknown probe deflection because these constant errors mathematically cancel out when measuring two different dimensions and taking their difference.

**Mathematical Proof**:
Let:
- `d_actual` = actual dimension of reference object
- `d_measured` = measured dimension from probe
- `δ` = probe deflection (same magnitude on both sides)
- `b` = backlash (appears in measurements)
- `s_current` = current steps-per-mm setting
- `s_actual` = actual steps-per-mm (what we need to find)

When measuring a single dimension with all errors present:
```
d_measured = (s_current / s_actual) × d_actual + 2δ + b
```

But we can eliminate both δ and b by comparing two different dimensions:
```
d1_measured = (s_current / s_actual) × d1_actual + 2δ + b
d2_measured = (s_current / s_actual) × d2_actual + 2δ + b

Subtracting:
d2_measured - d1_measured = (s_current / s_actual) × (d2_actual - d1_actual)

Therefore:
s_actual = s_current × (d2_actual - d1_actual) / (d2_measured - d1_measured)
```

**Both deflection and backlash terms cancel out!** This is why we can calibrate steps-per-mm precisely without knowing these other error sources.

**Procedure for Each Axis (Example: X-axis with 1-2-3 block)**:

1. **Setup**:
   - Install touch probe
   - Secure 1-2-3 block on machine table with known dimension oriented along X-axis
   - For X-axis: use the 1" (25.4mm) and 2" (50.8mm) dimensions

2. **Measure First Dimension (25.4mm side)**:
   - Position probe above the center of the narrow side
   - Probe left surface: `G6512 X{left_target} I{nxtTouchProbeID}`
   - Record: `left1 = nxtLastProbeResult`
   - Move probe across the block
   - Probe right surface: `G6512 X{right_target} I{nxtTouchProbeID}`
   - Record: `right1 = nxtLastProbeResult`
   - Calculate: `measured1 = abs(right1 - left1)`

3. **Measure Second Dimension (50.8mm side)**:
   - Rotate block or reposition to measure the 50.8mm dimension
   - Probe left surface: `G6512 X{left_target} I{nxtTouchProbeID}`
   - Record: `left2 = nxtLastProbeResult`
   - Probe right surface: `G6512 X{right_target} I{nxtTouchProbeID}`
   - Record: `right2 = nxtLastProbeResult`
   - Calculate: `measured2 = abs(right2 - left2)`

4. **Calculate Corrected Steps-per-mm**:
   ```
   actual1 = 25.4  ; mm
   actual2 = 50.8  ; mm
   s_new = s_current × (actual2 - actual1) / (measured2 - measured1)
   ```
   
5. **Apply Correction**:
   - Update firmware: `M92 X{s_new}`
   - Add to config.g for persistence
   - Restart or reload configuration

6. **Verify**:
   - Re-measure both dimensions
   - Both should now read within ±0.02mm of actual dimensions

**Repeat for Y and Z axes** using the appropriate dimensions of the reference block.

**Why Use a 1-2-3 Block**:
The 1-2-3 block is ideal for this calibration because:
- Large dimension differences (25.4mm vs 50.8mm = 25.4mm span) provide better accuracy
- Precision ground surfaces (typically ±0.005mm tolerance)
- The 25.4mm difference in measurements amplifies steps-per-mm errors while canceling constant offsets
- Larger blocks reduce measurement uncertainty compared to gauge pins

**Alternative Single-Dimension Method**:
If probe deflection and backlash have already been measured accurately, a single dimension can be used:
```
s_new = s_current × d_actual / (d_measured - 2δ - b)
```
However, the two-dimension method is more robust as it doesn't require knowing deflection or backlash.

**Automation Implementation**:

This procedure can be fully automated via a G-code macro or UI component:

```gcode
; Macro: G9000 - Calibrate Steps-per-mm on X-axis
; Parameters: P<probe_id> X<block_center> D1<dimension1> D2<dimension2>

var probeID = { param.P }
var blockCenter = { param.X }
var dim1_actual = { param.D1 }  ; e.g., 25.4
var dim2_actual = { param.D2 }  ; e.g., 50.8

; Measure first dimension
G6512 X{var.blockCenter - var.dim1_actual/2 - 5} I{var.probeID}
var left1 = { global.nxtLastProbeResult }
G6512 X{var.blockCenter + var.dim1_actual/2 + 5} I{var.probeID}
var right1 = { global.nxtLastProbeResult }
var measured1 = { abs(var.right1 - var.left1) }

; Measure second dimension (block rotated/repositioned)
M291 P"Rotate block to measure " ^ var.dim2_actual ^ "mm dimension" S3
G6512 X{var.blockCenter - var.dim2_actual/2 - 5} I{var.probeID}
var left2 = { global.nxtLastProbeResult }
G6512 X{var.blockCenter + var.dim2_actual/2 + 5} I{var.probeID}
var right2 = { global.nxtLastProbeResult }
var measured2 = { abs(var.right2 - var.left2) }

; Calculate new steps-per-mm
var current_steps = { move.axes[0].stepsPerMm }
var new_steps = { var.current_steps * (var.dim2_actual - var.dim1_actual) / (var.measured2 - var.measured1) }

echo "Current steps/mm: " ^ var.current_steps
echo "Measured dim1: " ^ var.measured1 ^ "mm (actual: " ^ var.dim1_actual ^ "mm)"
echo "Measured dim2: " ^ var.measured2 ^ "mm (actual: " ^ var.dim2_actual ^ "mm)"
echo "Calculated steps/mm: " ^ var.new_steps

; Apply correction
M92 X{var.new_steps}
```

**UI Component Integration**:

A dedicated calibration wizard in the Settings panel would:
1. Guide user through block setup and measurement
2. Execute dual-dimension probing automatically
3. Display measured vs actual dimensions
4. Calculate and apply steps-per-mm correction
5. Verify correction with follow-up measurements
6. Show before/after accuracy comparison

### 3.5 Phase 3: Backlash Measurement & Compensation

**Goal**: Measure and compensate for mechanical backlash on each axis using statistical analysis of repeated probe measurements.

**Concept**:
With approximately correct steps-per-mm (from Phase 1), we can now isolate backlash from probe deflection using a "drift detection" technique. Backlash causes repeated measurements of the same feature to cluster into two distinct groups when alternating approach directions, while probe deflection remains constant. By analyzing this clustering pattern, we can measure backlash independently of deflection.

**Mathematical Foundation**:

When probing a feature with both backlash and deflection present:
- **From negative direction**: Measured position = actual + deflection + 0 (backlash taken up)
- **From positive direction**: Measured position = actual + deflection + backlash

The key insight: **Deflection is constant regardless of approach direction, but backlash only appears when reversing direction**. This creates a bimodal distribution in repeated measurements.

**Procedure for Each Axis (Example: X-axis)**:

1. **Setup**:
   - Install touch probe (T{nxtProbeToolID})
   - Secure 1-2-3 block on machine table with X-axis dimension accessible
   - Jog probe to approximately 20mm from the left surface of the block

2. **Repeated Probing with Alternating Directions**:
   
   For 10 iterations (i = 0 to 9):
   ```
   ; Approach from negative (left) - odd iterations
   if (i % 2 == 1)
       ; Start well to the left
       G0 X{left_surface - 20}
       ; Probe towards right
       G6512 X{left_surface + 5} I{nxtTouchProbeID}
       
   ; Approach from positive (right) - even iterations  
   else
       ; Start well to the right
       G0 X{left_surface + 20}
       ; Probe towards left
       G6512 X{left_surface + 5} I{nxtTouchProbeID}
   
   ; Record result
   results[i] = global.nxtLastProbeResult
   ```

3. **Statistical Analysis**:
   
   Separate measurements by approach direction:
   ```
   negative_approaches = [results[1], results[3], results[5], results[7], results[9]]
   positive_approaches = [results[0], results[2], results[4], results[6], results[8]]
   
   mean_negative = average(negative_approaches)
   mean_positive = average(positive_approaches)
   
   backlash = abs(mean_positive - mean_negative)
   ```
   
   **Why this works:**
   - Measurements from the same direction cluster together
   - The separation between clusters IS the backlash
   - Probe deflection affects both clusters equally (adds same offset to both)
   - Steps-per-mm error affects positioning but not the cluster separation

4. **Validation**:
   
   Check measurement quality:
   ```
   std_dev_negative = standard_deviation(negative_approaches)
   std_dev_positive = standard_deviation(positive_approaches)
   
   ; Each cluster should have low scatter (< 0.005mm)
   if (std_dev_negative > 0.005 || std_dev_positive > 0.005)
       ; Warning: High scatter indicates mechanical issues or probe problems
   ```

5. **Apply Compensation**:
   - In RRF firmware, use M425 to configure backlash compensation
   - Example: `M425 X{backlash} Y{backlash_y} Z{backlash_z}`
   - Add this to config.g for persistence

6. **Verify Compensation**:
   - Repeat the 10-probe procedure
   - All measurements should now cluster into a single group
   - Standard deviation of all 10 measurements should be < 0.005mm
   - If measurements still cluster into two groups, increase backlash compensation

**Repeat for Y and Z axes** using appropriate surfaces of the reference block.

**Automation Implementation**:

This procedure can be fully automated via a G-code macro or UI component:

```gcode
; Macro: G9100 - Measure Backlash on X-axis
; Parameters: P<probe_id> X<surface_position> [N<iterations>]

var probeID = { param.P }
var surface = { param.X }
var iterations = { exists(param.N) ? param.N : 10 }

var results = vector(iterations, null)
var i = 0

while { i < iterations }
    ; Alternate approach direction
    if { i % 2 == 1 }
        ; Approach from negative
        G0 X{var.surface - 20}
        G6512 X{var.surface + 5} I{var.probeID}
    else
        ; Approach from positive  
        G0 X{var.surface + 20}
        G6512 X{var.surface + 5} I{var.probeID}
    
    set var.results[i] = { global.nxtLastProbeResult }
    set i = { i + 1 }

; Calculate means and backlash
; (Statistical analysis code here)

echo "Measured backlash: " ^ var.backlash ^ "mm"
```

**UI Component Integration**:

A dedicated calibration wizard in the Settings panel would:
1. Guide user through block setup
2. Execute the repeated probing automatically
3. Display real-time scatter plot showing clustering
4. Calculate and apply backlash compensation
5. Verify compensation with follow-up test
6. Show before/after visualization of measurement scatter

### 3.6 Phase 4: Probe Deflection Measurement

**Goal**: Accurately measure touch probe deflection now that steps-per-mm and backlash are correct.

**Procedure for Each Axis (Example: X-axis)**:

1. **Setup**:
   - Install touch probe
   - Secure reference block with known dimension along X-axis (e.g., 25.4mm)

2. **Measure Dimension**:
   - Probe left surface: `G6512 X{left_target} I{nxtTouchProbeID}`
   - Record: `left = nxtLastProbeResult`
   - Probe right surface: `G6512 X{right_target} I{nxtTouchProbeID}`
   - Record: `right = nxtLastProbeResult`
   - Calculate: `measured = abs(right - left)`

3. **Calculate Deflection**:
   ```
   total_error = measured - actual_dimension
   deflection = total_error / 2
   ```
   
   Example:
   ```
   measured = 25.45mm
   actual = 25.40mm
   deflection = (25.45 - 25.40) / 2 = 0.025mm
   ```

4. **Update nxt Configuration**:
   - Set `global.nxtProbeDeflection = {calculated_deflection}`
   - Add to nxt-user-vars.g for persistence

5. **Verify**:
   - Re-measure the reference dimension
   - The probing macro (G6512) will now apply deflection compensation
   - Result should be within ±0.01mm of actual dimension

**Repeat for Y and Z axes**. Note that deflection may differ between axes due to probe geometry and mounting.

### 3.7 Phase 5: Verification & Refinement

**Goal**: Verify all calibrations are working together correctly.

**Procedure**:

1. **Dimensional Verification**:
   - Measure multiple features on the reference block using probing cycles
   - All measurements should be within ±0.02mm of actual dimensions
   - Test different feature sizes to verify proportional accuracy

2. **Backlash Verification**:
   - Probe the same surface from opposite directions multiple times
   - Position difference should be < 0.01mm
   - If larger, backlash compensation may need adjustment

3. **Repeatability Test**:
   - Probe the same feature 10 times without moving the part
   - On a nxt machine with touch probe or toolsetter configured, run **`M6523`** (e.g. `M6523 B0 C10` at the touch reference, or `M6523 B1 C10` at the toolsetter) — see [GCODE.md](../GCODE.md) and `macros/utilities/M6523.g`
   - Review echoed min / max / **range** / mean; range should be **< 0.005 mm** for a good setup
   - Tune pair tolerance via `nxt-user-overrides.g` or Configuration repeatability notes if range exceeds `L`

4. **Directional Test**:
   - Probe surfaces from both positive and negative approach directions
   - Measurements should be consistent within ±0.01mm
   - Verifies both backlash compensation and deflection compensation

5. **Real-World Verification**:
   - Create a simple test part with known dimensions (e.g., rectangular pocket)
   - Machine the part and measure with calibrated touch probe
   - Measurement should match CAD dimensions within machine capability

**Refinement**:
If verification reveals errors:
- **Proportional errors**: Revisit steps-per-mm calibration
- **Directional inconsistency**: Check backlash compensation
- **Fixed offset on all measurements**: Verify probe deflection value
- **Large scatter in repeated measurements**: Check mechanical issues (loose probe, spindle runout, etc.)

---

## 4. Implementation in nxt

### 4.1 Implementation Approach

Two implementation approaches are possible:

#### Option A: UI-Based Calibration Wizard (Recommended)
- **Advantages**:
  - User-friendly step-by-step workflow
  - Visual feedback and progress indication
  - Can show real-time measurements and calculations
  - Easier to guide user through complex procedure
  - Can validate measurements and provide warnings

- **Implementation**:
  - Add calibration wizard to Settings panel in UI
  - UI guides user through each phase with instructions
  - UI sends probe commands and receives results
  - Calculations performed in UI JavaScript
  - Final values written to nxt-user-vars.g via M-code

#### Option B: G-code Macro Based (Alternative)
- **Advantages**:
  - Works without UI
  - Self-contained in macro system
  - Can be triggered from any G-code sender

- **Implementation**:
  - Create G-code macro (e.g., G6599 or M9000)
  - Uses M291 dialogs for user interaction
  - Prompts for reference block dimensions
  - Executes probe commands and calculations
  - Updates nxt-user-vars.g with results

### 4.2 Recommended Workflow Integration

**In Configuration/Settings UI:**

1. **Calibration Section**:
   - Button: "Run Machine Calibration"
   - Displays current calibration status (steps-per-mm, backlash, deflection values)
   - Shows last calibration date

2. **Calibration Wizard Flow**:
   ```
   Step 1: Welcome & Prerequisites Check
            - Verify machine is homed
            - Verify touch probe is configured
            - Prompt for reference block dimensions
            
   Step 2: Rough Steps-per-mm (Manual)
            - Instructions for manual measurement
            - Input fields for measured distances
            - Calculate and apply corrections
            
   Step 3: Precise Steps-per-mm (Automated)
            - For each axis:
              * Probe two different dimensions
              * Calculate correction
              * Apply M92 adjustment
              
   Step 4: Backlash Measurement
            - For each axis:
              * Auto-probe from both directions
              * Calculate backlash
              * Apply M425 compensation
              
   Step 5: Probe Deflection
            - For each axis:
              * Probe known dimension
              * Calculate deflection
              * Update nxtProbeDeflection
              
   Step 6: Verification & Report
            - Run verification tests
            - Display results and accuracy metrics
            - Save calibration data
   ```

3. **Calibration Results Storage**:
   - Append to user-config.g for persistence:
     ```gcode
     ; Machine Calibration Data
     ; Last calibrated: 2024-01-15 14:32:00
     
     ; Steps per mm
     M92 X100.234 Y99.876 Z400.123
     
     ; Backlash compensation
     M425 X0.05 Y0.08 Z0.02
     
     ; Probe deflection (mm)
     global nxtProbeDeflection = 0.025
     ```

### 4.3 API Requirements

**Backend Macros Needed**:
- Existing `G6512` (single-axis probe) - already implemented ✓
- Existing `M5000` (machine position query) - already implemented ✓

**UI Integration Points**:
- Read current calibration values from object model (move.axes[].stepsPerMm, move.axes[].backlash)
- Execute probe commands via G-code
- Update firmware parameters via standard M-codes (M92 for steps-per-mm, M425 for backlash)
- Append calibration results to user-config.g file

### 4.4 Error Handling

**Common Issues & Solutions**:

1. **Probe Fails to Trigger**:
   - Check probe mounting and electrical connection
   - Verify probe ID is correct in configuration
   - Ensure target position is beyond the expected surface

2. **Measurements Inconsistent**:
   - Check mechanical rigidity (loose parts, worn bearings)
   - Verify reference block is properly secured
   - Ensure work surface is clean and free of debris
   - Check for spindle/probe holder runout

3. **Calculated Values Unreasonable**:
   - Verify reference block dimensions entered correctly
   - Check that probe is approaching from correct directions
   - Ensure machine is homed properly before starting

4. **Compensation Makes Things Worse**:
   - May indicate mechanical problems (binding, friction)
   - Steps-per-mm may be drastically wrong (>5% error)
   - Recommend manual verification before accepting values

**Safety Checks**:
- Limit maximum adjustment per iteration (e.g., ±5% steps-per-mm change)
- Require operator confirmation before applying changes
- Store backup of previous values
- Provide rollback option if results are poor

---

## 5. Expected Accuracy

With proper calibration following this procedure, the machine should achieve:

- **Steps-per-mm accuracy**: < 0.1% (±0.1mm per 100mm of travel)
- **Backlash compensation**: < 0.01mm residual error
- **Probe deflection compensation**: < 0.01mm residual error
- **Overall probing accuracy**: ±0.02mm for features > 10mm
- **Repeatability**: < 0.005mm standard deviation

These accuracies assume:
- Reasonable mechanical quality (hobby CNC or better)
- Proper machine assembly and tramming
- Quality touch probe (±0.01mm repeatability)
- Precision reference block (±0.01mm tolerance)

---

## 6. Roadmap Integration

This calibration system should be implemented in **Phase 4** of the nxt development roadmap.

**Justification**:
- Requires stable probing engine (Phase 1) ✓
- Requires UI framework for wizard (Phase 2)
- Benefits from probe results management (Phase 3)
- Enhances overall system accuracy for advanced features

**Phase 4 Addition**:
```markdown
## Phase 4: Tool Change & Advanced Features

...existing items...

4. **Machine Calibration System:**
   * Implement UI-based calibration wizard in Settings panel
   * Create M-code macros for querying and updating calibration parameters
   * Implement automated steps-per-mm calibration using dual-dimension method
   * Implement automated backlash measurement and compensation
   * Implement automated probe deflection measurement
   * Add calibration verification and reporting
   * Document calibration procedure and best practices
```

---

## DWC Calibration tab (shipped on v0.6.0)

The nxt plugin **Calibration** tab (`CalibrationPanel.vue`) implements the phased workflow described in this document:

| Mode | UI flow | Macros |
|------|---------|--------|
| **Manual** | Phases 1–5 with dial-indicator steps | **M5014**, **M5015**, **M6523** |
| **Probe** | Automated travel legs on selected axis | **G9000**, **M5015**, **M6523** |

**Maintenance** counters and **M5013** thresholds live on the separate **Maintenance** tab. Configuration for platform (`v1.6` / `v2.0` / `custom`), probe references, and OM budget callouts are on the **Configuration** tab — see [CONFIGURATION_UI.md](CONFIGURATION_UI.md).

On the **v0.6.0** line, keep serialized `global` OM under **~5 KiB** when using calibration vectors; disable unused features if boot is tight on CDYv3 — [OM_GLOBAL_SIZE.md](OM_GLOBAL_SIZE.md).

---

## 7. References

### Related Documentation
- `docs/CODE.md` - nxt coding standards and conventions
- `docs/FEATURES.md` - Feature requirements and implementation status
- `docs/ROADMAP.md` - Development phases and timeline
- `GCODE.md` - Custom G-code and M-code reference

### RRF Firmware Commands
- `M92` - Set steps per mm
- `M425` - Backlash compensation
- `G38.2` - Probe toward workpiece (used by G6512)
- Object Model: `move.axes[].stepsPerMm` - Query current settings

### External Resources
- RepRapFirmware Object Model Documentation
- Touch Probe Selection and Setup Guide
- CNC Machine Tramming and Alignment Procedures

---

## Appendix A: Quick Reference

### Calibration Sequence Summary
```
1. Manual rough steps-per-mm → Get within 1-2%
2. Automated precise steps-per-mm → Use dual-dimension method
3. Probe backlash → Measure & compensate via statistical drift
4. Probe deflection → Measure with known object
5. Verify → Test accuracy and repeatability
```

### Key Formulas

**Steps-per-mm Correction (Manual)**:
```
new_steps = current_steps × (commanded / actual_measured)
```

**Steps-per-mm Correction (Automated)**:
```
new_steps = current_steps × (d2_actual - d1_actual) / (d2_measured - d1_measured)
```

**Probe Deflection**:
```
deflection = (measured_dimension - actual_dimension) / 2
```

**Backlash**:
```
backlash = abs(probe_result_positive - probe_result_negative)
```

### Reference Block Dimensions (1-2-3 Block)
- Side 1: 1 inch = 25.4 mm
- Side 2: 2 inches = 50.8 mm  
- Side 3: 3 inches = 76.2 mm
- Typical tolerance: ±0.0002 inches (±0.005 mm) or better

---

*Last Updated: 2024-01-15*
*Document Version: 1.0*
