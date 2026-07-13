#!/usr/bin/env sh
# Fail if machine endstop-y.g hard-codes Scylla PD_14 without CDYv3 conditional (v0.6.0 line).
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
for f in "$ROOT"/macros/nxt-config/machine/*/endstop-y.g; do
  [ -f "$f" ] || continue
  rel="${f#"$ROOT"/}"
  if grep -q 'M574 Y.*PD_14' "$f" && ! grep -q 'scylla1_0_h723' "$f"; then
    echo "check-cdy-endstop-y: FAIL $rel — PD_14 without scylla1_0_h723 conditional" >&2
    fail=1
  fi
  if grep -q 'M574 Y.*PD_14' "$f" && ! grep -q 'PD_11' "$f"; then
    echo "check-cdy-endstop-y: FAIL $rel — PD_14 without CDYv3 PD_11 branch" >&2
    fail=1
  fi
done
if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "check-cdy-endstop-y: OK"
