# RepRapFirmware reference version (nxt)

When **evaluating macros, meta G-code, object-model assumptions, or G/M-code behavior**, use this repository’s **reference** board firmware for branch **`v0.6.0`**:

| | |
|---|---|
| **Branch** | `v0.6.0` |
| **Reference RRF** | **3.6.3** (3.6.x line) |
| **DWC build pin** | [`ci/dwc-build-ref`](../ci/dwc-build-ref) → `v3.6.3` |
| **OM budget** | **~5 KiB** serialized `global` — see [OM_GLOBAL_SIZE.md](OM_GLOBAL_SIZE.md) |

This is the **evaluation target** on **`v0.6.0`**: PR review, macro design, and docs should be checked for compatibility with **RRF 3.6.3** unless a change explicitly documents a different floor or ceiling.

**Dual maintenance:** [`v0.7.0`](../docs/VERSIONING.md) targets RRF **3.7.x**. See [BRANCH_PORTING.md](BRANCH_PORTING.md).

**Useful links**

- [Duet3D G-code dictionary](https://docs.duet3d.com/User_manual/Reference/Gcodes) (select documentation matching the reference RRF generation)
- [RepRapFirmware releases](https://github.com/Duet3D/RepRapFirmware/releases)
- [Object model documentation](https://github.com/Duet3D/RepRapFirmware/wiki/Object-Model-Documentation)

**Note:** nxt probing uses **`G68`** for XY coordinate rotation after **`G10 L2`**. RRF **3.6.1** fixed the **`G68`** rotation direction; **3.6.3** is the stated reference for holistic evaluation on this line.
