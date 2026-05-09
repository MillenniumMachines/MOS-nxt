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

On a normal NeXT install, **`nxt-vars.g` does not define** magazine globals (`atcMagazineCount`, `atcPocketToTool`, etc.). **`nxt.g`** loads **`nxt-tooltable.g`** when **`mosTT`** is not already defined (for example after optional **`mos-vars.g`** during MOS import), pre-allocating **`mosET`** / **`mosTT`**. **[`macros/utilities/M4000.g`](../macros/utilities/M4000.g)** and **[`macros/utilities/M4001.g`](../macros/utilities/M4001.g)** on **`0:/sys/`** define RRF tools from the CAM post (radius and name in `M4000`, optional probe deflections in `X`/`Y`, optional flute count **`F`** and flute length **`L`**) and keep **`mosTT`** in sync for the Tool Library / legacy OM helpers. Spindle binding uses **`global.nxtSpindleID`**, defaulting to **0** when unset (optional **`I`** overrides, same as MillenniumOS). Magazine / bay globals remain absent until the optional pack is installed.

### RRF `tools[]` vs cutter geometry

Standard RepRapFirmware **does not** put cutter radius or diameter on **`machine.model.tools[n]`** in the object model (tool name, spindle mapping, offsets, etc. are there; geometry is not). **`M4000`** uses **`M563`** for the real tool row and **`global.mosTT`** for post-processor radius (optional probe deflections **`X`/`Y`**, optional **`mosTT[n][2]`** / **`[3]`** for flute count **`F`** and flute length mm **`L`**; **`-1`** = unset). The **NeXT DWC Tool Library** treats **`tools[n]`** as the primary record and **enriches display** with **`nxtRadiusMm`** / **`nxtDiameterMm`** and **`nxtFluteCount`** / **`nxtFluteLengthMm`** via **`augmentRrfToolForNeXtUi`** in the plugin (OM-first for radius if a future RRF adds native fields, else **`mosTT`**).

**Persisting the library:** Use **Tool Library → Save to board** to replace **`0:/sys/nxt-user-tools.g`** (HTTP path **`/sys/nxt-user-tools.g`** for `rr_upload`). The file contains one **`M4000`** line per tool (name, radius, spindle override, optional **`X`/`Y`** and **`F`/`L`** from **`mosTT`** when set) and, when present in the OM, a **`G10 L1 P…`** line with axis offsets (**`tools[n].offsets`** vs **`move.axes`** order). **`nxt.g`** runs **`M98 P"nxt-user-tools.g"`** after **`nxt-user-vars.g`** when the file exists, so definitions survive **M999** and power cycles. **Reload from SD** runs the same macro without a full restart.

**Auto-save from CAM / console:** After each successful **`M4000`** or **`M4001`**, **`nxt-user-tools-sync.g`** rewrites **`nxt-user-tools.g`** from the live **`tools[]`** / **`mosTT`** (same idea as the DWC save). This is skipped while the persistence file itself is **`M98`**-loading: the file must start with the **`nxtUserToolsLoadDepth`** wrapper (Tool Library save emits it; **`nxt-user-tools-sync.g`** always emits it) so **`M4000`** lines inside the file do not truncate it mid-load. Disable repeated SD writes with **`global nxtAutoPersistTools = false`** in **`nxt-user-vars.g`**. **`G10`**-only changes (no **`M4000`**) are not auto-captured until the next **`M4000`**/**`M4001`**, UI save, or manual **`M98 P"nxt-user-tools-sync.g"`**.

**Optional daemon reload:** Meta G-code exposes **`fileexists()`** but not a portable SD “file changed” / mtime, so NeXT cannot poll **`nxt-user-tools.g`** for edits by itself. To have **`daemon.g`** re-run **`M98 P"nxt-user-tools.g"`** after you upload a new library (refreshing **`tools[]`** / **`mosTT`** without **`M999`**), set **`global nxtUserToolsDaemonReload = true`** in **`nxt-user-vars.g`**. Then create an empty sentinel **`0:/sys/nxt-user-tools.reload.requested`** (zero-byte file via **`rr_upload`** or any editor). While **`state.status`** is **`idle`** and **`nxtUserToolsLoadDepth`** is inactive, **`nxt/nxt-user-tools-reload-daemon.g`** (under **`0:/sys/nxt/`**, called from **`macros/daemon/nxt-daemon.g`**) removes the sentinel with **`M472`** and runs **`M98 P"nxt-user-tools.g"`**. At boot, **`nxt.g`** still loads the file only when **`fileexists("0:/sys/nxt-user-tools.g")`**, echoes status, and sets **`global.nxtUserToolsFilePresent`**.

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

1. **`global.nxtProbeToolID`** (RRF tool index for the probe / datum tool), then  
2. Optional legacy **`global.mosPTID`** if the extension firmware defines it.

**`global.nxtTouchProbeID`** is the **touch probe sensor** ID for `G6512` / probing macros, not the tool-table slot.

---

## 4. Tool radius in the object model

The panel prefers **RRF tool object fields** (`radius` / `diameter` from `state.tools[]`) when present, then falls back to optional legacy **`mosTT[tool][0]`** if the extension defines it. See **`resolveToolRadiusMm`** in `nxtToolChangerOm.ts`.

---

## 5. Related files

| Area | Path |
|------|------|
| NeXT default globals | `macros/system/nxt-vars.g`, `macros/system/nxt-tooltable.g` (mosTT) |
| Persisted tool library (optional) | `0:/sys/nxt-user-tools.g` — `M4000` + `G10 L1`; written from DWC Tool Library or by hand; see `macros/system/nxt-user-tools.g.example` |
| Tooling hooks (examples) | `macros/tooling/tfree.g`, `tpre.g`, `tpost.g` |
| DWC OM helpers + key map | `ui/src/utils/nxtToolChangerOm.ts` |
| Tool Library (configured RRF tools only) | `ui/src/components/panels/ToolManagementPanel.vue` |
| `nxt-user-tools.g` builder | `ui/src/utils/nxtUserToolsFile.ts` |
| SD rewrite after M4000/M4001 | `macros/system/nxt-user-tools-sync.g` |
| Optional daemon reload (sentinel) | `macros/daemon/nxt-user-tools-reload-daemon.g` → `0:/sys/nxt/` (invoked from `nxt-daemon.g`) |
| OM helpers + key map (for mos-atc UI) | `ui/src/utils/nxtToolChangerOm.ts` |

When adding or renaming firmware globals in a **fork** of the extension pack, update **`NxtToolChangerOmKeys`** (and this doc) so the mos-atc UI stays aligned.
