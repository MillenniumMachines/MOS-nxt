# RepRapFirmware reference version (nxt)

When **evaluating macros, meta G-code, object-model assumptions, or G/M-code behavior**, use this repository’s **reference** board firmware:

| | |
|---|---|
| **Reference RRF** | **3.6.2** |
| **Purpose** | Default version to check against release notes, G-code dictionary, and OM fields when reviewing or implementing nxt changes |

This is the **evaluation target**: PR review, macro design, and docs should be checked for compatibility with **RRF 3.6.2** unless a change explicitly documents a different floor or ceiling.

**Minimum machine requirement** may still be lower for end users (see [README.md](../README.md)); the reference version is what **developers and reviewers** should treat as canonical when reasoning about firmware behavior.

**Useful links**

- [Duet3D G-code dictionary](https://docs.duet3d.com/User_manual/Reference/Gcodes) (select documentation matching the reference RRF generation)
- [RepRapFirmware releases](https://github.com/Duet3D/RepRapFirmware/releases)
- [Object model documentation](https://github.com/Duet3D/RepRapFirmware/wiki/Object-Model-Documentation)

**Note:** nxt probing uses **`G68`** for XY coordinate rotation after **`G10 L2`**. RRF **3.6.1** fixed the **`G68`** rotation direction; **3.6.2** is the stated reference for holistic evaluation (including fixes and OM changes after 3.6.1).
