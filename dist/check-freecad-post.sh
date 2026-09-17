#!/usr/bin/env bash
# Post every FreeCAD test case headlessly and compare against its golden G-code.
#
# Usage:
#   ./dist/check-freecad-post.sh            # verify against goldens
#   ./dist/check-freecad-post.sh --update   # regenerate goldens after an
#                                           # intentional post change
#
# Cases live in post-processors/freecad/tests/cases.tsv, one per line:
#   <fixture.FCStd>  <job label>  <machine .fcm>  <golden .gcode>
# with paths relative to post-processors/freecad/ and fields tab-separated.
#
# Each case is checked twice:
#
#   1. Semantically (tools/compare_gcode.py) over the motion stream. The header
#      carries an absolute project path and a wall-clock timestamp that differ
#      between a developer's machine and the runner, so compare_gcode.py drops
#      comments entirely.
#   2. Structurally, over the comment stream, with those two volatile lines
#      filtered out.
#
# The second check exists because the first cannot see comments at all. When
# upstream removed _optimize_gcode() this post's (NXT-MODAL-BARRIER) sentinel
# leaked into every posted file, and a comment-blind comparison reports that as
# clean -- verified, not assumed. The leak was harmless (RRF discards comments)
# but it is exactly the kind of silent drift this workflow exists to catch.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FC_DIR="${ROOT}/post-processors/freecad"
CASES="${FC_DIR}/tests/cases.tsv"
POST_CLI="${FC_DIR}/tools/post_cli.py"
COMPARE="${FC_DIR}/tools/compare_gcode.py"

UPDATE=0
[[ "${1:-}" == "--update" ]] && UPDATE=1

if [[ -z "${FREECADCMD:-}" ]]; then
  CANDIDATE="${ROOT}/freecad-build/squashfs-root/usr/bin/freecadcmd"
  if [[ -x "${CANDIDATE}" ]]; then
    export FREECADCMD="${CANDIDATE}"
  else
    echo "::error::no FreeCAD found; run dist/ci-fetch-freecad.sh or set FREECADCMD" >&2
    exit 1
  fi
fi

if [[ ! -f "${CASES}" ]]; then
  echo "::error::missing ${CASES}" >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

# Comment lines that should be identical between any two runs of the same case.
# The project path is absolute and the timestamp is wall-clock, so both differ
# between a developer's machine and the runner; everything else is post output.
stable_comments() {
  grep '^(' "$1" | grep -vE '^\((Project File|Output Time):' || true
}

FAIL=0
RAN=0

while IFS=$'\t' read -r fixture job machine golden; do
  # Skip blanks and comments.
  [[ -z "${fixture// }" || "${fixture}" == \#* ]] && continue
  RAN=$((RAN + 1))

  FIXTURE_PATH="${FC_DIR}/${fixture}"
  MACHINE_PATH="${FC_DIR}/${machine}"
  GOLDEN_PATH="${FC_DIR}/${golden}"
  ACTUAL="${TMP}/$(basename "${golden}")"

  for required in "${FIXTURE_PATH}" "${MACHINE_PATH}"; do
    if [[ ! -f "${required}" ]]; then
      echo "::error::missing ${required}" >&2
      FAIL=1
      continue 2
    fi
  done

  echo "--- ${fixture} [${job}] via $(basename "${machine}")"
  if ! "${POST_CLI}" "${FIXTURE_PATH}" -j "${job}" -M "${MACHINE_PATH}" -o "${ACTUAL}" >/dev/null; then
    echo "::error::post failed for ${fixture} [${job}]" >&2
    FAIL=1
    continue
  fi

  if [[ "${UPDATE}" -eq 1 ]]; then
    mkdir -p "$(dirname "${GOLDEN_PATH}")"
    cp "${ACTUAL}" "${GOLDEN_PATH}"
    echo "    updated ${golden}"
    continue
  fi

  if [[ ! -f "${GOLDEN_PATH}" ]]; then
    echo "::error::missing golden ${golden} (run dist/check-freecad-post.sh --update)" >&2
    FAIL=1
    continue
  fi

  CASE_FAIL=0

  if ! "${COMPARE}" "${GOLDEN_PATH}" "${ACTUAL}"; then
    echo "::error::G-code changed for ${fixture} [${job}] vs ${golden}" >&2
    CASE_FAIL=1
  fi

  if ! COMMENT_DIFF="$(diff <(stable_comments "${GOLDEN_PATH}") \
                            <(stable_comments "${ACTUAL}"))"; then
    echo "::error::comments changed for ${fixture} [${job}] vs ${golden}" >&2
    echo "${COMMENT_DIFF}" >&2
    CASE_FAIL=1
  fi

  if [[ "${CASE_FAIL}" -eq 0 ]]; then
    echo "    OK"
  else
    # Keep the actual output so the workflow can attach it for inspection.
    mkdir -p "${ROOT}/freecad-post-actual"
    cp "${ACTUAL}" "${ROOT}/freecad-post-actual/"
    FAIL=1
  fi
done < "${CASES}"

if [[ "${RAN}" -eq 0 ]]; then
  echo "::error::no cases in ${CASES}" >&2
  exit 1
fi

if [[ "${FAIL}" -ne 0 ]]; then
  echo "check-freecad-post: FAILED (${RAN} case(s) run)" >&2
  exit 1
fi

echo "check-freecad-post: OK (${RAN} case(s))"
