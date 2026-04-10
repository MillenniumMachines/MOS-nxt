# Tool changing in NeXT

This note ties together **RepRapFirmware (RRF) stock tool change behaviour**, **NeXT’s tooling macros**, and the **optional magazine / ATC extension** (firmware globals + macros). The **NeXT DWC plugin Tool Library** lists only **configured RRF tools**; **magazine / job-sequence / ATC operator UI** is intended to live in the **mos-atc** DWC plugin when that pack is installed—not in base NeXT.

---

## 1. RRF baseline: `T` and tool-change macros

RRF selects tools with **`Tn`** (e.g. `T3`). For each tool change, the firmware runs the configured macros in order:

| Macro   | Typical role |
|--------|----------------|
| **`tfreeN.g`** | Run **before** releasing the previous tool `N` (e.g. move to changer, unlock). |
| **`tpreN.g`**  | Run **before** picking up new tool `N`. |
| **`tpostN.g`** | Run **after** new tool `N` is active. |

File names use the **tool index** (e.g. `tpost3.g` for tool 3). Paths are normally under the active **macros** directory (often `0:/macros/` or paths configured in your `config.g`).

**Official references (bookmark these):**

- [Duet3D Wiki — Configuring RepRapFirmware for CNC usage](https://docs.duet3d.com/UserManual/SBC/CNC) (tool table, general CNC)
- [RepRapFirmware G-code — `T` / tool selection](https://docs.duet3d.com/UserManual/Reference/Gcodes) (see tool change and related codes for your RRF version)

NeXT ships example tooling hooks under:

- `macros/tooling/tfree.g`
- `macros/tooling/tpre.g`
- `macros/tooling/tpost.g`

…which you wire in **config.g** / tool definitions as appropriate for your machine. Those files are the right place to integrate with **your** physical changer logic.

---

## 2. NeXT base install vs optional extension

### Base NeXT (`nxt-vars.g`)

On a normal NeXT install, **`nxt-vars.g` does not define** magazine globals (`atcMagazineCount`, `atcPocketToTool`, etc.) or legacy table vectors like **`mosTT`**. The UI and macros assume a standard RRF tool table and NeXT globals (`nxtTouchProbeID`, `nxtProbeToolID`, …).

### Optional tool changer extension

If you install a **compatible macro pack** on the machine (same object-model wire format as the legacy mos-atc-style pack), the firmware may expose globals such as:

- `atcMagazineCount`, `atcSlotsPerMagazine`, `atcPocketCount`
- `atcPocketToTool`, `atcToolToPocket`
- `atcEnabled`, `atcToolChangeMode`, `atcBayMode`
- Job sequence arrays (`atcJobSeq*`) if your post processor fills them

Base **NeXT** does not drive those from its Tool Library panel. Use the **mos-atc** DWC plugin (paired with that macro pack) for magazine layout, bay cards, job sequence, and M870–M879 / M401x controls. **`ui/src/utils/nxtToolChangerOm.ts`** remains the shared OM key / M-code map for that plugin or forks.

**Single source of truth for OM key names in the repo:**  
`ui/src/utils/nxtToolChangerOm.ts` — export **`NxtToolChangerOmKeys`** maps stable NeXT-side names to the actual RRF global strings (unchanged for compatibility with installed firmware).

**M-code numbers** for that extension (used by **mos-atc** UI, not base NeXT Tool Library):  
`NxtToolChangerExtensionM` in the same file (e.g. 870–879, 4010–4014). The pack must provide matching `M*.g` files on `0:/sys/` (or your board’s sys path).

---

## 3. Probe tool index in the UI

The Tool Library highlights the touch probe using, in order:

1. **`global.nxtTouchProbeID`** (NeXT configuration), then  
2. Optional legacy **`global.mosPTID`** if the extension firmware defines it.

Prefer configuring **`nxtTouchProbeID`** in **`nxt-user-vars.g`** / Configuration UI so NeXT does not depend on legacy globals.

---

## 4. Tool radius in the object model

The panel prefers **RRF tool object fields** (`radius` / `diameter` from `state.tools[]`) when present, then falls back to optional legacy **`mosTT[tool][0]`** if the extension defines it. See **`resolveToolRadiusMm`** in `nxtToolChangerOm.ts`.

---

## 5. Related files

| Area | Path |
|------|------|
| NeXT default globals | `macros/system/nxt-vars.g` |
| Tooling hooks (examples) | `macros/tooling/tfree.g`, `tpre.g`, `tpost.g` |
| DWC OM helpers + key map | `ui/src/utils/nxtToolChangerOm.ts` |
| Tool Library (configured RRF tools only) | `ui/src/components/panels/ToolManagementPanel.vue` |
| OM helpers + key map (for mos-atc UI) | `ui/src/utils/nxtToolChangerOm.ts` |

When adding or renaming firmware globals in a **fork** of the extension pack, update **`NxtToolChangerOmKeys`** (and this doc) so the mos-atc UI stays aligned.
