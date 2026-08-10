# RepRapFirmware macro line length

RRF rejects overlong single lines with **`GCode command too long`**. That aborts the current macro (including `config.g` → `nxt.g` on boot), so **`global.nxtLoaded` never becomes true** even when the DWC plugin is installed and started.

## Hard limit (nxt policy)

| Rule | Value |
|------|--------|
| **Maximum characters per line** | **200** (including leading spaces; full physical line) |
| **Comment-only lines** | Exempt (`;` after optional whitespace) |
| **Blank lines** | Exempt |

Enforced by `node dist/check-gcode-line-length.mjs` before plugin/release builds.

## AI / contributor rules (non-negotiable)

1. **Never** add or leave a `.g` line longer than 200 characters.
2. **Never** put a long compound `if { a \|\| b && (c \|\| d \|\| ...) }` on one line — use `var` booleans and a short final `if`.
3. **Never** put a long `echo`, `abort`, or `M291 P{...}` on one line — build the string in one or more `var` lines first.
4. Before finishing macro work, run `node dist/check-gcode-line-length.mjs` and fix all failures.
5. If a change would exceed the limit, **stop and refactor**; do not ship “we’ll fix later”.

## Bad vs good

### Long `if` (boot killer — was `nxt.g` line 26)

**Bad:**

```gcode
if { fileexists("0:/sys/nxt-mos-import.requested") || (!fileexists("0:/sys/nxt-user-vars.g") && (fileexists("0:/sys/mos-vars.g") || ...)) }
```

**Good:**

```gcode
var nxtMosImportForced = { fileexists("0:/sys/nxt-mos-import.requested") }
var nxtNeedsUserVars = { !fileexists("0:/sys/nxt-user-vars.g") }
var nxtMosOnSd = { fileexists("0:/sys/mos-vars.g") || fileexists("0:/sys/mos-user-vars.g") || fileexists("0:/sys/mos.g") }
var nxtMosInGlobals = { exists(global.mosSID) || exists(global.mosFeatTouchProbe) || exists(global.mosPTID) || exists(global.mosLdd) }
var nxtRunMosImport = { var.nxtMosImportForced || (var.nxtNeedsUserVars && (var.nxtMosOnSd || var.nxtMosInGlobals)) }
if { var.nxtRunMosImport }
    M98 P"nxt-mos-import.g"
```

### Long `M291` dialog

**Bad:** one line with full HTML in `P{...}`.

**Good:**

```gcode
var nxtM81Msg = {"<b>CAUTION</b>: Machine Power is <b>on</b>. Deactivate?<br/>Stops <b>ALL</b> movement and spindle."}
M291 P{var.nxtM81Msg} R"nxt: Safety Net" S4 K{"Deactivate", "Cancel"} F1
```

### Long `echo` / `abort`

**Bad:** one `echo` with many `^` concatenations.

**Good:** build `var msg` in steps, then `echo { var.msg }` or `abort { var.msg }`.

## Verification

```bash
node dist/check-gcode-line-length.mjs
```

Also runs automatically at the start of `dist/build-plugin.sh` and `dist/build-plugin-win.ps1`.

## Related docs

- [CODE.md](CODE.md) — macro style (includes line-length summary)
- [RRF_META_PITFALLS.md](RRF_META_PITFALLS.md) — `^` vs power, A-axis indexing, probe dive/`startZ`, hit buffers
- [RRF_META.txt](RRF_META.txt) — CNC meta syntax
- [macros/system/](../macros/system/) — boot macros
