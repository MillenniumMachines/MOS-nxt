#!/usr/bin/env bash
# Ensure the DWC tree used for build-plugin.sh matches ci/dwc-build-ref (version skew gate).
#
# Usage: ./dist/verify-dwc-build-alignment.sh [path-to-DuetWebControl]
#
# Exit 0 when package.json version matches the pin (e.g. ci/dwc-build-ref = v3.6.2 → DWC 3.6.2).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DWC_PATH="${1:-${ROOT}/../DuetWebControl}"
REF_FILE="${ROOT}/ci/dwc-build-ref"

if [[ ! -f "${REF_FILE}" ]]; then
  echo "error: missing ${REF_FILE}" >&2
  exit 1
fi
if [[ ! -f "${DWC_PATH}/package.json" ]]; then
  echo "error: no package.json in DWC tree: ${DWC_PATH}" >&2
  exit 1
fi

PIN_REF="$(tr -d '[:space:]' < "${REF_FILE}")"
PIN_VER="${PIN_REF#v}"
DWC_VER="$(jq -r '.version' "${DWC_PATH}/package.json")"

if [[ -z "${PIN_VER}" || -z "${DWC_VER}" || "${DWC_VER}" == "null" ]]; then
  echo "error: could not read versions (pin=${PIN_REF}, dwc=${DWC_VER})" >&2
  exit 1
fi

echo "verify-dwc-build-alignment: pin ${PIN_REF} → DWC package.json ${DWC_VER}"

if [[ "${PIN_VER}" != "${DWC_VER}" ]]; then
  echo "error: DWC tree version skew — build DWC is ${DWC_VER} but ci/dwc-build-ref expects ${PIN_VER}" >&2
  echo "  Fix: use DWC at ${PIN_REF}, or update ci/dwc-build-ref + docs and rebuild the plugin." >&2
  exit 1
fi

echo "verify-dwc-build-alignment: OK"
