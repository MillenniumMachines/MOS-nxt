#!/usr/bin/env sh
# Fail if any git-tracked text file contains CR (CRLF).
#
# Usage (from repo root):
#   ./dist/check-line-endings.sh
#
# See .gitattributes (eol=lf) and .editorconfig.

set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
exec node dist/check-line-endings.mjs
