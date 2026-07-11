#!/usr/bin/env bash
# Symlink MOS-nxt/ui into DuetWebControl for dwc dev / built-in plugin load.
#
# DWC 3.7+ discovers builtins via vite/dwc-plugins (virtual:dwc-builtin-plugins) —
# a symlink under src/plugins/nxt is enough; restart `npm run dev` after linking.
# DWC 3.6.x also needs src/plugins/imports.ts regenerated when that file exists.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DWC="${1:-${ROOT}/../DuetWebControl}"
LINK="${DWC}/src/plugins/nxt"
TARGET="${ROOT}/ui"

if [[ ! -d "${DWC}/src/plugins" ]]; then
  echo "error: ${DWC}/src/plugins not found" >&2
  exit 1
fi
if [[ ! -f "${TARGET}/plugin.json" ]]; then
  echo "error: ${TARGET}/plugin.json not found" >&2
  exit 1
fi

if [[ -e "${LINK}" && ! -L "${LINK}" ]]; then
  echo "error: ${LINK} exists and is not a symlink" >&2
  exit 1
fi

ln -sfn "${TARGET}" "${LINK}"
if [[ -f "${DWC}/src/plugins/imports.ts" ]]; then
  node "${ROOT}/dist/regenerate-dwc-plugin-imports.cjs" "${DWC}"
else
  echo "DWC Vite builtins: symlink only (no imports.ts) — restart npm run dev to pick up nxt."
fi
echo "Symlink: ${LINK} -> ${TARGET}"
echo "Restart dwc dev server (npm run dev) after changing plugin sources."
