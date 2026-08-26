# Standalone M292 hang: DWC 3.6 vs 3.7 code map

**Verdict:** The hang is **not** in NeXT macros. It is stock **DuetWebControl** `MessageBoxDialog` on standalone boards (**PollConnector**). Duet added `noWait: true` for every `M292` on the **3.6** line only; the **3.7** Vue 3 rewrite never received that change. NeXT restores the workaround at plugin load via a Pinia `sendCode` wrapper.

## Symptom

On boards **without an SBC**, after the operator acknowledges the **first** `M291` prompt (OK / Accept / Cancel), the UI can freeze: the dialog closes but the next `M291` never appears. Multi-prompt macros (e.g. M5016 calibration, tool-change `S4`) look stuck.

**SBC / DSF** is unaffected: `RestConnector` returns the G-code reply on the HTTP response (or uses `{ async: true }` when `noWait` is set).

## Root cause

1. RRF does not yet return matching per-request G-code replies for standalone `rr_gcode` / `rr_reply` ([RRF #925](https://github.com/Duet3D/RepRapFirmware/issues/925) — still open).
2. Stock DWC 3.7 `MessageBoxDialog` `await`s `machineStore.sendCode(M292…)` **without** `noWait`.
3. On standalone, `PollConnector.sendCode` parks a Promise on the reply sequence until it advances. When RRF never delivers a matching reply for that request, the `await` never settles, so the dialog handler never finishes and subsequent prompts do not show.

```mermaid
sequenceDiagram
  participant UI as MessageBoxDialog
  participant Store as machineStore.sendCode
  participant Poll as PollConnector
  participant RRF as RRF_rr_gcode

  UI->>Store: await sendCode("M292 S…")
  Store->>Poll: sendCode(code, noWait=false)
  Poll->>RRF: GET rr_gcode
  Note over Poll,RRF: RRF #925: no matching per-request reply
  Poll-->>Store: Promise parked on reply-seq
  Note over UI: Dialog closed; await never settles
  Note over UI: Next M291 modal never shown
```

### Upstream layers

| Layer | Path (DuetWebControl) | Role |
|-------|------------------------|------|
| Dialog UI | `src/components/dialogs/MessageBoxDialog.vue` | Builds `M292 … S{seq}` on OK / Accept / Cancel |
| Store API | `src/stores/machine.ts` (`sendCode`) | `sendCode(code, fromInput, logReply, noWait?)` → `connector.sendCode(code, noWait ?? false)` |
| Standalone | `@duet3d/connectors` `PollConnector.sendCode` | `rr_gcode`, then if `!noWait` parks on `pendingCodes` until reply seq advances |
| SBC | `@duet3d/connectors` `RestConnector.sendCode` | HTTP POST `machine/code` carries the reply |

`PollConnector` wait gate (conceptual):

```js
// @duet3d/connectors PollConnector.sendCode
if (!noWait && seq === this.lastSeqs.reply && strippedCode !== "" /* … */) {
  return new Promise((resolve, reject) => pendingCodes.push({ seq, resolve, reject }));
}
return (noWait ? undefined : "");
```

## Code that exists in 3.6 but not in 3.7

**Commit:** [`d02661dd`](https://github.com/Duet3D/DuetWebControl/commit/d02661dd257418afdbc3732c0834b25458466716) — *“M292 no longer waits for replies (v3.6 only)”* (2025-04-29, Christian Hammacher).

- Present on `v3.6-dev`
- **Not** an ancestor of `v3.7-dev` (never ported through the Vue 3 rewrite)

### DWC 3.6 (`MessageBoxDialog.vue`)

Vuex object form with `noWait: true` on every ack path:

```js
// NOTE: The following calls use noWait because we don't want M292 replies to be logged.
// This option will become obsolete in 3.7 or 3.8 when RRF is able to return G-code replies
// for each G-code request
await store.dispatch("machine/sendCode", {
  code: `M292 S${this.messageBox.seq}`,
  noWait: true,
});
// Same pattern for R{…} / P1 variants in ok / accept / cancel
```

Branch file: [v3.6-dev MessageBoxDialog.vue](https://github.com/Duet3D/DuetWebControl/blob/v3.6-dev/src/components/dialogs/MessageBoxDialog.vue)

### DWC 3.7.0-beta.1 (NeXT build pin)

Pinia positional call with **no** fourth argument — still waits for a reply:

```js
await machineStore.sendCode(`M292 S${messageBox.seq}`);
```

### Current `v3.7-dev` tip

[`327401ee`](https://github.com/Duet3D/DuetWebControl/commit/327401ee08e2246e68d95d32fca9ad953c3c1ca7) (2026-07-09) only sets `fromInput=false, logReply=false` — still **omits** `noWait`:

```js
await machineStore.sendCode(`M292 S${messageBox.seq}`, false, false);
// Would need: …, false, false, true)
```

The missing piece vs 3.6 is specifically **`noWait: true` / 4th parameter `true`**, not merely quiet logging. Pinia already accepts `noWait`; the dialog never passes it.

Branch file: [v3.7-dev MessageBoxDialog.vue](https://github.com/Duet3D/DuetWebControl/blob/v3.7-dev/src/components/dialogs/MessageBoxDialog.vue)

## Minimal upstream fix

In DWC 3.7+ `src/components/dialogs/MessageBoxDialog.vue`, on all five `sendCode(M292…)` sites in `ok` / `accept` / `cancel`, pass the fourth argument:

```js
await machineStore.sendCode(`M292 S${messageBox.seq}`, false, false, true);
```

(Or restore an object form equivalent to 3.6’s `{ code, noWait: true }` if the store API is updated.) That matches commit `d02661dd` and becomes obsolete only after RRF #925 lands.

## NeXT mitigation

Until Duet ports the 3.6 workaround, the nxt plugin forces fire-and-forget for every `M292` at load:

| File | Role |
|------|------|
| [`ui/src/utils/nxtPatchM292NoWait.ts`](../ui/src/utils/nxtPatchM292NoWait.ts) | Wraps Pinia `sendCode`; `M292` → `original(code, fromInput, false, true)` |
| [`ui/src/index.ts`](../ui/src/index.ts) | Calls `installNxtM292NoWaitPatch()` at plugin load |
| [`ui/src/components/overrides/MessageBoxDialog.vue`](../ui/src/components/overrides/MessageBoxDialog.vue) | Inert under Vue 3 (App.vue binds stock DWC); already uses `noWait: true` if ever hooked |
| [`ui/src/utils/nxtMessageBoxRespond.ts`](../ui/src/utils/nxtMessageBoxRespond.ts) | Ack string builder (`M292 S{seq}` / `R{n}`) |

Stock DWC modal remains the sole ack UI. The patch is global so the stock dialog benefits without remounting a second Action Confirmation widget (which caused double `M292` / hung macros).

See also: [UI_IMPLEMENTATION.md](UI_IMPLEMENTATION.md#standalone-no-sbc-m292-must-not-await-replies).
