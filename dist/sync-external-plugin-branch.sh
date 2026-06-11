#!/usr/bin/env bash
set -euo pipefail

# Draft helper for external plugin automation.
# Creates a synchronization branch in an external plugin repo only if it does not already exist.
#
# Usage:
#   ./dist/sync-external-plugin-branch.sh <plugin-repo-path> <plugin-id> <source-sha>
#
# Example:
#   ./dist/sync-external-plugin-branch.sh ../nxt-Plugin-CoolantPlus next-coolant-plus abc12345

PLUGIN_REPO_PATH="${1:?plugin repo path required}"
PLUGIN_ID="${2:?plugin id required}"
SOURCE_SHA="${3:?source sha required}"

if [[ ! -d "${PLUGIN_REPO_PATH}" ]]; then
  echo "error: plugin repo path not found: ${PLUGIN_REPO_PATH}" >&2
  exit 1
fi

BRANCH_NAME="sync/next-plugin-loader-${PLUGIN_ID}-${SOURCE_SHA:0:8}"

git -C "${PLUGIN_REPO_PATH}" fetch origin main

if git -C "${PLUGIN_REPO_PATH}" ls-remote --exit-code --heads origin "${BRANCH_NAME}" >/dev/null 2>&1; then
  echo "branch already exists, skipping: ${BRANCH_NAME}"
  exit 0
fi

git -C "${PLUGIN_REPO_PATH}" checkout main
git -C "${PLUGIN_REPO_PATH}" pull --ff-only origin main
git -C "${PLUGIN_REPO_PATH}" checkout -b "${BRANCH_NAME}"

echo "created branch: ${BRANCH_NAME}"
echo "next step: apply plugin loader updates, commit, and open PR"
