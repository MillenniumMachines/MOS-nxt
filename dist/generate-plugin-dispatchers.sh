#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CATALOG_PATH="${1:-${ROOT}/dist/plugins.catalog.json}"
SYS_ROOT="${2:-${ROOT}/.tmp/sys}"
STRICT_DEFAULT="${STRICT_DEFAULT:-false}"

OUT_DIR="${SYS_ROOT}/nxt/plugins"
INIT_FILE="${OUT_DIR}/nxt-plugin-init-dispatch.g"
DAEMON_FILE="${OUT_DIR}/nxt-plugin-daemon-dispatch.g"
PAUSE_FILE="${OUT_DIR}/nxt-plugin-hooks-pause.g"
RESUME_FILE="${OUT_DIR}/nxt-plugin-hooks-resume.g"
STOP_FILE="${OUT_DIR}/nxt-plugin-hooks-stop.g"
CANCEL_FILE="${OUT_DIR}/nxt-plugin-hooks-cancel.g"

mkdir -p "${OUT_DIR}"

cat > "${INIT_FILE}" <<'EOF'
; Auto-generated. Do not edit.
; nxt plugin init dispatcher
EOF

cat > "${DAEMON_FILE}" <<'EOF'
; Auto-generated. Do not edit.
; nxt plugin daemon dispatcher
EOF

cat > "${PAUSE_FILE}" <<'EOF'
; Auto-generated. Do not edit.
; nxt plugin pause hooks dispatcher
EOF

cat > "${RESUME_FILE}" <<'EOF'
; Auto-generated. Do not edit.
; nxt plugin resume hooks dispatcher
EOF

cat > "${STOP_FILE}" <<'EOF'
; Auto-generated. Do not edit.
; nxt plugin stop hooks dispatcher
EOF

cat > "${CANCEL_FILE}" <<'EOF'
; Auto-generated. Do not edit.
; nxt plugin cancel hooks dispatcher
EOF

warn() {
  echo "warning: $*" >&2
}

fail_or_warn() {
  local mode="$1"
  local message="$2"
  if [[ "${mode}" == "strict" ]]; then
    echo "error: ${message}" >&2
    exit 1
  fi
  warn "${message}"
}

sanitize_id() {
  local plugin_id="$1"
  echo "${plugin_id}" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/_/g; s/^_+//; s/_+$//'
}

normalize_m98_path() {
  local p="$1"
  p="${p#0:/sys/}"
  p="${p#/sys/}"
  echo "${p}"
}

append_hook_if_valid() {
  local target_file="$1"
  local plugin_global="$2"
  local mode="$3"
  local event_name="$4"
  local event_path="$5"
  local normalized

  if [[ -z "${event_path}" ]]; then
    return 0
  fi

  normalized="$(normalize_m98_path "${event_path}")"
  if [[ ! -f "${SYS_ROOT}/${normalized}" ]]; then
    fail_or_warn "${mode}" "missing ${event_name} entrypoint: ${event_path}"
    return 0
  fi

  cat >> "${target_file}" <<EOF
if { exists(global.nxtPluginLoaded_${plugin_global}) && global.nxtPluginLoaded_${plugin_global} }
    M98 P"${normalized}"
EOF
}

ENTRY_COUNT=0

while IFS= read -r plugin; do
  manifest_rel="$(jq -r '.manifestPath // empty' <<<"${plugin}")"
  repo_path="$(jq -r '.repoPath // "."' <<<"${plugin}")"
  required="$(jq -r '.required // false' <<<"${plugin}")"
  manifest_abs="${ROOT}/${repo_path}/${manifest_rel}"

  if [[ ! -f "${manifest_abs}" ]]; then
    if [[ "${required}" == "true" ]]; then
      echo "error: required plugin manifest missing: ${manifest_abs}" >&2
      exit 1
    fi
    warn "optional plugin manifest not found: ${manifest_abs}"
    continue
  fi

  tag="$(jq -r '.data.nxt.tag // empty' "${manifest_abs}")"
  enabled="$(jq -r '.data.nxt.enabled // true' "${manifest_abs}")"
  if [[ "${tag}" != "nxt-plugin" || "${enabled}" != "true" ]]; then
    continue
  fi

  plugin_id="$(jq -r '.id // empty' "${manifest_abs}")"
  if [[ -z "${plugin_id}" || "${plugin_id}" == "null" ]]; then
    echo "error: plugin id is required in ${manifest_abs}" >&2
    exit 1
  fi
  plugin_global="$(sanitize_id "${plugin_id}")"
  if [[ -z "${plugin_global}" ]]; then
    echo "error: could not derive plugin global namespace for ${plugin_id}" >&2
    exit 1
  fi

  skip_init_dispatch="$(jq -r '.skipInitDispatch // false' <<<"${plugin}")"

  failure_mode="$(jq -r '.data.nxt.failureMode // empty' "${manifest_abs}")"
  if [[ -z "${failure_mode}" ]]; then
    if [[ "${STRICT_DEFAULT}" == "true" ]]; then
      failure_mode="strict"
    else
      failure_mode="soft"
    fi
  fi

  init_path="$(jq -r '.data.nxt.entrypoints.init // empty' "${manifest_abs}")"
  daemon_path="$(jq -r '.data.nxt.entrypoints.daemon // empty' "${manifest_abs}")"
  pause_path="$(jq -r '.data.nxt.entrypoints.pause // empty' "${manifest_abs}")"
  resume_path="$(jq -r '.data.nxt.entrypoints.resume // empty' "${manifest_abs}")"
  stop_path="$(jq -r '.data.nxt.entrypoints.stop // empty' "${manifest_abs}")"
  cancel_path="$(jq -r '.data.nxt.entrypoints.cancel // empty' "${manifest_abs}")"

  # Stage entrypoint macros from sibling plugin repos (e.g. ../ArborCTL/sd/sys/...)
  # when they are not already present in the nxt staging tree.
  stage_entrypoint_from_repo() {
    local event_path="$1"
    local normalized
    if [[ -z "${event_path}" ]]; then
      return 0
    fi
    normalized="$(normalize_m98_path "${event_path}")"
    if [[ -f "${SYS_ROOT}/${normalized}" ]]; then
      return 0
    fi
    local plugin_root="${ROOT}/${repo_path}"
    local candidates=(
      "${plugin_root}/sd/sys/${normalized}"
      "${plugin_root}/sd/${normalized}"
    )
    local src
    for src in "${candidates[@]}"; do
      if [[ -f "${src}" ]]; then
        mkdir -p "$(dirname "${SYS_ROOT}/${normalized}")"
        cp -a "${src}" "${SYS_ROOT}/${normalized}"
        echo "staged ${plugin_id} entrypoint: ${normalized} <- ${src}"
        return 0
      fi
    done
  }

  stage_entrypoint_from_repo "${init_path}"
  stage_entrypoint_from_repo "${daemon_path}"
  stage_entrypoint_from_repo "${pause_path}"
  stage_entrypoint_from_repo "${resume_path}"
  stage_entrypoint_from_repo "${stop_path}"
  stage_entrypoint_from_repo "${cancel_path}"

  feature_flag="$(jq -r '.featureFlag // empty' <<<"${plugin}")"
  if [[ -z "${feature_flag}" || "${feature_flag}" == "null" ]]; then
    feature_flag="$(jq -r '.data.nxt.featureFlag // empty' "${manifest_abs}")"
  fi

  if [[ "${skip_init_dispatch}" == "true" ]]; then
    warn "skipping init dispatch for ${plugin_id} (boot via nxt.g when feature flag set)"
  elif [[ -z "${init_path}" ]]; then
    fail_or_warn "${failure_mode}" "missing init entrypoint for ${plugin_id}"
  else
    normalized_init="$(normalize_m98_path "${init_path}")"
    if [[ ! -f "${SYS_ROOT}/${normalized_init}" ]]; then
      fail_or_warn "${failure_mode}" "missing init entrypoint file for ${plugin_id}: ${init_path}"
    else
      if [[ -n "${feature_flag}" && "${feature_flag}" != "null" ]]; then
        cat >> "${INIT_FILE}" <<EOF
if { exists(global.${feature_flag}) && global.${feature_flag} }
    if { !exists(global.nxtPluginLoaded_${plugin_global}) }
        global nxtPluginLoaded_${plugin_global} = false
    if { !global.nxtPluginLoaded_${plugin_global} }
        M98 P"${normalized_init}"
        set global.nxtPluginLoaded_${plugin_global} = true

EOF
      else
        cat >> "${INIT_FILE}" <<EOF
if { !exists(global.nxtPluginLoaded_${plugin_global}) }
    global nxtPluginLoaded_${plugin_global} = false

if { !global.nxtPluginLoaded_${plugin_global} }
    M98 P"${normalized_init}"
    set global.nxtPluginLoaded_${plugin_global} = true
EOF
      fi
      ENTRY_COUNT=$((ENTRY_COUNT + 1))
    fi
  fi

  append_hook_if_valid "${DAEMON_FILE}" "${plugin_global}" "${failure_mode}" "daemon" "${daemon_path}"
  append_hook_if_valid "${PAUSE_FILE}" "${plugin_global}" "${failure_mode}" "pause" "${pause_path}"
  append_hook_if_valid "${RESUME_FILE}" "${plugin_global}" "${failure_mode}" "resume" "${resume_path}"
  append_hook_if_valid "${STOP_FILE}" "${plugin_global}" "${failure_mode}" "stop" "${stop_path}"
  append_hook_if_valid "${CANCEL_FILE}" "${plugin_global}" "${failure_mode}" "cancel" "${cancel_path}"
done < <(jq -c '.plugins | sort_by(.id)[]' "${CATALOG_PATH}")

if [[ "${ENTRY_COUNT}" -eq 0 ]]; then
  echo "; no plugins tagged nxt-plugin" >> "${INIT_FILE}"
  echo "; no plugins tagged nxt-plugin" >> "${DAEMON_FILE}"
  echo "; no plugins tagged nxt-plugin" >> "${PAUSE_FILE}"
  echo "; no plugins tagged nxt-plugin" >> "${RESUME_FILE}"
  echo "; no plugins tagged nxt-plugin" >> "${STOP_FILE}"
  echo "; no plugins tagged nxt-plugin" >> "${CANCEL_FILE}"
fi

echo "Generated plugin dispatchers in ${OUT_DIR}"
