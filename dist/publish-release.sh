#!/usr/bin/env bash
# Publish a NeXT release line to origin: push the maintenance branch and an annotated tag.
#
# Gates (see .cursor/rules/release-plugin-verify.mdc):
#   - clean git working tree
#   - ./dist/build-plugin.sh (unless --skip-build)
#   - interactive DWC load/smoke-test confirmation (unless --yes-dwc)
#
# Pushing the tag triggers CI (.github/workflows/release.yml) to build release assets.
#
# Usage:
#   ./dist/publish-release.sh <version> [options]
#
# Examples:
#   ./dist/publish-release.sh v0.6.0 --source kadders/v0.6.0
#   ./dist/publish-release.sh v0.6.0 --dwc-path ../DuetWebControl
#   ./dist/publish-release.sh v0.6.0-beta.5 --source HEAD --skip-branch
#   ./dist/publish-release.sh v0.6.0 --dry-run
#
# Options:
#   --source <ref>       Commit to publish (default: local branch matching <version>)
#   --remote <name>      Remote to push to (default: origin)
#   --dwc-path <path>    DuetWebControl tree for build-plugin.sh (default: ../DuetWebControl)
#   --skip-build         Skip ./dist/build-plugin.sh
#   --skip-branch        Do not push refs/heads/<version>
#   --skip-tag           Do not create or push the annotated tag
#   --yes-dwc            Skip manual DWC verification prompt (use only after real smoke-test)
#   --force-tag          Allow moving an existing stable tag (refuses for stable without this flag)
#   --dry-run            Print actions without mutating git remotes or creating tags
#   -h, --help           Show this help

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

VERSION=""
SOURCE_REF=""
REMOTE="origin"
DWC_PATH="${ROOT}/../DuetWebControl"
SKIP_BUILD=false
SKIP_BRANCH=false
SKIP_TAG=false
YES_DWC=false
FORCE_TAG=false
DRY_RUN=false

usage() {
  sed -n '2,28p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

die() {
  echo "error: $*" >&2
  exit 1
}

run() {
  if [[ "${DRY_RUN}" == true ]]; then
    printf '[dry-run]'; printf ' %q' "$@"; printf '\n'
  else
    "$@"
  fi
}

confirm() {
  local prompt="$1"
  if [[ "${YES_DWC}" == true ]]; then
    return 0
  fi
  printf '%s [y/N] ' "${prompt}"
  local answer
  read -r answer
  case "${answer}" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

normalize_version() {
  local raw="$1"
  if [[ "${raw}" != v* ]]; then
    printf 'v%s' "${raw}"
  else
    printf '%s' "${raw}"
  fi
}

is_stable_version() {
  local ver="$1"
  [[ "${ver}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

is_beta_version() {
  local ver="$1"
  [[ "${ver}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+-beta\.[0-9]+$ ]]
}

validate_version() {
  local ver="$1"
  if is_stable_version "${ver}" || is_beta_version "${ver}"; then
    return 0
  fi
  die "unsupported version format: ${ver} (expected vMAJOR.MINOR.PATCH or vMAJOR.MINOR.PATCH-beta.N)"
}

resolve_source_ref() {
  local ver="$1"
  if [[ -n "${SOURCE_REF}" ]]; then
    printf '%s' "${SOURCE_REF}"
    return
  fi
  if git show-ref --verify --quiet "refs/heads/${ver}"; then
    printf '%s' "${ver}"
    return
  fi
  if git show-ref --verify --quiet "refs/remotes/origin/${ver}"; then
    printf '%s' "origin/${ver}"
    return
  fi
  if git show-ref --verify --quiet "refs/remotes/kadders/${ver}"; then
    printf '%s' "kadders/${ver}"
    return
  fi
  die "no --source given and no local/origin/kadders ref named ${ver}"
}

tag_exists() {
  local tag="$1"
  git rev-parse "refs/tags/${tag}" >/dev/null 2>&1
}

remote_tag_sha() {
  local tag="$1"
  local peeled
  peeled="$(git ls-remote "${REMOTE}" "refs/tags/${tag}^{}" 2>/dev/null | awk '{print $1}' | head -n1)"
  if [[ -n "${peeled}" ]]; then
    printf '%s' "${peeled}"
    return
  fi
  git ls-remote "${REMOTE}" "refs/tags/${tag}" 2>/dev/null | awk '{print $1}' | head -n1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --source)
      SOURCE_REF="${2:?--source requires a ref}"
      shift 2
      ;;
    --remote)
      REMOTE="${2:?--remote requires a name}"
      shift 2
      ;;
    --dwc-path)
      DWC_PATH="${2:?--dwc-path requires a path}"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=true
      shift
      ;;
    --skip-branch)
      SKIP_BRANCH=true
      shift
      ;;
    --skip-tag)
      SKIP_TAG=true
      shift
      ;;
    --yes-dwc)
      YES_DWC=true
      shift
      ;;
    --force-tag)
      FORCE_TAG=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    v[0-9]*|[0-9]*)
      if [[ -n "${VERSION}" ]]; then
        die "unexpected extra argument: $1"
      fi
      VERSION="$(normalize_version "$1")"
      shift
      ;;
    *)
      die "unknown option: $1 (try --help)"
      ;;
  esac
done

[[ -n "${VERSION}" ]] || { usage >&2; die "version argument required"; }
validate_version "${VERSION}"

if [[ "${SKIP_BRANCH}" == true && "${SKIP_TAG}" == true ]]; then
  die "nothing to do: both --skip-branch and --skip-tag are set"
fi

if ! git remote get-url "${REMOTE}" >/dev/null 2>&1; then
  die "git remote not found: ${REMOTE}"
fi

if [[ -n "$(git status --porcelain)" ]]; then
  die "working tree is not clean; commit or stash changes first"
fi

SOURCE_REF="$(resolve_source_ref "${VERSION}")"
COMMIT_SHA="$(git rev-parse "${SOURCE_REF}^{commit}")"
COMMIT_SUBJECT="$(git log -1 --format='%s' "${COMMIT_SHA}")"

echo "NeXT publish-release"
echo "  version:     ${VERSION}"
echo "  source:      ${SOURCE_REF} (${COMMIT_SHA})"
echo "  subject:     ${COMMIT_SUBJECT}"
echo "  remote:      ${REMOTE} ($(git remote get-url "${REMOTE}"))"
echo "  skip build:  ${SKIP_BUILD}"
echo "  skip branch: ${SKIP_BRANCH}"
echo "  skip tag:    ${SKIP_TAG}"
echo "  dry run:     ${DRY_RUN}"
echo

run git fetch "${REMOTE}" --tags

if [[ "${SOURCE_REF}" == kadders/* || "${SOURCE_REF}" == */kadders/* ]]; then
  if git remote get-url kadders >/dev/null 2>&1; then
    run git fetch kadders --tags
  fi
fi

if ! git cat-file -e "${COMMIT_SHA}^{commit}" 2>/dev/null; then
  die "cannot resolve commit for ${SOURCE_REF}"
fi

if [[ "${SKIP_BUILD}" == false ]]; then
  echo "Running build gate: ./dist/build-plugin.sh"
  if [[ "${DRY_RUN}" == true ]]; then
    run "${ROOT}/dist/build-plugin.sh" "${DWC_PATH}"
  else
    "${ROOT}/dist/build-plugin.sh" "${DWC_PATH}"
  fi
  echo "build-plugin.sh finished OK"
  echo
else
  echo "Skipping build-plugin.sh (--skip-build)"
  echo
fi

if ! confirm "Plugin built and manually verified in DWC (install ZIP, start plugin, smoke-test)?"; then
  die "aborted: confirm DWC verification or pass --yes-dwc after testing"
fi

if [[ "${SKIP_BRANCH}" == false ]]; then
  REMOTE_BRANCH_SHA="$(git ls-remote "${REMOTE}" "refs/heads/${VERSION}" 2>/dev/null | awk '{print $1}' | head -n1 || true)"
  if [[ -n "${REMOTE_BRANCH_SHA}" && "${REMOTE_BRANCH_SHA}" == "${COMMIT_SHA}" ]]; then
    echo "Branch ${VERSION} on ${REMOTE} already at ${COMMIT_SHA}; skipping branch push"
  else
    if [[ -n "${REMOTE_BRANCH_SHA}" && "${REMOTE_BRANCH_SHA}" != "${COMMIT_SHA}" ]]; then
      echo "Updating ${REMOTE}/${VERSION}: ${REMOTE_BRANCH_SHA:0:7} -> ${COMMIT_SHA:0:7}"
    else
      echo "Creating ${REMOTE}/${VERSION} at ${COMMIT_SHA:0:7}"
    fi
    run git push "${REMOTE}" "${COMMIT_SHA}:refs/heads/${VERSION}"
  fi
  echo
fi

if [[ "${SKIP_TAG}" == false ]]; then
  if tag_exists "${VERSION}" && [[ "${FORCE_TAG}" == false ]]; then
    LOCAL_TAG_SHA="$(git rev-parse "refs/tags/${VERSION}^{commit}")"
    if [[ "${LOCAL_TAG_SHA}" == "${COMMIT_SHA}" ]]; then
      echo "Annotated tag ${VERSION} already points at ${COMMIT_SHA}"
    else
      die "local tag ${VERSION} exists at ${LOCAL_TAG_SHA:0:7}; use --force-tag to move it"
    fi
  fi

  REMOTE_TAG_COMMIT="$(remote_tag_sha "${VERSION}")"
  if [[ -n "${REMOTE_TAG_COMMIT}" ]]; then
    if [[ "${REMOTE_TAG_COMMIT}" == "${COMMIT_SHA}" ]]; then
      echo "Tag ${VERSION} on ${REMOTE} already at ${COMMIT_SHA}"
    elif is_stable_version "${VERSION}" && [[ "${FORCE_TAG}" == false ]]; then
      die "stable tag ${VERSION} exists on ${REMOTE} at ${REMOTE_TAG_COMMIT:0:7}; refusing to move without --force-tag"
    elif [[ "${FORCE_TAG}" == false ]]; then
      die "tag ${VERSION} exists on ${REMOTE} at ${REMOTE_TAG_COMMIT:0:7}; use --force-tag to replace"
    else
      echo "warning: moving existing tag ${VERSION} on ${REMOTE}"
    fi
  fi

  if ! tag_exists "${VERSION}" || [[ "${FORCE_TAG}" == true ]]; then
    TAG_MSG="NeXT ${VERSION}"
    if is_beta_version "${VERSION}"; then
      TAG_MSG="NeXT ${VERSION} pre-release"
    fi
    if tag_exists "${VERSION}" && [[ "${FORCE_TAG}" == true ]]; then
      run git tag -f -a "${VERSION}" -m "${TAG_MSG}" "${COMMIT_SHA}"
    else
      run git tag -a "${VERSION}" -m "${TAG_MSG}" "${COMMIT_SHA}"
    fi
  fi

  if [[ "${FORCE_TAG}" == true ]]; then
    run git push --force "${REMOTE}" "refs/tags/${VERSION}"
  else
    run git push "${REMOTE}" "refs/tags/${VERSION}"
  fi
  echo
fi

echo "Done."
if [[ "${SKIP_TAG}" == false && "${DRY_RUN}" == false ]]; then
  echo "CI should run on tag push; draft release: NeXT ${VERSION} on GitHub."
fi
