#!/usr/bin/env bash
# Build the NeXT DWC plugin only (no full SD release zip).
# Run from anywhere; paths are resolved from this script's location.
#
# Usage:
#   ./dist/build-plugin.sh [path-to-DuetWebControl]
#   ./dist/build-plugin.sh --clean-only [path-to-DuetWebControl]
#
# Default DWC path: <NeXT-repo>/../DuetWebControl
#
# Output: dist/nxt-<ref>-<sha>[-dirty].zip
#
# Artifact cleanup runs automatically before staging and npm/webpack (not after the build).
# --clean-only removes artifacts and exits. --clean is accepted as a no-op for backwards compatibility.
#
# Cleanup removes:
#   - DuetWebControl/dist/          (webpack output: js/, css/, zips from last build)
#   - DuetWebControl/src/plugins/NeXT/  (staged plugin tree if a prior build stopped early)
#   - DuetWebControl/node_modules/.cache/ (vue-cli / webpack cache; optional but helps stale chunks)
#   - DuetWebControl/scripts/build-plugin.js.next-bak (leftover if a build was interrupted)
#   - NeXT/dist/nxt-*.zip        (previous plugin zip outputs only; other files under dist/ are kept)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${ROOT}/dist"

CLEAN_ONLY=false
REMAINING=()
for arg in "$@"; do
  case "${arg}" in
    --clean-only)
      CLEAN_ONLY=true
      ;;
    --clean)
      ;; # no-op: cleanup always runs before each build
    *)
      REMAINING+=("${arg}")
      ;;
  esac
done

DWC_REPO_PATH="${REMAINING[0]:-${ROOT}/../DuetWebControl}"

sanitize_ref() {
  local raw="$1"
  printf '%s' "${raw}" | sed 's/[^A-Za-z0-9._-]/-/g'
}

clean_next_plugin_artifacts() {
  local dwc="$1"
  echo "NeXT plugin artifact cleanup (DWC: ${dwc})"
  if [[ -d "${dwc}/dist" ]]; then
    echo "  rm -rf ${dwc}/dist"
    rm -rf "${dwc}/dist"
  else
    echo "  (skip) no ${dwc}/dist"
  fi
  if [[ -d "${dwc}/src/plugins/NeXT" ]]; then
    echo "  rm -rf ${dwc}/src/plugins/NeXT"
    rm -rf "${dwc}/src/plugins/NeXT"
  else
    echo "  (skip) no ${dwc}/src/plugins/NeXT"
  fi
  local bak="${dwc}/scripts/build-plugin.js.next-bak"
  if [[ -f "${bak}" ]]; then
    echo "  rm -f ${bak}"
    rm -f "${bak}"
  fi
  if [[ -d "${dwc}/node_modules/.cache" ]]; then
    echo "  rm -rf ${dwc}/node_modules/.cache"
    rm -rf "${dwc}/node_modules/.cache"
  else
    echo "  (skip) no ${dwc}/node_modules/.cache"
  fi
  mkdir -p "${OUT_DIR}"
  local found_zip=false
  shopt -s nullglob
  for z in "${OUT_DIR}"/nxt-*.zip "${OUT_DIR}"/NeXT-*.zip; do
    echo "  rm -f ${z}"
    rm -f "${z}"
    found_zip=true
  done
  shopt -u nullglob
  if [[ "${found_zip}" == false ]]; then
    echo "  (skip) no ${OUT_DIR}/nxt-*.zip"
  fi
  echo "Cleanup finished."
}

if [[ ! -d "${DWC_REPO_PATH}" ]]; then
  echo "error: DuetWebControl repository not found at ${DWC_REPO_PATH}" >&2
  exit 1
fi

chmod +x "${ROOT}/dist/verify-dwc-build-alignment.sh"
"${ROOT}/dist/verify-dwc-build-alignment.sh" "${DWC_REPO_PATH}"

clean_next_plugin_artifacts "${DWC_REPO_PATH}"

if [[ "${CLEAN_ONLY}" == true ]]; then
  exit 0
fi

if [[ ! -f "${ROOT}/ui/plugin.json" ]]; then
  echo "error: ${ROOT}/ui/plugin.json not found" >&2
  exit 1
fi

echo "Checking RRF macro line lengths (max 200)..."
node "${ROOT}/dist/check-gcode-line-length.mjs" || exit 1

TMP_DIR="$(mktemp -d -t next-plugin-build-XXXXX)"

# shellcheck source=dist/resolve-build-version.sh
source "${ROOT}/dist/resolve-build-version.sh"

if git -C "${ROOT}" diff-index --quiet HEAD --; then
  DIRTY_SUFFIX=""
else
  DIRTY_SUFFIX="-dirty"
fi

# Embedded %%NXT_VERSION%% uses release line (e.g. v0.6.0); zip basename includes ref+sha for uniqueness.
DWC_PLUGIN_ZIP="NeXT-${BUILD_VERSION}.zip"
OUT_ZIP="nxt-$(sanitize_ref "${BUILD_REF}")-${BUILD_SHA}${DIRTY_SUFFIX}.zip"
echo "nxt plugin build: embedded version ${BUILD_VERSION} (ref ${BUILD_REF}, zip ${OUT_ZIP})"
BUILD_PLUGIN_JS="${DWC_REPO_PATH}/scripts/build-plugin.js"

plugin_build_exit() {
  if [[ -f "${BUILD_PLUGIN_JS}.next-bak" ]]; then
    mv -f "${BUILD_PLUGIN_JS}.next-bak" "${BUILD_PLUGIN_JS}"
  fi
  rm -rf "${TMP_DIR}"
}
trap plugin_build_exit EXIT

generate_nxt_plugin_dispatchers() {
  local plugin_json="${TMP_DIR}/plugin.json"
  local plugin_dir="${TMP_DIR}/sd/sys/nxt/plugins"
  local init_dispatch="${plugin_dir}/nxt-plugin-init-dispatch.g"
  local daemon_dispatch="${plugin_dir}/nxt-plugin-daemon-dispatch.g"
  local pause_dispatch="${plugin_dir}/nxt-plugin-hooks-pause.g"
  local resume_dispatch="${plugin_dir}/nxt-plugin-hooks-resume.g"
  local stop_dispatch="${plugin_dir}/nxt-plugin-hooks-stop.g"
  local cancel_dispatch="${plugin_dir}/nxt-plugin-hooks-cancel.g"

  mkdir -p "${plugin_dir}"

  cat > "${init_dispatch}" <<'EOF'
; Auto-generated. Do not edit.
; NeXT plugin init dispatcher
EOF
  cat > "${daemon_dispatch}" <<'EOF'
; Auto-generated. Do not edit.
; NeXT plugin daemon dispatcher
EOF
  cat > "${pause_dispatch}" <<'EOF'
; Auto-generated. Do not edit.
; NeXT plugin pause hooks dispatcher
EOF
  cat > "${resume_dispatch}" <<'EOF'
; Auto-generated. Do not edit.
; NeXT plugin resume hooks dispatcher
EOF
  cat > "${stop_dispatch}" <<'EOF'
; Auto-generated. Do not edit.
; NeXT plugin stop hooks dispatcher
EOF
  cat > "${cancel_dispatch}" <<'EOF'
; Auto-generated. Do not edit.
; NeXT plugin cancel hooks dispatcher
EOF

  if ! jq -e '.data.nxt.tag == "nxt-plugin" and (.data.nxt.enabled // true)' "${plugin_json}" >/dev/null 2>&1; then
    echo "; no plugins tagged nxt-plugin" >> "${init_dispatch}"
    echo "; no plugins tagged nxt-plugin" >> "${daemon_dispatch}"
    echo "; no plugins tagged nxt-plugin" >> "${pause_dispatch}"
    echo "; no plugins tagged nxt-plugin" >> "${resume_dispatch}"
    echo "; no plugins tagged nxt-plugin" >> "${stop_dispatch}"
    echo "; no plugins tagged nxt-plugin" >> "${cancel_dispatch}"
    return 0
  fi

  local plugin_id plugin_global failure_mode
  plugin_id="$(jq -r '.id' "${plugin_json}")"
  plugin_global="$(jq -r '.id | ascii_downcase | gsub("[^a-z0-9]+"; "_")' "${plugin_json}")"
  failure_mode="$(jq -r '.data.nxt.failureMode // "soft"' "${plugin_json}")"

  local init_path daemon_path pause_path resume_path stop_path cancel_path
  init_path="$(jq -r '.data.nxt.entrypoints.init // empty' "${plugin_json}")"
  daemon_path="$(jq -r '.data.nxt.entrypoints.daemon // empty' "${plugin_json}")"
  pause_path="$(jq -r '.data.nxt.entrypoints.pause // empty' "${plugin_json}")"
  resume_path="$(jq -r '.data.nxt.entrypoints.resume // empty' "${plugin_json}")"
  stop_path="$(jq -r '.data.nxt.entrypoints.stop // empty' "${plugin_json}")"
  cancel_path="$(jq -r '.data.nxt.entrypoints.cancel // empty' "${plugin_json}")"

  append_hook() {
    local target_file="$1"
    local hook_path="$2"
    local event_name="$3"
    if [[ -z "${hook_path}" ]]; then
      return 0
    fi
    if [[ ! -f "${TMP_DIR}/sd/sys/${hook_path}" ]]; then
      if [[ "${failure_mode}" == "strict" ]]; then
        echo "error: missing ${event_name} entrypoint for ${plugin_id}: ${hook_path}" >&2
        exit 1
      fi
      echo "warning: missing ${event_name} entrypoint for ${plugin_id}: ${hook_path}" >&2
      return 0
    fi
    cat >> "${target_file}" <<EOF
if { exists(global.nxtPluginLoaded_${plugin_global}) && global.nxtPluginLoaded_${plugin_global} }
    M98 P"${hook_path}"
EOF
  }

  cat >> "${init_dispatch}" <<EOF
if { !exists(global.nxtPluginLoaded_${plugin_global}) }
    global nxtPluginLoaded_${plugin_global} = false

if { !global.nxtPluginLoaded_${plugin_global} }
EOF
  if [[ -n "${init_path}" && -f "${TMP_DIR}/sd/sys/${init_path}" ]]; then
    cat >> "${init_dispatch}" <<EOF
    M98 P"${init_path}"
    set global.nxtPluginLoaded_${plugin_global} = true
EOF
  elif [[ "${failure_mode}" == "strict" ]]; then
    echo "error: missing init entrypoint for ${plugin_id}: ${init_path}" >&2
    exit 1
  else
    echo "warning: missing init entrypoint for ${plugin_id}: ${init_path}" >&2
    cat >> "${init_dispatch}" <<EOF
    ; missing init entrypoint: ${init_path}
EOF
  fi

  append_hook "${daemon_dispatch}" "${daemon_path}" "daemon"
  append_hook "${pause_dispatch}" "${pause_path}" "pause"
  append_hook "${resume_dispatch}" "${resume_path}" "resume"
  append_hook "${stop_dispatch}" "${stop_path}" "stop"
  append_hook "${cancel_dispatch}" "${cancel_path}" "cancel"
}

echo "Building nxt plugin (${OUT_ZIP}) using DWC at ${DWC_REPO_PATH}..."
echo "Build basis: ${BUILD_REF} (${BUILD_VERSION}) @ ${BUILD_SHA}"

# Stage sd/sys*: same layout as release.sh — macros/system/ → sd/sys/; macros/daemon/
# (nxt-daemon.g, nxt-user-tools-reload-daemon.g, …) → sd/sys/nxt/.
mkdir -p "${TMP_DIR}/sd/sys/nxt"
SYNC_CMD=(rsync -a --exclude=README.md --exclude='*.gitkeep')
for _macro_dir in system probing tooling spindle coolant utilities canned; do
  if [[ -d "${ROOT}/macros/${_macro_dir}" ]]; then
    "${SYNC_CMD[@]}" "${ROOT}/macros/${_macro_dir}/" "${TMP_DIR}/sd/sys/"
  fi
done
if [[ -d "${ROOT}/macros/daemon" ]]; then
  "${SYNC_CMD[@]}" "${ROOT}/macros/daemon/" "${TMP_DIR}/sd/sys/nxt/"
fi
if [[ -d "${ROOT}/macros/plugins" ]]; then
  mkdir -p "${TMP_DIR}/sd/sys/plugins"
  "${SYNC_CMD[@]}" "${ROOT}/macros/plugins/" "${TMP_DIR}/sd/sys/plugins/"
fi
if [[ -d "${ROOT}/macros/nxt-config" ]]; then
  mkdir -p "${TMP_DIR}/sd/sys/nxt-config"
  "${SYNC_CMD[@]}" "${ROOT}/macros/nxt-config/" "${TMP_DIR}/sd/sys/nxt-config/"
fi

if [[ -f "${TMP_DIR}/sd/sys/nxt.g" ]]; then
  echo "Replacing %%NXT_VERSION%% in sd/sys/nxt.g with ${BUILD_VERSION}..."
  _tmp_nxt="${TMP_DIR}/sd/sys/nxt.g.bak"
  sed "s/%%NXT_VERSION%%/${BUILD_VERSION}/g" "${TMP_DIR}/sd/sys/nxt.g" > "${_tmp_nxt}" && mv "${_tmp_nxt}" "${TMP_DIR}/sd/sys/nxt.g"
fi

echo "Generating nxt-config manifest..."
node "${ROOT}/dist/generate-nxt-config-manifest.mjs" "${ROOT}"

cp -a "${ROOT}/ui/." "${TMP_DIR}/"

# Replace version placeholder (portable; avoids sed -i differences)
_tmp_plugin="${TMP_DIR}/plugin.json.bak"
sed "s/%%NXT_VERSION%%/${BUILD_VERSION}/g" "${TMP_DIR}/plugin.json" > "${_tmp_plugin}" && mv "${_tmp_plugin}" "${TMP_DIR}/plugin.json"

generate_nxt_plugin_dispatchers

# Prefer catalog-driven dispatcher generation when available.
if [[ -f "${ROOT}/dist/generate-plugin-dispatchers.sh" && -f "${ROOT}/dist/plugins.catalog.json" ]]; then
  bash "${ROOT}/dist/generate-plugin-dispatchers.sh" "${ROOT}/dist/plugins.catalog.json" "${TMP_DIR}/sd/sys"
fi

if [[ ! -f "${BUILD_PLUGIN_JS}" ]]; then
  echo "error: ${BUILD_PLUGIN_JS} not found" >&2
  exit 1
fi
cp "${BUILD_PLUGIN_JS}" "${BUILD_PLUGIN_JS}.next-bak"
node "${ROOT}/dist/patch-dwc-build-plugin-zip.cjs" "${BUILD_PLUGIN_JS}"

(
  cd "${DWC_REPO_PATH}"
  npm ci
  npm install three@0.181.0
  npm run build-plugin "${TMP_DIR}"
)

if [[ ! -f "${DWC_REPO_PATH}/dist/${DWC_PLUGIN_ZIP}" ]]; then
  echo "error: expected DWC plugin zip ${DWC_REPO_PATH}/dist/${DWC_PLUGIN_ZIP}" >&2
  exit 1
fi
mv "${DWC_REPO_PATH}/dist/${DWC_PLUGIN_ZIP}" "${DWC_REPO_PATH}/dist/${OUT_ZIP}"

# build-plugin copies then deletes src/plugins/NeXT; restore imports.ts so dwc dev is not left broken
node "${ROOT}/dist/regenerate-dwc-plugin-imports.cjs" "${DWC_REPO_PATH}"

node "${ROOT}/dist/verify-plugin-zip.mjs" "${DWC_REPO_PATH}/dist/${OUT_ZIP}"

PLUGIN_DWC_NEED="$(unzip -p "${DWC_REPO_PATH}/dist/${OUT_ZIP}" plugin.json | jq -r '.dwcVersion')"
echo "Plugin ZIP requires host DWC version: ${PLUGIN_DWC_NEED} (exact match — see DWC Settings if load fails)"

echo "Diagnosing plugin chunk host dependencies..."
_app_js="$(ls "${DWC_REPO_PATH}"/dist/js/app.*.js 2>/dev/null | head -1)"
if [[ -n "${_app_js}" ]] && ! node "${ROOT}/dist/diagnose-plugin-chunk.mjs" "${DWC_REPO_PATH}/dist/${OUT_ZIP}" "${_app_js}"; then
  echo "warning: plugin chunk expects host modules missing from this DWC app.js — ZIP may fail on other DWC builds" >&2
fi

# DWC client only uploads zip members whose names start with "sd/" (see @duet3d/connectors
# PollConnector.installPlugin). Re-pack sd/ from staging so M-code macros always land under 0:/sys/.
DWC_REPO_PATH="${DWC_REPO_PATH}" node "${ROOT}/dist/merge-sd-into-plugin-zip.cjs" \
  "${DWC_REPO_PATH}/dist/${OUT_ZIP}" \
  "${TMP_DIR}"

DWC_REPO_PATH="${DWC_REPO_PATH}" node "${ROOT}/dist/inject-plugin-dwcfiles.cjs" \
  "${DWC_REPO_PATH}/dist/${OUT_ZIP}"

set +o pipefail
_zip_js="$(unzip -Z1 "${DWC_REPO_PATH}/dist/${OUT_ZIP}" 'dwc/js/NeXT*.js' 2>/dev/null | head -1)"
if [[ -z "${_zip_js}" ]]; then
  _zip_js="$(unzip -Z1 "${DWC_REPO_PATH}/dist/${OUT_ZIP}" 'dwc/NeXT/js/NeXT*.js' 2>/dev/null | head -1)"
fi
set -o pipefail
if [[ -n "${_zip_js}" ]]; then
  _tmp_js="$(mktemp --suffix=.js)"
  unzip -p "${DWC_REPO_PATH}/dist/${OUT_ZIP}" "${_zip_js}" > "${_tmp_js}"
  node --check "${_tmp_js}"
  rm -f "${_tmp_js}"
  echo "nxt chunk syntax check: OK"
fi

mkdir -p "${OUT_DIR}"
cp "${DWC_REPO_PATH}/dist/${OUT_ZIP}" "${OUT_DIR}/"

echo "Plugin built: ${OUT_DIR}/${OUT_ZIP}"
