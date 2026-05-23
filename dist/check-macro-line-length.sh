#!/usr/bin/env sh
# Fail if any RepRapFirmware macro line exceeds the G-code line length limit.
#
# RRF rejects long meta/G-code lines (typically >255 characters). Split conditions
# across multiple if blocks or use a var flag — see nxt.g MOS import gate.
#
# Usage (from repo root):
#   ./dist/check-macro-line-length.sh
#   ./dist/check-macro-line-length.sh path/to/macros
#
# Optional env: NXT_MACRO_MAX_LINE=255

set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MAX="${NXT_MACRO_MAX_LINE:-255}"
SEARCH_ROOT="${1:-${ROOT}/macros}"

FAILED=0
COUNT=0

if [ ! -d "$SEARCH_ROOT" ]; then
  echo "check-macro-line-length: not a directory: ${SEARCH_ROOT}" >&2
  exit 1
fi

for _f in $(find "$SEARCH_ROOT" -type f \( -name '*.g' -o -name '*.gcode' \) 2>/dev/null | LC_ALL=C sort); do
  _line_num=0
  while IFS= read -r _line || [ -n "$_line" ]; do
    _line_num=$((_line_num + 1))
    _len=$(printf '%s' "$_line" | wc -c)
    if [ "$_len" -gt "$MAX" ]; then
      echo "${_f}:${_line_num}: line length ${_len} exceeds ${MAX}"
      FAILED=1
      COUNT=$((COUNT + 1))
    fi
  done < "$_f"
done

if [ "$FAILED" -ne 0 ]; then
  echo "check-macro-line-length: ${COUNT} line(s) over ${MAX} characters" >&2
  exit 1
fi

echo "check-macro-line-length: OK (max ${MAX} chars)"
