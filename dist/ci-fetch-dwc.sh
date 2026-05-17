#!/usr/bin/env bash
# Fetch a pinned DuetWebControl source tree for CI/local builds without cloning
# or writing to the upstream GitHub repository (read-only release tarball).
#
# Usage:
#   ./dist/ci-fetch-dwc.sh [ref] [dest-dir]
#
# Ref defaults to ci/dwc-build-ref (e.g. v3.6.2). Dest defaults to ./dwc-build.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REF="${1:-$(tr -d '[:space:]' < "${ROOT}/ci/dwc-build-ref")}"
DEST="${2:-${ROOT}/dwc-build}"

if [[ -z "${REF}" ]]; then
  echo "error: DWC ref is empty (set ci/dwc-build-ref or pass ref argument)" >&2
  exit 1
fi

mkdir -p "${DEST}"
DEST="$(cd "${DEST}" && pwd)"

if [[ -f "${DEST}/package.json" ]]; then
  echo "ci-fetch-dwc: using existing DWC tree at ${DEST}"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

archive_name="DuetWebControl-${REF#v}"
if [[ "${REF}" == v* ]]; then
  URL="https://github.com/Duet3D/DuetWebControl/archive/refs/tags/${REF}.tar.gz"
else
  URL="https://github.com/Duet3D/DuetWebControl/archive/refs/heads/${REF}.tar.gz"
  archive_name="DuetWebControl-${REF}"
fi

echo "ci-fetch-dwc: downloading read-only DWC ${REF} from GitHub archive..."
curl -fsSL "${URL}" -o "${TMP}/dwc.tar.gz"

tar -xzf "${TMP}/dwc.tar.gz" -C "${TMP}"
extracted="${TMP}/${archive_name}"
if [[ ! -d "${extracted}" ]]; then
  extracted="$(find "${TMP}" -mindepth 1 -maxdepth 1 -type d | head -1)"
fi
if [[ ! -f "${extracted}/package.json" ]]; then
  echo "error: extracted DWC tree missing package.json (${extracted})" >&2
  exit 1
fi

rm -rf "${DEST}"
mkdir -p "$(dirname "${DEST}")"
mv "${extracted}" "${DEST}"
echo "ci-fetch-dwc: DWC ${REF} ready at ${DEST} (no git remote; upstream repo not modified)"
