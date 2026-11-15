# FreeCAD Post Processor for nxt

## Installation

1. Download `nxt-<version>_post.py` from the [GitHub Release](https://github.com/MillenniumMachines/MOS-nxt/releases) on the same **major.minor** line as installed nxt (e.g. any 0.7.x post with 0.7 firmware; `M4005` ignores beta/rc/patch).
2. Copy the file into your FreeCAD **macro directory** (the same folder used for `.FCMacro` files).
3. Restart FreeCAD or refresh the CAM post list if needed.
4. In the CAM workbench, select the post processor whose name matches the file prefix (e.g. `nxt-v0.6.0` for `nxt-v0.6.0_post.py`).

FreeCAD expects post processors to follow the `<prefix>_post.py` naming convention (`_post.py` must be lowercase). See the [FreeCAD CAM post customization guide](https://github.com/FreeCAD/FreeCAD-documentation/blob/main/wiki/CAM_Postprocessor_Customization.md#naming-convention).

## Notes

- The post outputs nxt-specific G/M-codes for probing, tool setup, and job preamble. It targets RRF 3.5+ with nxt macros installed.
- Version compatibility is checked at job start via `M4005` when **version-check** is enabled (default). `M4005` matches major.minor only, so a 0.7 post runs on `v0.7.0-beta.N` / `v0.7.0-rcN` / `v0.7.x` firmware without re-exporting.
- If you upgrade nxt firmware to a **new line** (e.g. 0.6 → 0.7), install a post from that line and remove older `nxt-*_post.py` files from your macro directory to avoid duplicate entries in the post list.

## MQTT telemetry (optional)

Pass job arguments (or set them in FreeCAD’s post argument string):

| Flag | Default | Role |
|------|---------|------|
| `--mqtt-telemetry` / `--no-mqtt-telemetry` | off | Emit `M586` reconnect + `M118 P6` tool publishes |
| `--mqtt-device-id` | empty | `duet/{device}/tool` segment — fill to match your collector |
| `--mqtt-broker-host` | empty | Hostname for `M586 P4` (no `mqtt://`) |
| `--mqtt-broker-port` | `1883` | Static default; overridable |
| `--mqtt-job-file` | empty | Optional `job_file` override when basename is only a program number |

When telemetry is enabled, **device ID and broker host are required** or the post raises. Same wire format as the Fusion post / 4th-combinator sim: `duet/{device}/tool`, no `tap/` or `cam/` session mint. Does not replace Pi `tap-spindle` ADXL streams.

**`job_file`:** output basename unless it is `8910` / `8910.gcode` (then `job.gcode`, or `--mqtt-job-file`). **`event`:** `start` then `change`. Charts/accel still need tap-spindle on `tap/#`.
