#!/usr/bin/env bash
# Verify FreeCAD post-processor naming and staged artifact conventions.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

FAIL=0

fail() {
  echo "::error::$1" >&2
  FAIL=1
}

STAGE="${ROOT}/dist/stage-post-processors.sh"
FREECAD_SRC="${ROOT}/post-processors/freecad/nxt_post.py"

if [[ ! -f "${STAGE}" ]]; then
  fail "missing ${STAGE}"
fi
if [[ ! -f "${FREECAD_SRC}" ]]; then
  fail "missing ${FREECAD_SRC}"
fi

if ! grep -q 'FREECAD_PY_NAME="nxt-${BUILD_VERSION}_post.py"' "${STAGE}"; then
  fail "stage-post-processors.sh must set FREECAD_PY_NAME=nxt-\${BUILD_VERSION}_post.py"
fi
if ! grep -q 'F360_CPS_NAME="nxt-${BUILD_VERSION}-f360.cps"' "${STAGE}"; then
  fail "stage-post-processors.sh must set F360_CPS_NAME=nxt-\${BUILD_VERSION}-f360.cps"
fi
if ! grep -q 'post-processors/freecad/nxt_post.py' "${STAGE}"; then
  fail "stage-post-processors.sh must source post-processors/freecad/nxt_post.py"
fi
if ! grep -q 'post-processors/fusion-360/nxt.cps' "${STAGE}"; then
  fail "stage-post-processors.sh must source post-processors/fusion-360/nxt.cps"
fi

if ! grep -q 'POST_PREFIX = "nxt-{}".format(RELEASE.VERSION)' "${FREECAD_SRC}"; then
  fail "nxt_post.py must define POST_PREFIX = nxt-{VERSION}"
fi
if ! grep -q 'prog=POST_PREFIX' "${FREECAD_SRC}"; then
  fail "nxt_post.py argparse prog must use POST_PREFIX"
fi

LEGACY_HITS="$(rg -n 'next_post\.py|next\.cps|-post-freecad\.py' post-processors dist/stage-post-processors.sh 2>/dev/null \
  | grep -Ev '^dist/verify-post-processor-naming\.sh:' \
  || true)"
if [[ -n "${LEGACY_HITS}" ]]; then
  fail "legacy post-processor names (use nxt_* / _post.py)"
  echo "${LEGACY_HITS}" >&2
fi

if [[ "${FAIL}" -ne 0 ]]; then
  echo "verify-post-processor-naming: FAILED" >&2
  exit 1
fi

echo "verify-post-processor-naming: OK"
