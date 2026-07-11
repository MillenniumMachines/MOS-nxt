#!/usr/bin/env bash
# Require a Node.js version that can run DWC 3.7 Vite / rolldown plugin builds.
#
# Rolldown (DWC 3.7) engines: ^20.19.0 || >=22.12.0
# Symptom on older Node (e.g. Ubuntu Node 18): SyntaxError —
#   The requested module 'node:util' does not provide an export named 'styleText'
#
# Usage:
#   ./dist/check-node-for-dwc-build.sh
#   NODE_BIN=/path/to/node22 ./dist/check-node-for-dwc-build.sh
#
# Exit 0 when OK; exit 1 with a fix hint when not.

set -euo pipefail

NODE_BIN="${NODE_BIN:-$(command -v node || true)}"
if [[ -z "${NODE_BIN}" ]]; then
  echo "error: node not found on PATH" >&2
  exit 1
fi

NODE_VER="$("${NODE_BIN}" -p "process.versions.node" 2>/dev/null || true)"
if [[ -z "${NODE_VER}" ]]; then
  echo "error: could not read Node version from ${NODE_BIN}" >&2
  exit 1
fi

if ! "${NODE_BIN}" -e '
const [maj, min] = process.versions.node.split(".").map(Number);
const ok =
  (maj === 20 && min >= 19) ||
  (maj === 22 && min >= 12) ||
  maj >= 23;
process.exit(ok ? 0 : 1);
'; then
  echo "error: Node ${NODE_VER} at ${NODE_BIN} is too old for DWC 3.7 Vite/rolldown builds" >&2
  echo "  Required: Node ^20.19.0 or >=22.12.0 (Node 22 LTS recommended)" >&2
  echo "  Symptom if ignored: SyntaxError: node:util has no export named 'styleText'" >&2
  echo "  Fix (pick one):" >&2
  echo "    - Install Node 22 LTS (nvm/fnm/nodesource); ensure \`which node\` is not system Node 18" >&2
  echo "    - Or: NODE_BIN=/path/to/node22 ./dist/build-plugin.sh ../DuetWebControl" >&2
  exit 1
fi

maj="$("${NODE_BIN}" -p "process.versions.node.split('.')[0]")"
if [[ "${maj}" == "21" ]]; then
  echo "warning: Node ${NODE_VER} is untested for DWC 3.7; prefer Node 22 LTS" >&2
fi

echo "check-node-for-dwc-build: OK (Node ${NODE_VER} @ ${NODE_BIN})"
