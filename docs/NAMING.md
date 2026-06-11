# Naming conventions

## Product and DWC plugin: `nxt`

| Item | Value |
|------|--------|
| Product name | `nxt` |
| `plugin.json` `id` | `nxt` |
| `dwcWebpackChunk` | `nxt` |
| Routes | `/nxt`, `/nxt/ToolLibrary`, … |
| Web assets | `/nxt/js/nxt.<hash>.js`, `/nxt/css/nxt.<hash>.css` |
| `dwc-plugins.json` key | `nxt` |
| Dev symlink | `DuetWebControl/src/plugins/nxt` → `MOS-nxt/ui` |
| Main Vue shell | `ui/src/nxt.vue` |

## Repository: `MOS-nxt`

| Item | Value |
|------|--------|
| Checkout folder | `MOS-nxt/` |
| GitHub | https://github.com/MillenniumMachines/MOS-nxt |
| Releases | https://github.com/MillenniumMachines/MOS-nxt/releases |

## i18n (`plugins.nxt.*`)

UI copy uses the **`plugins.nxt`** prefix in templates (e.g. `$t('plugins.nxt.panels.status.caption')`). Locale registration: `registerPluginLocalization('nxt', 'en', en)` — matches plugin `id`.

## SD / macros

- Boot: `nxt.g`, `global.nxt*`, `nxt-config/` on SD
- Release ZIP: `nxt-<version>.zip`

## Checks

```bash
./dist/audit-naming.sh
./dist/verify-nxt-plugin-contract.mjs
```

See [`.cursor/rules/naming.mdc`](../.cursor/rules/naming.mdc).
