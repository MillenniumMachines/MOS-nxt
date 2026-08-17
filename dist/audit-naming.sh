#!/usr/bin/env bash
# Regression guard: forbidden legacy branding and repo URLs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

FAIL=0

check_rg() {
  local label="$1"
  shift
  local hits
  hits="$(rg -n "$@" --glob '!.git' . 2>/dev/null \
    | grep -Ev '^(\./)?dist/(audit-naming\.sh|verify-nxt-plugin-contract\.mjs|verify-post-processor-naming\.sh):' \
    || true)"
  if [[ -n "${hits}" ]]; then
    echo "::error::${label}" >&2
    echo "${hits}" >&2
    FAIL=1
  fi
}

check_rg "Forbidden spelling (use nxt)" '\bNeXT\b'
check_rg "Old repo URL" 'github\.com/benagricola/NeXT|github\.com/MillenniumMachines/NeXT([^-]|$)'
check_rg "Wrong DWC plugin paths" \
  'src/plugins/NeXT|/NeXT/|NeXT\.vue|"id":\s*"NeXT"|dwcWebpackChunk":\s*"NeXT"'
check_rg "Retired tagline" 'Next-Gen Extended Tooling'
check_rg "Retired i18n namespace" 'plugins\.next'
check_rg "Legacy post-processor names" 'next_post\.py|next\.cps|-post-freecad\.py'

if [[ "${FAIL}" -ne 0 ]]; then
  echo "audit-naming: FAILED" >&2
  exit 1
fi

echo "audit-naming: OK"
