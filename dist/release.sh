#!/usr/bin/env bash
# Build the versioned nxt release ZIP for CI / GitHub Releases (MOS-nxt project).
#
# Usage: ./dist/release.sh [path-to-DuetWebControl]
# Output: dist/nxt-<version>.zip (DWC plugin + sd/sys macros; install via Settings → Plugins)
#
# Post-processors are staged separately under dist/post-processors/<version>/.
WD="${PWD}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "Checking RRF macro line lengths (max 200)..."
node "${ROOT}/dist/check-gcode-line-length.mjs" || exit 1
TMP_DIR=$(mktemp -d -t nxt-release-XXXXX)
SYNC_CMD="rsync -a --exclude=README.md --exclude='*.gitkeep'"
# shellcheck source=dist/resolve-build-version.sh
source "${ROOT}/dist/resolve-build-version.sh"
DWC_PLUGIN_ZIP="nxt-${BUILD_VERSION}.zip"
DWC_REPO_PATH="${1:-${WD}/DuetWebControl}"
PLUGIN_ZIP="nxt-${BUILD_VERSION}.zip"
PLUGIN_PATH="${WD}/dist/${PLUGIN_ZIP}"

generate_nxt_plugin_dispatchers() {
    local plugin_json="$1"
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

    if [[ ! -f "${plugin_json}" ]] || ! jq -e '.data.nxt.tag == "nxt-plugin" and (.data.nxt.enabled // true)' "${plugin_json}" >/dev/null 2>&1; then
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

echo "Building nxt release ${PLUGIN_ZIP} for ${BUILD_VERSION} (ref ${BUILD_REF}, sha ${BUILD_SHA})..."

# Make stub folder-structure
# This also creates the sys directory
mkdir -p "${TMP_DIR}/sd/sys/nxt"

# Copy all macros to sys/ for system functionality (G/M-codes).
# macros/system/ is authoritative for nxt.g, nxt-user-tools*.g, etc.; optional tool reload lives under macros/daemon/.
${SYNC_CMD} macros/system/* macros/probing/* macros/tooling/* macros/spindle/* macros/coolant/* macros/utilities/* macros/canned/* "${TMP_DIR}/sd/sys/"

# Copy all daemon scripts to sys/nxt
if [[ -d "${WD}/macros/daemon" ]]; then
    ${SYNC_CMD} macros/daemon/* "${TMP_DIR}/sd/sys/nxt/"
fi
if [[ -d "${WD}/macros/plugins" ]]; then
    mkdir -p "${TMP_DIR}/sd/sys/plugins"
    ${SYNC_CMD} macros/plugins/* "${TMP_DIR}/sd/sys/plugins/"
fi
if [[ -d "${WD}/macros/nxt-config" ]]; then
    mkdir -p "${TMP_DIR}/sd/sys/nxt-config"
    ${SYNC_CMD} "${WD}/macros/nxt-config/" "${TMP_DIR}/sd/sys/nxt-config/"
fi

[[ -f "${PLUGIN_PATH}" ]] && rm "${PLUGIN_PATH}"

cd "${TMP_DIR}"

echo "Replacing %%NXT_VERSION%% with ${BUILD_VERSION}..."
sed -si -e "s/%%NXT_VERSION%%/${BUILD_VERSION}/g" sd/sys/nxt.g

if [[ ! -f "${WD}/ui/plugin.json" ]]; then
    echo "error: ui/plugin.json required for release (single plugin ZIP output)" >&2
    exit 1
fi

if [[ ! -d "${DWC_REPO_PATH}" ]]; then
    echo "error: Duet Web Control repository not found at ${DWC_REPO_PATH}" >&2
    exit 1
fi

echo "UI directory found, building plugin..."

cp -r "${WD}/ui/"* "${TMP_DIR}/"
sed -si -e "s/%%NXT_VERSION%%/${BUILD_VERSION}/g" plugin.json

echo "Generating nxt-config manifest..."
node "${WD}/dist/generate-nxt-config-manifest.mjs" "${WD}"

generate_nxt_plugin_dispatchers "${TMP_DIR}/plugin.json"

if [[ -f "${WD}/dist/generate-plugin-dispatchers.sh" && -f "${WD}/dist/plugins.catalog.json" ]]; then
    bash "${WD}/dist/generate-plugin-dispatchers.sh" "${WD}/dist/plugins.catalog.json" "${TMP_DIR}/sd/sys"
fi

(
    cd "${DWC_REPO_PATH}"
    npm ci
    npm install three@0.181.0
    npm run build-plugin "${TMP_DIR}" || exit 1
) || exit 1

BUILT_PLUGIN_ZIP="${DWC_REPO_PATH}/dist/${DWC_PLUGIN_ZIP}"
if [[ ! -f "${BUILT_PLUGIN_ZIP}" ]]; then
    echo "error: expected DWC plugin zip ${BUILT_PLUGIN_ZIP}" >&2
    exit 1
fi

echo "Generating dwc-plugins.json..."

if unzip -p "${BUILT_PLUGIN_ZIP}" plugin.json 2>/dev/null | jq -e '.dwcFiles | length > 0' >/dev/null 2>&1; then
    DWC_FILES=$(unzip -p "${BUILT_PLUGIN_ZIP}" plugin.json | jq -c '.dwcFiles')
else
    DWC_FILES=$(unzip -l "${BUILT_PLUGIN_ZIP}" | grep -E '^\s+[0-9]+.*dwc/' | awk '{print $4}' | sed 's|dwc/||' | sort | jq -R . | jq -s .)
fi

SD_FILES=$(find "${TMP_DIR}/sd/sys" -type f -name "*.g" | sed "s|${TMP_DIR}/sd/||" | sort | jq -R . | jq -s .)

PLUGIN_DWC_VERSION="$(unzip -p "${BUILT_PLUGIN_ZIP}" plugin.json | jq -r '.dwcVersion')"
PLUGIN_RRF_VERSION="$(unzip -p "${BUILT_PLUGIN_ZIP}" plugin.json | jq -r '.rrfVersion')"
if [[ -z "${PLUGIN_DWC_VERSION}" || "${PLUGIN_DWC_VERSION}" == "null" || -z "${PLUGIN_RRF_VERSION}" || "${PLUGIN_RRF_VERSION}" == "null" ]]; then
    echo "error: could not read resolved dwcVersion/rrfVersion from ${BUILT_PLUGIN_ZIP}" >&2
    exit 1
fi

jq -n \
  --arg id "nxt" \
  --arg name "nxt" \
  --arg author "MOS-nxt contributors" \
  --arg version "${BUILD_VERSION}" \
  --arg license "GPL-3.0-or-later" \
  --arg homepage "https://github.com/MillenniumMachines/MOS-nxt" \
  --arg dwcVersion "${PLUGIN_DWC_VERSION}" \
  --arg rrfVersion "${PLUGIN_RRF_VERSION}" \
  --argjson dwcFiles "${DWC_FILES}" \
  --argjson sdFiles "${SD_FILES}" \
  '{
    "nxt": {
      "id": $id,
      "name": $name,
      "author": $author,
      "version": $version,
      "license": $license,
      "homepage": $homepage,
      "tags": [],
      "dwcVersion": $dwcVersion,
      "dwcDependencies": [],
      "sbcRequired": false,
      "sbcDsfVersion": null,
      "sbcExecutable": null,
      "sbcExecutableArguments": null,
      "sbcExtraExecutables": [],
      "sbcAutoRestart": false,
      "sbcOutputRedirected": true,
      "sbcPermissions": [],
      "sbcConfigFiles": [],
      "sbcPackageDependencies": [],
      "sbcPluginDependencies": [],
      "sbcPythonDependencies": [],
      "rrfVersion": $rrfVersion,
      "data": {},
      "dsfFiles": [],
      "dwcFiles": $dwcFiles,
      "sdFiles": $sdFiles,
      "pid": -1
    }
  }' > "${TMP_DIR}/sd/sys/dwc-plugins.json"

mkdir -p "${WD}/dist"
cp "${BUILT_PLUGIN_ZIP}" "${PLUGIN_PATH}"

DWC_REPO_PATH="${DWC_REPO_PATH}" node "${WD}/dist/merge-sd-into-plugin-zip.cjs" \
    "${PLUGIN_PATH}" \
    "${TMP_DIR}" || exit 1
DWC_REPO_PATH="${DWC_REPO_PATH}" node "${WD}/dist/inject-plugin-dwcfiles.cjs" \
    "${PLUGIN_PATH}" || exit 1

node "${WD}/dist/verify-plugin-zip.mjs" "${PLUGIN_PATH}"

chmod +x "${WD}/dist/stage-post-processors.sh"
"${WD}/dist/stage-post-processors.sh" "${BUILD_VERSION}"

cat > "${WD}/dist/build-version.env" <<EOF
# Generated by dist/release.sh — do not commit
NXT_BUILD_VERSION=${BUILD_VERSION}
NXT_BUILD_REF=${BUILD_REF}
NXT_BUILD_SHA=${BUILD_SHA}
NXT_PLUGIN_ZIP=${PLUGIN_PATH}
NXT_RELEASE_ZIP=${PLUGIN_PATH}
EOF
if [[ -f "${WD}/dist/post-processors-staging.env" ]]; then
    cat "${WD}/dist/post-processors-staging.env" >> "${WD}/dist/build-version.env"
fi

cd "${WD}"
rm -rf "${TMP_DIR}"

echo "nxt release created at ${PLUGIN_PATH}"