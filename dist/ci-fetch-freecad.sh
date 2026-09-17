#!/usr/bin/env bash
# Fetch a pinned FreeCAD weekly AppImage and extract it for headless use.
#
# Usage:
#   ./dist/ci-fetch-freecad.sh [ref] [dest-dir]
#
# Ref defaults to ci/freecad-build-ref (e.g. weekly-2026.09.16). The literal
# "latest" resolves the newest weekly-* release instead, which is what the
# scheduled drift check uses. Dest defaults to ./freecad-build.
#
# The AppImage is extracted rather than mounted: ubuntu-latest ships no
# libfuse2, so running it directly fails with "Cannot mount AppImage".
#
# Prints the resolved ref on the last line, and appends freecad-ref= to
# GITHUB_OUTPUT when running under Actions so the cache key can use it.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REF="${1:-$(tr -d '[:space:]' < "${ROOT}/ci/freecad-build-ref")}"
DEST="${2:-${ROOT}/freecad-build}"
CACHE="${FREECAD_CACHE_DIR:-${ROOT}/.freecad-cache}"
API="https://api.github.com/repos/FreeCAD/FreeCAD/releases"

if [[ -z "${REF}" ]]; then
  echo "error: FreeCAD ref is empty (set ci/freecad-build-ref or pass ref argument)" >&2
  exit 1
fi

if [[ "${REF}" == "latest" ]]; then
  echo "ci-fetch-freecad: resolving newest weekly release..." >&2
  REF="$(curl -fsSL "${API}?per_page=50" \
    | python3 -c 'import json,sys
tags=[r["tag_name"] for r in json.load(sys.stdin) if r["tag_name"].startswith("weekly-")]
print(sorted(tags)[-1] if tags else "")')"
  if [[ -z "${REF}" ]]; then
    echo "error: could not resolve a weekly-* release from ${API}" >&2
    exit 1
  fi
  echo "ci-fetch-freecad: newest weekly is ${REF}" >&2
fi

VERSION="${REF#weekly-}"
ASSET="FreeCAD_weekly-${VERSION}-Linux-x86_64.AppImage"
URL="https://github.com/FreeCAD/FreeCAD/releases/download/${REF}/${ASSET}"

mkdir -p "${CACHE}"
APPIMAGE="${CACHE}/${ASSET}"

if [[ ! -f "${APPIMAGE}" ]]; then
  echo "ci-fetch-freecad: downloading ${ASSET} (~680MB)..." >&2
  curl -fsSL "${URL}" -o "${APPIMAGE}.part"
  mv "${APPIMAGE}.part" "${APPIMAGE}"
else
  echo "ci-fetch-freecad: using cached ${ASSET}" >&2
fi

# Every weekly publishes a matching -SHA256.txt; verify when we can reach it,
# but do not fail the run if only the checksum fetch breaks.
if SUMS="$(curl -fsSL "${URL}-SHA256.txt" 2>/dev/null)"; then
  EXPECTED="$(echo "${SUMS}" | awk '{print $1}' | head -1)"
  ACTUAL="$(sha256sum "${APPIMAGE}" | awk '{print $1}')"
  if [[ "${EXPECTED}" != "${ACTUAL}" ]]; then
    echo "error: checksum mismatch for ${ASSET}" >&2
    echo "  expected ${EXPECTED}" >&2
    echo "  actual   ${ACTUAL}" >&2
    rm -f "${APPIMAGE}"
    exit 1
  fi
  echo "ci-fetch-freecad: checksum OK" >&2
else
  echo "ci-fetch-freecad: warning: could not fetch checksum, skipping verification" >&2
fi

FREECADCMD="${DEST}/squashfs-root/usr/bin/freecadcmd"
if [[ ! -x "${FREECADCMD}" ]]; then
  echo "ci-fetch-freecad: extracting..." >&2
  rm -rf "${DEST}"
  mkdir -p "${DEST}"
  chmod +x "${APPIMAGE}"
  ( cd "${DEST}" && "${APPIMAGE}" --appimage-extract >/dev/null )
fi

if [[ ! -x "${FREECADCMD}" ]]; then
  echo "error: freecadcmd not found at ${FREECADCMD} after extraction" >&2
  exit 1
fi

echo "ci-fetch-freecad: FreeCAD ${REF} ready at ${FREECADCMD}" >&2
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "freecad-ref=${REF}" >> "${GITHUB_OUTPUT}"
  echo "freecadcmd=${FREECADCMD}" >> "${GITHUB_OUTPUT}"
fi
echo "${REF}"
