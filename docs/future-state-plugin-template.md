# nxt Future-State Plugin Template

This document defines the minimum requirements and baseline automation for building a net-new plugin that is supported by nxt using a fully RRF runtime model.

## Design Intent

- Runtime remains RRF-only (`M98` dispatchers + globals).
- Plugin metadata is required and read during build automation.
- Dispatchers are generated from metadata, not hand-authored.
- External plugin repos may live as siblings (`../<repo-name>`) and be referenced from a plugin catalog.

## Required Plugin Metadata

Each plugin must provide a `plugin.json` file with:

- `id` (required, string)
- `version` (required, string)
- `data.nxt.tag` (required, must be `nxt-plugin`)
- `data.nxt.enabled` (optional, default `true`)
- `data.nxt.loadOrder` (optional, default stable ordering by plugin id)
- `data.nxt.failureMode` (optional, `soft` or `strict`)
- `data.nxt.entrypoints.init` (required path to init macro)
- `data.nxt.entrypoints.daemon` (optional path to daemon macro)
- `data.nxt.entrypoints.pause|resume|stop|cancel` (optional event hooks)

Example:

```json
{
  "id": "nxt-CoolantPlus",
  "version": "1.0.0",
  "data": {
    "nxt": {
      "tag": "nxt-plugin",
      "enabled": true,
      "loadOrder": 20,
      "failureMode": "soft",
      "entrypoints": {
        "init": "plugins/next-coolant-plus/next-coolant-plus-init.g",
        "daemon": "plugins/next-coolant-plus/next-coolant-plus-daemon.g"
      }
    }
  }
}
```

## Required Macro Layout

Under staged `/sys` the plugin must provide:

- `plugins/<plugin-id>/<plugin-id>-init.g` (required)
- `plugins/<plugin-id>/<plugin-id>-daemon.g` (optional)
- `plugins/<plugin-id>/<plugin-id>-pause.g` (optional)
- `plugins/<plugin-id>/<plugin-id>-resume.g` (optional)
- `plugins/<plugin-id>/<plugin-id>-stop.g` (optional)
- `plugins/<plugin-id>/<plugin-id>-cancel.g` (optional)

## Global Loading Contract

Generated init dispatchers must use:

- `global nxtPluginLoaded_<plugin_namespace> = false` for first definition
- `set global.nxtPluginLoaded_<plugin_namespace> = true` after init runs

This guarantees one-time init per boot/session.

## Plugin Catalog

nxt uses `dist/plugins.catalog.json` as a source list for build automation.

Fields:

- `id` (logical identifier)
- `repoPath` (e.g. `.` or `../nxt-Plugin-CoolantPlus`)
- `manifestPath` (e.g. `ui/plugin.json`)
- `required` (boolean)

## Baseline Build Automation

Use `dist/generate-plugin-dispatchers.sh`:

- Input 1: plugin catalog file path
- Input 2: staged `/sys` root path
- Reads each plugin manifest
- Filters only `data.nxt.tag == "nxt-plugin"` and enabled plugins
- Generates dispatchers in `/sys/nxt/plugins`:
  - `nxt-plugin-init-dispatch.g`
  - `nxt-plugin-daemon-dispatch.g`
  - `nxt-plugin-hooks-pause.g`
  - `nxt-plugin-hooks-resume.g`
  - `nxt-plugin-hooks-stop.g`
  - `nxt-plugin-hooks-cancel.g`

## External Repo Automation Concepts

For cross-repo plugin workflows:

- Validate sibling plugin repo exists (`../<repo-name>`)
- Validate manifest exists and contains required `data.nxt` fields
- Ensure macro entrypoint paths exist before generating dispatchers
- Optionally automate external branch creation only if branch does not exist

Suggested branch naming:

- `sync/next-plugin-loader-<plugin-id>-<shortsha>`

Branch safety checks:

- Verify remote branch does not already exist before creating
- Verify branch source is external repo `main` before committing automation changes

## Local build and test

Step-by-step local workflows (DWC paths, plugin ZIP, testing matrix) are in
[LOCAL_PLUGIN_BUILD_AND_TEST.md](LOCAL_PLUGIN_BUILD_AND_TEST.md).

## Acceptance Criteria for a New Plugin

A new plugin is considered nxt-compatible when:

- Metadata validates against required fields
- Required init macro exists in staged `/sys`
- Dispatcher generation succeeds without strict-mode errors
- `nxt-daemon.g` can invoke generated dispatchers
- Plugin init runs once and sets loaded flag
