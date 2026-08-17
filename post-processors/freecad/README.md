# FreeCAD Post Processor for nxt

## Installation

1. Download `nxt-<version>_post.py` from the [GitHub Release](https://github.com/MillenniumMachines/MOS-nxt/releases) that matches your installed nxt firmware version (see `M4005` / `global.nxtVersion`).
2. Copy the file into your FreeCAD **macro directory** (the same folder used for `.FCMacro` files).
3. Restart FreeCAD or refresh the CAM post list if needed.
4. In the CAM workbench, select the post processor whose name matches the file prefix (e.g. `nxt-v0.6.0` for `nxt-v0.6.0_post.py`).

FreeCAD expects post processors to follow the `<prefix>_post.py` naming convention (`_post.py` must be lowercase). See the [FreeCAD CAM post customization guide](https://github.com/FreeCAD/FreeCAD-documentation/blob/main/wiki/CAM_Postprocessor_Customization.md#naming-convention).

## Notes

- The post outputs nxt-specific G/M-codes for probing, tool setup, and job preamble. It targets RRF 3.5+ with nxt macros installed.
- Version compatibility is checked at job start via `M4005` when **version-check** is enabled (default).
- If you upgrade nxt firmware, install the matching `_post.py` from the same release line and remove older `nxt-*_post.py` files from your macro directory to avoid duplicate entries in the post list.
