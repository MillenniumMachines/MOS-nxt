# RepRapFirmware reference version (nxt)

When **evaluating macros, meta G-code, object-model assumptions, or G/M-code behavior**, use this repository’s **reference** board firmware for the **current release branch**:

| | |
|---|---|
| **Branch** | `v0.7.0` |
| **Reference RRF** | **3.7.0-beta.1** (3.7.x line) |
| **DWC build pin** | [`ci/dwc-build-ref`](../ci/dwc-build-ref) → `v3.7.0-beta.1` |
| **Purpose** | Default version to check against release notes, G-code dictionary, and OM fields when reviewing or implementing nxt changes on this line |

This is the **evaluation target**: PR review, macro design, and docs on branch **`v0.7.0`** should be checked for compatibility with **RRF 3.7.x** unless a change explicitly documents a different floor or ceiling.

**Version alignment:** nxt **`v0.M.0`** branches target RRF/DWC **`3.M.x`**. See [VERSIONING.md](VERSIONING.md).

**Minimum machine requirement** may still be lower for end users on older lines (see [README.md](../README.md)); the reference version is what **developers and reviewers** treat as canonical on **`v0.7.0`**.

**Migration from 3.6:** [RRF_3.7_MIGRATION.md](RRF_3.7_MIGRATION.md)

**Useful links**

- [Duet3D G-code dictionary](https://docs.duet3d.com/User_manual/Reference/Gcodes) (select documentation matching the reference RRF generation)
- [RepRapFirmware releases](https://github.com/Duet3D/RepRapFirmware/releases)
- [Object model documentation](https://github.com/Duet3D/RepRapFirmware/wiki/Object-Model-Documentation)
- [RRF 3.6.3 → 3.7.0-beta.1 changelog](https://github.com/Duet3D/RepRapFirmware/wiki/Changelog-RRF-3.x-Beta#reprapfirmware-changes-from-363-to-370-beta1)

**Note:** nxt probing uses **`G68`** for XY coordinate rotation after **`G10 L2`**. **G68** rotation direction was fixed in **RRF 3.6.1** (anticlockwise **R**, matching CNC convention); **G68** per motion system landed in **3.6.2**. The **3.7** line inherits those fixes. nxt arms session **`nxtJobG68Deg`** when applying rotation and clears it at job end — see [DETAILS.md](DETAILS.md) (native probing / job-scoped G68).
