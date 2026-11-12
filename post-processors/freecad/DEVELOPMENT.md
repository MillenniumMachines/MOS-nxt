# FreeCAD Machine Post: Developer Notes

This document records implementation details and upstream behavior that are not needed for normal installation or machine setup. The user guide is in [README.md](README.md).

## Base-class responsibilities

The FreeCAD `PostProcessor` base class handles these features through the machine definition:

| Legacy behavior | Machine definition |
|---|---|
| argparse options | property schema and Machine editor |
| header and comments | `output.header.*`, `output.comments.*` |
| coordinate, feed, and spindle precision | `output.precision.*` |
| modal deduplication | `output.duplicates.*` |
| canned-cycle expansion | `processing.translate_drill_cycles` |
| G21/G90/G94 | `postprocessor.properties.preamble` |
| park and stop at end | `postprocessor.properties.postamble` |

## Post overrides

- `_expand_prefix` builds the job-specific M4005 version check, M4000 tool table, G6511 reference probe, G6600 WCS probing, and M7000 VSSC. It also appends the legacy closing sequence: `M9`, `G27`, `M7001`, `M9`, `M5.9`.
  - Each M4000 line carries `P` (tool number), `R` (diameter / 2), `S` (the tool controller label, cut to 32 characters), and `F` (flute count) and `L` (`CuttingEdgeHeight`, in mm) when the tool bit has them. A word is left out when the shape lacks it or it is 0, as with a drill's flute length, so M4000 keeps whatever the firmware already holds. nxt only shows `F` and `L` in the DWC status panel. The Fusion post doesn't emit them.
- `_convert_tool_change` emits a bare `T` word because firmware services tool changes; `M6` is suppressed.
- `_convert_spindle_command` adds the `.9` wait suffix so RRF blocks until the spindle reaches speed.
- `_convert_fixture` parks before a WCS change, then optionally probes and emits M5011.
- `_convert_coolant_command` labels coolant commands inserted by FreeCAD.
- `_delay_leading_z`, called from `_convert_item_commands`, moves a leading Z-only approach after the first XY move.
- `get_sanity_checks` warns about rotary axes, multiple spindles, and disabled version checks.
- `_optimize_duplicates_doubles` and `_convert_linear_move` implement the arc-start restatement after plane changes; see "Parity with the legacy post's v0.7.0 fixes" in the README.

Compatibility fixes:

- `format_parameter` trims trailing zeros, normalizes `-0`, and supports 26.x base methods with or without the `command_name` argument.
- `_expand_prefix` sets `PARAMETER_ORDER` to match legacy output. It must be set there because `apply_configuration_bundle()` replaces `self.values` during Stage 0.
- `_convert_rapid_move` removes `F` from `G0` and drops rapid moves whose axes were all deduplicated. The base class's `F_FOR_RAPID_MOVES` check is unreachable when `output.duplicates.parameters` is false.
- `_convert_arc_move` removes zero-valued `I`/`J`/`K` offsets, matching legacy output.
- `_convert_modal_command` drops `G80`, `G98`, and `G99` (see the divergence table in the README) and labels `G17`/`G18`/`G19`.

## Approach ordering

FreeCAD commonly emits `G0 Z5` followed by `G0 X.. Y..`. After a tool change, the machine is parked above the toolsetter. Descending before traversing can send the XY move through the toolsetter, so the post defers the leading pure-Z move until after the first XY move.

Only pure-Z moves are deferred; legacy also deferred combined XYZ moves. Any deferred move left at the end of an operation is emitted rather than dropped. The held move is flushed before the next move, so a coolant-on between them still precedes the descent. The reorder runs after the base class's axis-word deduplication; this is safe because a pure-Z move and an XY move touch disjoint axes.

## Upstream FreeCAD behavior

FreeCAD 26.3's machine-post API is evolving. The machine post requires the 2026-09-02 weekly build or later. Last checked against `origin/main` at `a4ce44d33b` (2026-09-14) and the 2026.09.16 weekly AppImage.

### Duplicate suppression and tool changes

Before commit [`493bba9e42`](https://github.com/FreeCAD/FreeCAD/commit/493bba9e42), `GcodeProcessingUtils.suppress_redundant_axes_words()` suppressed repeated axes in output text and reset only at `M6`/`M06`. Since this post emits a bare `T` word, that reset was missed and a retract could be suppressed across a tool change. A sentinel-comment workaround was used in the old pipeline.

The command-stage deduplicator now recognizes tool-change commands and `ANNOT_MODAL_BARRIER` before conversion. The string-stage `_optimize_gcode()` hook was also removed, and any override of it is dead code. `_reset_modal_state()` handles the separate conversion-stage suppression pass.

### Coolant commands

FreeCAD hardcodes coolant commands as `M7`/`M07`, `M8`/`M08`, and `M9`/`M09`. A non-standard command such as nxt's `M7.1` air blast does not dispatch to `_convert_coolant_command()` or `_expand_coolant_delay()`. Making these constants post-overridable would support non-standard coolant modes.

## Machine-definition details

- FreeCAD inserts `M7`/`M8`/`M9` into the operation path based on `obj.CoolantMode`; the post only labels them.
- On 3-axis machines, many fields (including axis limits, velocity, and coolant properties) are descriptive rather than inputs to posted output. Keep them accurate for the editor, validator, and future versions.
- Spindle `min_rpm` and `max_rpm` are active: FreeCAD clamps speeds to that range and scales feeds to preserve chipload.
- `_make_postable(label, [])` does not create a deduplication barrier. A postable without a path does; an empty `Path` does not. A `str` postable, such as those `_expand_prefix()` makes from `PREAMBLE`, is a barrier.
- `supported_commands` is substring-matched, so `M3` also matches `M30`.
- The `.fcm` validator checks axis limit ordering, kinematic chains, post resolution, property keys, and ignored keys.
- `processing.f_for_rapid_moves` is not read from `.fcm` by this FreeCAD version. `_convert_rapid_move()` enforces the desired behavior directly.
- `processing.filter_inefficient_moves` is currently unused upstream. Keep it `false`; `_optimize_g0()` is not called by `export2()` and `collapse_g0()` has no active caller.
- Command annotations include `ANNOT_MODAL_BARRIER`, `ANNOT_ALLOW_UNSUPPORTED`, and `ANNOT_NO_COLLAPSE_G0`.

### Machine definition settings

These are not FreeCAD defaults; each was arrived at by comparing output against the legacy post.

| Setting | Value | Why |
|---|---|---|
| `processing.filter_inefficient_moves` | `false` | `collapse_g0()` removed ~1500 rapids on a test job, including the XY approach before every operation. Currently unwired upstream |
| `processing.translate_drill_cycles` | `false` | nxt implements G73/G81/G83 natively |
| `processing.f_for_rapid_moves` | `false` | legacy emits no `F` on `G0`; the `.fcm` key is dropped by the loader, `_convert_rapid_move()` enforces it |
| `output.duplicates.commands` | `true` | means "emit the command word every line"; `false` suppressed the `M4000` prefix on repeated lines, producing bare parameter lines RRF would reject |
| `output.duplicates.parameters` | `false` | suppress unchanged axis words, as legacy does |
| `output.comments.symbol` | `"("` | `;` produces a file mixing both styles |
| `output.precision.feed` | `0` | legacy truncates feed to whole mm/min |
| `output.precision.axis` | `4` | matches the legacy post's `AXIS_DECIMALS = 4`, required for RRF G2/G3 arc tolerance |
| `toolheads[0].toolhead_wait` | `0.0` | `M3.9` already blocks; a `G4` dwell would double the wait |

The shipped definitions cover every machine pack in `macros/nxt-config/machine/` apart from `custom`. Their travels are the published nominal figures, not the placeholder `M208` values in those packs.

## Validation notes

### Legacy comparison

Comparisons run in the MillenniumOS port across a profiling job, a large adaptive job, and a drilling job found these differences:

- Feed rounding: legacy truncates feed while the base rounds, e.g. `F919` versus `F920`.
- Feed placement: the machine post may emit a standalone `G1 F...` before the next move.
- Modal axes: the machine post omits unchanged axes that the legacy post reasserts; the tested motions were equivalent.
- One extra `M9` before `G27`: this is a no-op when coolant is already off and can be removed from `postprocessor.properties.postamble` for an exact match.

These comparisons predate FreeCAD commit `493bba9e42`, which moved suppression to `Path.Command` objects and changed when approach reordering runs. Re-run the comparisons on a current build before relying on those results.

### Coverage gaps

Nothing in this port has been verified against nxt firmware on real hardware; the equivalence results were established for MillenniumOS.

`_force_arc_start_after_plane_change()` has unit coverage for its command handling but has never run inside FreeCAD. No FreeCAD CAM operation emits `G18`/`G19` as a side effect of its toolpath; only the Shape operation (via `ArcPlane` with `EmitPreamble`) or a Custom op with `PostProcessOutput` on can trigger it. To exercise it, post such a job and confirm each first arc after a plane change is preceded by a `G1` carrying real X/Y values, not a bare `G1`.

Both FreeCAD posts restate X and Y whatever the plane, whereas `nxt.cps` restates the in-plane axes. Entering an `XZ` arc may want X and Z restated; resolve this across all three posts rather than diverging further.

No job has exercised multiple fixtures/WCSs or probing operations; `_convert_fixture()`'s park-before-change branch and multiline return remain untested. Rotary support is also untested on hardware. The README documents the operational limitations and dry-run guidance.
