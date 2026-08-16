# nxt Tool Setting and Offsetting Workflow

This document outlines the complete tool setting and Z-offsetting workflow for nxt. It combines a **Static Datum** (calibrated once) for machine geometry with a **Relative Offsetting** (with caching) approach for tool changes to ensure accuracy, efficiency, and ease of use.

---

## 1. Core Principles

- **Static Datum:** The physical Z-distance between the toolsetter's activation plane and a designated reference surface is measured once during setup and stored permanently as `nxtDeltaMachine`. This provides a stable, geometric foundation for all Z-height calculations.
- **Relative Offsetting:** All tool-to-tool offset calculations are *relative*. The system calculates the difference in measured length between the old tool and the new tool and applies that difference to the running tool offset.
- **Session Caching:** To improve efficiency, the measured Z-activation point of a tool is cached for the duration of a power-on session. This avoids redundant measurements during subsequent tool changes.
- **Explicit Workflows:** The system handles common scenarios (probe-to-cutter, cutter-to-cutter) automatically and provides a safe, explicit path for edge cases like starting with an unmeasured tool.

---

## 2. Phase 1: One-Time Static Datum Calibration

This process is performed once via the **Calibration** tab (Phase 0 → `M5016`, then park + load probe tool) to establish the machine's core geometry. It is only re-run if the toolsetter or reference surface is physically moved. See [CALIBRATION.md](CALIBRATION.md) §4 for the UI path and probe-mode calibration (`G9000`).

1.  **Install Datum Tool:** The user installs a rigid, known-geometry datum tool (e.g., a gauge pin).
2.  **Verify Toolsetter Input:** `M5016` requires `nxtToolSetterID` from Configuration, asks the operator to press and hold the platen, and confirms that configured probe input is active.
3.  **Measure Toolsetter:** Jog XY over the platen with ~20 mm Z clearance; `M5016` probes down 20 mm (or until trigger) for `Z_act_datum` / `nxtToolSetterPos`.
4.  **Measure Reference Surface:**
    - **V1 (default):** The user manually jogs the datum tool onto the designated flat reference surface (mill **paper-touch**, not a probe trigger) to get `Z_ref_datum` (and XY).
    - **V2.0** (`nxtToolSetterV2`): Configuration sets the ref-pad side of the platen (`nxtToolSetterRefDir`: +X / −X / +Y / −Y). After probing `Z_act`, M5016 places `nxtTouchProbeRefPos` at **±13 mm** from the platen center in that direction and **`Z_ref = Z_act − 6`** (no second jog). Then `nxtDeltaMachine = −6`.
5.  **Store Static Datum:** The system calculates and permanently saves:
    `nxtDeltaMachine = Z_ref_datum - Z_act_datum`
6.  **Load touch probe:** Park (`G27`), install probe, `T{nxtProbeToolID}`. Probe `tpost` zeros incoming L1 then **`G6511 R1 S0`** at **`nxtTouchProbeRefPos`** (reference surface, not the setter pad). Fast find seeks **`nxtToolSetterProbeTravelMm`** (default 80 mm) past mill-touch Z so a shorter probe still triggers. Mill virtual = `meanZ − nxtDeltaMachine`. **Save** writes setter/ref/delta (and finite virtual) to `nxt-user-vars.g`.

### UI Babystepping

To account for minor physical changes or thermal drift over time, the UI will provide a "babystepping" function. This will allow the operator to apply small, persistent adjustments (e.g., +/- 0.01mm) to the stored `nxtDeltaMachine` value without needing to perform a full recalibration.

---

## 3. Phase 2: In-Job Tool & Origin Management

This section describes the workflows an operator will encounter during a typical job.

### Scenario A: Initial WCS Z-Origin Setup (with Touch Probe)

This is the standard and recommended way to start a job.

1.  The operator installs the **touch probe**.
2.  From the UI, they initiate a "Probe Z" cycle on the workpiece.
3.  The probe touches the workpiece, recording the trigger coordinate `Z_wcs_trigger`.
4.  The system sets the WCS Z-origin to this trigger in machine coords (`G10 L2 P(wcs) Z{Z_wcs_trigger}`), or equivalently `G10 L20 P(wcs) Z0` **while still at the trigger**. It internally sets the probe's current tool offset to `0`. **`G10 L20 … Z{trigger}`** would treat the trigger as a *work* value, not a machine height.

*Result: The machine's coordinate system is now defined such that the tip of the triggered probe is at Z=0 in the active WCS.*

### Scenario B: First Tool Change (Probe -> Cutter)

Every probe install (`T{nxtProbeToolID}`) **`G6511 R1`** on the **saved reference surface** (`nxtTouchProbeRefPos`) and keeps the probe **`G10 L1 Z0`**. Mills then `G10 L1` vs that virtual (MOS G37). Incoming mill L1 is zeroed before the platen hit.

1.  A tool change from the probe to a cutting tool is commanded (`T{mill}`).
2.  **Probe `tpost`:** Incoming **`G10 L1 Z0`**, then **`G6511 R1 S0`** at **`nxtTouchProbeRefPos`** every load (does not skip if mill virtual already exists; does not use the setter pad `Z_act−8`). Fast find seeks past mill-touch Z (`nxtToolSetterProbeTravelMm`) so probe vs mill stickout still triggers. Cache virtual. Probe L1 stays 0.
3.  **Swap:** `tfree` then `tpre` run a **full `G27`** before Remove/Install `M291` so the table parks. First `T` skips tfree — tpre still full-parks.
4.  **Measure cutter:** Mill `tpost` **`G10 L1 Z0`** on the incoming mill, then **`G27 Z1`**, probes the **toolsetter**. Trailing full **`G27`** parks after `G10`. Same-T does not run tpost.
5.  **Calculate Offset:** `New_Offset = -(Z_act_cutter − nxtProbeVirtualTsZ)` where virtual is pad `meanZ − nxtDeltaMachine` after the last T49. Probe L1 stays 0. Do not add the previous mill’s L1.
6.  **Apply & Cache:** `G10 L1 P{mill} Z{New_Offset}` and cache `Z_act_cutter` for this mill for the session.

**Job-start mill from T-1:** CAM often issues the first mill `T` with no prior `tfree`, so RRF `previousTool` is **-1**. tpost measures against **probe virtual** (last G6511 / persist), not a previousTool match. Confirm Console **`Offset=`** after the setter slow pass.

**Park:** Real T-change zeros **incoming** L1 before measure (not the outgoing mill in tfree/tpre). After measure + `G10 L1`, tpost runs a **full `G27`**. `G27 Z1` at tpost *start* is only a raise after that Z0.

### Scenario C: Subsequent Tool Change (Cutter A -> Cutter B)

With pad virtual (live or persisted after a T49 G6511), every mill is measured **against that virtual**, same as MOS G37 — not against cutter A’s L1.

1.  A tool change from Cutter A (e.g. T1) to Cutter B (e.g. T7) is commanded from DWC or CAM — **not** only at job start.
2.  **No measurement of T1 on tfree.**
3.  After **M999**, mill cache is empty: tpost still uses **persisted `nxtProbeVirtualTsZ`**. A new T49 **G6511 R1** refreshes it from the reference surface.
4.  **Measure "New" Tool:** Cutter B on the **toolsetter**.
5.  **Calculate Offset:** `New_Offset = -(Z_act_B − virtual)`.
6.  **Apply & Cache:** `G10 L1` on B and cache `Z_act_B` for session diagnostics.

If there is **no** mill virtual and **no** setter Z, mill-to-mill cannot run vs the datum pin. tpost **aborts** and asks for **M5016**. Optional session cache `New_Offset = Old_Offset − (Z_new − Z_old)` only when virtual is still null but cache Z exists.

### Scenario D: The `T-1` Edge Case (Unmeasured Tool -> Known Tool)

This workflow handles a **paper touch-off** when the **toolsetter is not** in the mill `tpost` path (`nxtFeatureToolSetter` off or `nxtToolSetterPos` null).

1.  **Initial State:** Operator set WCS Z with an unmeasured stick-out (paper `G10 L20 … Z0`). There is no platen mill datum.
2.  **Tool Change Request:** Operator or CAM loads a mill (`T0`, …).
3.  **System Action:** mill `tpost` zeros **incoming** L1 then measures. If setter XY exists but **Z is missing**, it **aborts** and asks for **M5016** (not G6511 / not paper-touch). Only the **no-toolsetter** branch takes Scenario D:
    - **`G37.1`** — re-establish WCS Z with the mill on the workpiece.
    - Then a **full `G27`** so CAM spindle/XY start from park.

If M5016 has run (virtual = platen Z, persisted), mill-to-mill is **Scenario C**, not D — even after M999, and even when `previousTool` is -1.