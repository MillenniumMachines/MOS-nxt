#!/usr/bin/env bash
# Build the NeXT DWC plugin only (no full SD release zip).
# Run from anywhere; paths are resolved from this script's location.
#
# Usage:
#   ./dist/build-plugin.sh [path-to-DuetWebControl]
#
# Default DWC path: <NeXT-repo>/../DuetWebControl
#
# Output: dist/NeXT-<git-describe>.zip

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DWC_REPO_PATH="${1:-${ROOT}/../DuetWebControl}"
TMP_DIR="$(mktemp -d -t next-plugin-build-XXXXX)"
COMMIT_ID="$(git -C "${ROOT}" describe --tags --exclude "release-*" --always --dirty)"
OUT_ZIP="NeXT-${COMMIT_ID}.zip"
OUT_DIR="${ROOT}/dist"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

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

if [[ ! -f "${ROOT}/ui/plugin.json" ]]; then
  echo "error: ${ROOT}/ui/plugin.json not found" >&2
  exit 1
fi

if [[ ! -d "${DWC_REPO_PATH}" ]]; then
  echo "error: DuetWebControl repository not found at ${DWC_REPO_PATH}" >&2
  exit 1
fi

echo "Building NeXT plugin (${OUT_ZIP}) using DWC at ${DWC_REPO_PATH}..."

# Stage sd/sys* the same way as dist/release.sh. DWC's build-plugin archives a top-level
# sd/ tree into the plugin zip (see DuetWebControl scripts/build-plugin.js).
mkdir -p "${TMP_DIR}/sd/sys/nxt"
SYNC_CMD=(rsync -a --exclude=README.md --exclude='*.gitkeep')
for _macro_dir in system probing tooling spindle coolant utilities; do
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

if [[ -f "${TMP_DIR}/sd/sys/nxt.g" ]]; then
  echo "Replacing %%NXT_VERSION%% in sd/sys/nxt.g with ${COMMIT_ID}..."
  _tmp_nxt="${TMP_DIR}/sd/sys/nxt.g.bak"
  sed "s/%%NXT_VERSION%%/${COMMIT_ID}/g" "${TMP_DIR}/sd/sys/nxt.g" > "${_tmp_nxt}" && mv "${_tmp_nxt}" "${TMP_DIR}/sd/sys/nxt.g"
fi

cp -a "${ROOT}/ui/." "${TMP_DIR}/"

# Replace version placeholder (portable; avoids sed -i differences)
_tmp_plugin="${TMP_DIR}/plugin.json.bak"
sed "s/%%NXT_VERSION%%/${COMMIT_ID}/g" "${TMP_DIR}/plugin.json" > "${_tmp_plugin}" && mv "${_tmp_plugin}" "${TMP_DIR}/plugin.json"

generate_nxt_plugin_dispatchers

# Prefer catalog-driven dispatcher generation when available.
if [[ -f "${ROOT}/dist/generate-plugin-dispatchers.sh" && -f "${ROOT}/dist/plugins.catalog.json" ]]; then
  bash "${ROOT}/dist/generate-plugin-dispatchers.sh" "${ROOT}/dist/plugins.catalog.json" "${TMP_DIR}/sd/sys"
fi

(
  cd "${DWC_REPO_PATH}"
  npm ci
  npm install three@0.181.0
  npm run build-plugin "${TMP_DIR}"
)

mkdir -p "${OUT_DIR}"
cp "${DWC_REPO_PATH}/dist/${OUT_ZIP}" "${OUT_DIR}/"

echo "Plugin built: ${OUT_DIR}/${OUT_ZIP}"
