#!/usr/bin/env bash
# Build the nxt DWC plugin only (no full SD release zip).
# Run from anywhere; paths are resolved from this script's location.
#
# Usage:
#   ./dist/build-plugin.sh [path-to-DuetWebControl]
#   ./dist/build-plugin.sh --clean-only [path-to-DuetWebControl]
#
# Default DWC path: <MOS-nxt-repo>/../DuetWebControl
#
# Output: dist/nxt-<ref>-<sha>[-dirty].zip
#
# Artifact cleanup runs automatically before staging and npm/Vite (not after the build).
# --clean-only removes artifacts and exits. --clean is accepted as a no-op for backwards compatibility.
#
# DWC 3.7+ (Vite): npm run build-plugin <staging-dir> writes <staging-dir>/nxt-<version>.zip
#   (flat dwc/js/nxt-<hash>.js + dwc/css/…). No webpack chunk filter patch is required.
# DWC 3.6.x (webpack): still patches build-plugin.js and expects ZIP under DuetWebControl/dist/.
#
# Cleanup removes:
#   - DuetWebControl/dist/          (legacy webpack output / leftover zips)
#   - DuetWebControl/src/plugins/nxt/  (dev symlink or staged tree)
#   - DuetWebControl/node_modules/.cache/ (vite / vue-cli cache)
#   - DuetWebControl/scripts/build-plugin.js.next-bak (leftover if a webpack-era build was interrupted)
#   - MOS-nxt/dist/nxt-*.zip        (previous plugin zip outputs only; other files under dist/ are kept)

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
# Resolve to absolute so Node post-processors (jszip require) work when a relative path is passed.
DWC_REPO_PATH="$(cd "${DWC_REPO_PATH}" && pwd)"

sanitize_ref() {
  local raw="$1"
  printf '%s' "${raw}" | sed 's/[^A-Za-z0-9._-]/-/g'
}

clean_next_plugin_artifacts() {
  local dwc="$1"
  echo "nxt plugin artifact cleanup (DWC: ${dwc})"
  if [[ -d "${dwc}/dist" ]]; then
    echo "  rm -rf ${dwc}/dist"
    rm -rf "${dwc}/dist"
  else
    echo "  (skip) no ${dwc}/dist"
  fi
  if [[ -d "${dwc}/src/plugins/nxt" ]]; then
    echo "  rm -rf ${dwc}/src/plugins/nxt"
    rm -rf "${dwc}/src/plugins/nxt"
  else
    echo "  (skip) no ${dwc}/src/plugins/nxt"
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
  for z in "${OUT_DIR}"/nxt-*.zip "${OUT_DIR}"/nxt-*.zip; do
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

# DWC 3.7 Vite/rolldown needs Node ^20.19 or >=22.12 (system Node 18 fails with styleText).
chmod +x "${ROOT}/dist/check-node-for-dwc-build.sh"
"${ROOT}/dist/check-node-for-dwc-build.sh"

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
echo "Checking M98 must not invoke numbered M####/G#### macros..."
node "${ROOT}/dist/check-m98-numbered-meta.mjs" || exit 1
echo "Checking RRF caret-as-power misuse..."
node "${ROOT}/dist/check-rrf-caret-power.mjs" || exit 1
echo "Checking G6512 single-axis call contract..."
node "${ROOT}/dist/check-g6512-axis-contract.mjs" || exit 1
echo "Checking G6512 deflection math..."
node "${ROOT}/dist/check-g6512-deflection-math.mjs" || exit 1
echo "Checking rotation / skew math..."
node "${ROOT}/dist/check-rotation-skew-math.mjs" || exit 1
echo "Checking calibration math..."
node "${ROOT}/dist/check-calibration-math.mjs" || exit 1
echo "Checking OM global size budget hygiene..."
node "${ROOT}/dist/check-om-global-budget.mjs" || exit 1

TMP_DIR="$(mktemp -d -t next-plugin-build-XXXXX)"

# shellcheck source=dist/resolve-build-version.sh
source "${ROOT}/dist/resolve-build-version.sh"

if git -C "${ROOT}" diff-index --quiet HEAD --; then
  DIRTY_SUFFIX=""
else
  DIRTY_SUFFIX="-dirty"
fi

# Embedded nxt.g / posts use release line with leading v (e.g. v0.7.0) for M4005.
# plugin.json gets semver without leading v — DWC build-plugin prints/names as v${version}.
PLUGIN_SEMVER="${BUILD_VERSION#v}"
DWC_PLUGIN_ZIP="nxt-${PLUGIN_SEMVER}.zip"
OUT_ZIP="nxt-$(sanitize_ref "${BUILD_REF}")-${BUILD_SHA}${DIRTY_SUFFIX}.zip"
echo "nxt plugin build: embedded version ${BUILD_VERSION} (plugin.json ${PLUGIN_SEMVER}, ref ${BUILD_REF}, zip ${OUT_ZIP})"
BUILD_PLUGIN_JS="${DWC_REPO_PATH}/scripts/build-plugin.js"
DWC_BUILDER="$(node "${ROOT}/dist/detect-dwc-plugin-builder.mjs" "${DWC_REPO_PATH}")"
echo "DWC plugin builder: ${DWC_BUILDER}"

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
; nxt plugin init dispatcher
EOF
  cat > "${daemon_dispatch}" <<'EOF'
; Auto-generated. Do not edit.
; nxt plugin daemon dispatcher
EOF
  cat > "${pause_dispatch}" <<'EOF'
; Auto-generated. Do not edit.
; nxt plugin pause hooks dispatcher
EOF
  cat > "${resume_dispatch}" <<'EOF'
; Auto-generated. Do not edit.
; nxt plugin resume hooks dispatcher
EOF
  cat > "${stop_dispatch}" <<'EOF'
; Auto-generated. Do not edit.
; nxt plugin stop hooks dispatcher
EOF
  cat > "${cancel_dispatch}" <<'EOF'
; Auto-generated. Do not edit.
; nxt plugin cancel hooks dispatcher
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

# Replace version placeholder (portable; avoids sed -i differences).
# plugin.json only: strip leading v so DWC does not display/name vv….
_tmp_plugin="${TMP_DIR}/plugin.json.bak"
sed "s/%%NXT_VERSION%%/${PLUGIN_SEMVER}/g" "${TMP_DIR}/plugin.json" > "${_tmp_plugin}" && mv "${_tmp_plugin}" "${TMP_DIR}/plugin.json"

generate_nxt_plugin_dispatchers

# Prefer catalog-driven dispatcher generation when available.
if [[ -f "${ROOT}/dist/generate-plugin-dispatchers.sh" && -f "${ROOT}/dist/plugins.catalog.json" ]]; then
  bash "${ROOT}/dist/generate-plugin-dispatchers.sh" "${ROOT}/dist/plugins.catalog.json" "${TMP_DIR}/sd/sys"
fi

if [[ ! -f "${BUILD_PLUGIN_JS}" ]]; then
  echo "error: ${BUILD_PLUGIN_JS} not found" >&2
  exit 1
fi

# Webpack (3.6): patch chunk filter in place (restored on EXIT).
# Vite (3.7+): no-op unless NXT_SKIP_DWC_TYPECHECK=1 (softens vue-tsc gate for packaging smoke).
cp "${BUILD_PLUGIN_JS}" "${BUILD_PLUGIN_JS}.next-bak"
if [[ "${DWC_BUILDER}" == "vite" && "${NXT_SKIP_DWC_TYPECHECK:-}" == "1" ]]; then
  echo "warning: NXT_SKIP_DWC_TYPECHECK=1 — ZIP packaging will proceed despite Vue 2/3 type errors" >&2
fi
node "${ROOT}/dist/patch-dwc-build-plugin-zip.cjs" "${BUILD_PLUGIN_JS}"

(
  cd "${DWC_REPO_PATH}"
  if [[ ! -d node_modules ]]; then
    npm ci
  fi
  # three is a peer of the nxt GCode viewer panel (optional at ZIP build time).
  if [[ "${DWC_BUILDER}" == "webpack" ]]; then
    npm install three@0.181.0
  elif ! node -e "require.resolve('three')" >/dev/null 2>&1; then
    npm install three@0.181.0 --no-save
  fi
  # jszip is a real runtime dep of the Fusion tool import parser (fusionToolsImport/parseFusionTools.ts).
  # Vite's plugin build root is the TMP_DIR staging tree (no node_modules of its own), so bare
  # `import('jszip')` cannot resolve by walking up from a file under /tmp; DWC already depends on
  # jszip (used by its own file-list ZIP handling), so link it into the staging tree instead of
  # adding a build-only dependency.
  if [[ "${DWC_BUILDER}" == "vite" ]]; then
    if ! node -e "require.resolve('jszip')" >/dev/null 2>&1; then
      npm install jszip@3.10.1 --no-save
    fi
  fi
)

if [[ "${DWC_BUILDER}" == "vite" ]]; then
  NXT_JSZIP_SRC="${DWC_REPO_PATH}/node_modules/jszip"
  if [[ -d "${NXT_JSZIP_SRC}" ]]; then
    mkdir -p "${TMP_DIR}/node_modules"
    ln -s "${NXT_JSZIP_SRC}" "${TMP_DIR}/node_modules/jszip"
  fi
fi

(
  cd "${DWC_REPO_PATH}"
  npm run build-plugin -- "${TMP_DIR}"
)

# Vite writes ZIP next to the plugin staging dir; webpack wrote under DuetWebControl/dist/.
BUILT_PLUGIN_ZIP=""
_dwc_zip_names=("${DWC_PLUGIN_ZIP}" "nxt-${BUILD_VERSION}.zip")
for _zip_name in "${_dwc_zip_names[@]}"; do
  if [[ -f "${TMP_DIR}/${_zip_name}" ]]; then
    BUILT_PLUGIN_ZIP="${TMP_DIR}/${_zip_name}"
    break
  elif [[ -f "${DWC_REPO_PATH}/dist/${_zip_name}" ]]; then
    BUILT_PLUGIN_ZIP="${DWC_REPO_PATH}/dist/${_zip_name}"
    break
  fi
done
if [[ -z "${BUILT_PLUGIN_ZIP}" ]]; then
  # Fallback: any nxt-*.zip produced in staging (version placeholder edge cases).
  shopt -s nullglob
  _candidates=("${TMP_DIR}"/nxt-*.zip "${DWC_REPO_PATH}/dist"/nxt-*.zip)
  shopt -u nullglob
  if [[ ${#_candidates[@]} -gt 0 ]]; then
    BUILT_PLUGIN_ZIP="${_candidates[0]}"
    echo "warning: using unexpected ZIP name ${BUILT_PLUGIN_ZIP} (expected ${DWC_PLUGIN_ZIP})" >&2
  fi
fi
if [[ -z "${BUILT_PLUGIN_ZIP}" || ! -f "${BUILT_PLUGIN_ZIP}" ]]; then
  echo "error: expected plugin zip ${DWC_PLUGIN_ZIP} under ${TMP_DIR}/ or ${DWC_REPO_PATH}/dist/" >&2
  exit 1
fi

mkdir -p "${OUT_DIR}"
WORK_ZIP="${OUT_DIR}/${OUT_ZIP}"
cp "${BUILT_PLUGIN_ZIP}" "${WORK_ZIP}"

# Webpack-era built-in staging used imports.ts; Vite discovers builtins via virtual:dwc-builtin-plugins.
# Only regenerate when the legacy file exists (3.6 trees / leftover checkouts).
if [[ -f "${DWC_REPO_PATH}/src/plugins/imports.ts" ]]; then
  node "${ROOT}/dist/regenerate-dwc-plugin-imports.cjs" "${DWC_REPO_PATH}"
fi

# DWC client only uploads zip members whose names start with "sd/" (see @duet3d/connectors
# PollConnector.installPlugin). Re-pack sd/ from staging so M-code macros always land under 0:/sys/.
DWC_REPO_PATH="${DWC_REPO_PATH}" node "${ROOT}/dist/merge-sd-into-plugin-zip.cjs" \
  "${WORK_ZIP}" \
  "${TMP_DIR}"

DWC_REPO_PATH="${DWC_REPO_PATH}" node "${ROOT}/dist/inject-plugin-dwcfiles.cjs" \
  "${WORK_ZIP}"

node "${ROOT}/dist/verify-plugin-zip.mjs" "${WORK_ZIP}"

PLUGIN_DWC_NEED="$(unzip -p "${WORK_ZIP}" plugin.json | jq -r '.dwcVersion')"
echo "Plugin ZIP requires host DWC version: ${PLUGIN_DWC_NEED} (exact match — see DWC Settings if load fails)"

if [[ "${DWC_BUILDER}" == "webpack" ]]; then
  echo "Diagnosing plugin chunk host dependencies (webpack)..."
  _app_js="$(ls "${DWC_REPO_PATH}"/dist/js/app.*.js 2>/dev/null | head -1)"
  if [[ -n "${_app_js}" ]] && ! node "${ROOT}/dist/diagnose-plugin-chunk.mjs" "${WORK_ZIP}" "${_app_js}"; then
    echo "warning: plugin chunk expects host modules missing from this DWC app.js — ZIP may fail on other DWC builds" >&2
  fi
else
  echo "Skipping webpack chunk diagnose (DWC Vite / IIFE external plugin)."
fi

set +o pipefail
_zip_js="$(unzip -Z1 "${WORK_ZIP}" 'dwc/js/nxt*.js' 2>/dev/null | head -1)"
if [[ -z "${_zip_js}" ]]; then
  _zip_js="$(unzip -Z1 "${WORK_ZIP}" 'dwc/nxt/js/nxt*.js' 2>/dev/null | head -1)"
fi
set -o pipefail
if [[ -n "${_zip_js}" ]]; then
  _tmp_js="$(mktemp --suffix=.js)"
  unzip -p "${WORK_ZIP}" "${_zip_js}" > "${_tmp_js}"
  node --check "${_tmp_js}"
  rm -f "${_tmp_js}"
  echo "nxt chunk syntax check: OK (${_zip_js})"
fi

echo "Plugin built: ${WORK_ZIP}"
