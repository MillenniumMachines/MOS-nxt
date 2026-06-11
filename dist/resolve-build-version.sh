#!/usr/bin/env bash
# Resolve nxt BUILD_VERSION from version branch or tag name.
#
# Usage (source from other scripts):
#   source dist/resolve-build-version.sh
#   # exports BUILD_VERSION, BUILD_REF, BUILD_SHA, NXT_REPO_ROOT
#
# BUILD_VERSION:
#   - Annotated tag (e.g. v0.6.0-beta.5, v0.6.0-rc1): full tag name
#   - Version branch (e.g. v0.6.0, v0.6.0-beta.13): release line (vM.m.p)
#
# Optional env:
#   NXT_BUILD_REF_OVERRIDE  — force ref (e.g. GITHUB_BASE_REF on PR CI)
#   NXT_PRINT_BUILD_VERSION=1 — print resolved values to stdout

set -euo pipefail

NXT_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

extract_release_line() {
  local ref="$1"
  local line
  line="$(printf '%s' "${ref}" | sed -n 's/^\(v[0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p')"
  if [[ -z "${line}" ]]; then
    echo "error: could not extract release line (vM.m.p) from ref: ${ref}" >&2
    return 1
  fi
  printf '%s' "${line}"
}

resolve_build_ref() {
  if [[ -n "${NXT_BUILD_REF_OVERRIDE:-}" ]]; then
    printf '%s' "${NXT_BUILD_REF_OVERRIDE}"
    return 0
  fi
  if [[ -n "${GITHUB_BASE_REF:-}" && "${GITHUB_EVENT_NAME:-}" == "pull_request" ]]; then
    printf '%s' "${GITHUB_BASE_REF}"
    return 0
  fi
  local branch
  branch="$(git -C "${NXT_REPO_ROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  if [[ -n "${branch}" && "${branch}" != "HEAD" ]]; then
    printf '%s' "${branch}"
    return 0
  fi
  local tag
  tag="$(git -C "${NXT_REPO_ROOT}" describe --tags --exact-match 2>/dev/null || true)"
  if [[ -n "${tag}" ]]; then
    printf '%s' "${tag}"
    return 0
  fi
  if [[ -n "${GITHUB_REF_NAME:-}" ]]; then
    printf '%s' "${GITHUB_REF_NAME}"
    return 0
  fi
  echo "error: could not resolve version branch or tag ref" >&2
  return 1
}

is_exact_tag_ref() {
  local ref="$1"
  local exact
  exact="$(git -C "${NXT_REPO_ROOT}" describe --tags --exact-match HEAD 2>/dev/null || true)"
  [[ -n "${exact}" && "${exact}" == "${ref}" ]]
}

RAW_BUILD_REF="$(resolve_build_ref)"

if [[ "${GITHUB_REF:-}" == refs/tags/* && -n "${GITHUB_REF_NAME:-}" ]]; then
  BUILD_REF="${GITHUB_REF_NAME}"
  BUILD_VERSION="${GITHUB_REF_NAME}"
elif is_exact_tag_ref "${RAW_BUILD_REF}"; then
  BUILD_REF="${RAW_BUILD_REF}"
  BUILD_VERSION="${RAW_BUILD_REF}"
else
  BUILD_REF="${RAW_BUILD_REF}"
  BUILD_VERSION="$(extract_release_line "${BUILD_REF}")"
fi
BUILD_SHA="$(git -C "${NXT_REPO_ROOT}" rev-parse --short HEAD)"

export BUILD_REF BUILD_VERSION BUILD_SHA NXT_REPO_ROOT

if [[ "${NXT_PRINT_BUILD_VERSION:-}" == "1" ]]; then
  echo "BUILD_REF=${BUILD_REF}"
  echo "BUILD_VERSION=${BUILD_VERSION}"
  echo "BUILD_SHA=${BUILD_SHA}"
fi
