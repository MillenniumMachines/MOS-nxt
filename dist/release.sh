#!/usr/bin/env bash
WD="${PWD}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "Checking RRF macro line lengths (max 200)..."
node "${ROOT}/dist/check-gcode-line-length.mjs" || exit 1
TMP_DIR=$(mktemp -d -t next-release-XXXXX)
ZIP_NAME="${1:-next-sd-release}.zip"
ZIP_PATH="${WD}/dist/${ZIP_NAME}"
SYNC_CMD="rsync -a --exclude=README.md --exclude='*.gitkeep'"
COMMIT_ID=$(git describe --tags --exclude "release-*" --always --dirty)
DWC_REPO_PATH="${2:-${WD}/DuetWebControl}"

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

echo "Building NeXT release ${ZIP_NAME} for ${COMMIT_ID}..."

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

[[ -f "${ZIP_PATH}" ]] && rm "${ZIP_PATH}"

cd "${TMP_DIR}"

echo "Replacing %%NXT_VERSION%% with ${COMMIT_ID}..."
sed -si -e "s/%%NXT_VERSION%%/${COMMIT_ID}/g" sd/sys/nxt.g

# Conditionally build and include the UI if it exists
if [[ -f "${WD}/ui/plugin.json" ]]; then
    echo "UI directory found, building plugin..."

    if [[ ! -d "${DWC_REPO_PATH}" ]]; then
        echo "Duet Web Control repository not found at ${DWC_REPO_PATH}"
        exit 1
    fi

    # Copy UI source for build
    cp -r "${WD}/ui/"* "${TMP_DIR}/"
    sed -si -e "s/%%NXT_VERSION%%/${COMMIT_ID}/g" plugin.json

    # Build the DWC Plugin
    (   cd "${DWC_REPO_PATH}"
        npm ci
        npm install three@0.181.0
        npm run build-plugin "${TMP_DIR}" || exit 1
        # Ensure sd/ entries use dwc/expected "sd/..." paths so PollConnector installs M-codes to 0:/sys/
        DWC_REPO_PATH="${DWC_REPO_PATH}" node "${WD}/dist/merge-sd-into-plugin-zip.cjs" \
            "${PWD}/dist/NeXT-${COMMIT_ID}.zip" \
            "${TMP_DIR}" || exit 1
        DWC_REPO_PATH="${DWC_REPO_PATH}" node "${WD}/dist/inject-plugin-dwcfiles.cjs" \
            "${PWD}/dist/NeXT-${COMMIT_ID}.zip" || exit 1
        # Copy the built plugin to the main dist folder
        cp dist/NeXT-${COMMIT_ID}.zip "${WD}/dist/" || exit 1
    ) || exit 1

    # Extract the "dwc" folder from the plugin into the SD directory
    unzip -o "${WD}/dist/NeXT-${COMMIT_ID}.zip" "dwc/*" -d "${TMP_DIR}/sd"

    # Generate dwc-plugins.json automatically
    echo "Generating dwc-plugins.json..."

    # Extract DWC file paths from the plugin ZIP
    # Prefer dwcFiles from built plugin.json (NeXT/js/... layout); fallback: strip dwc/ prefix from zip listing
    if unzip -p "${WD}/dist/NeXT-${COMMIT_ID}.zip" plugin.json 2>/dev/null | jq -e '.dwcFiles | length > 0' >/dev/null 2>&1; then
        DWC_FILES=$(unzip -p "${WD}/dist/NeXT-${COMMIT_ID}.zip" plugin.json | jq -c '.dwcFiles')
    else
        DWC_FILES=$(unzip -l "${WD}/dist/NeXT-${COMMIT_ID}.zip" | grep -E '^\s+[0-9]+.*dwc/' | awk '{print $4}' | sed 's|dwc/||' | sort | jq -R . | jq -s .)
    fi

    # Extract SD file paths (macro files that go in sys/)
    SD_FILES=$(find "${TMP_DIR}/sd/sys" -type f -name "*.g" | sed "s|${TMP_DIR}/sd/||" | sort | jq -R . | jq -s .)

    # Match dwc-plugins.json to the built plugin manifest (dwcVersion auto → exact; rrfVersion auto-major)
    PLUGIN_MANIFEST="${WD}/dist/NeXT-${COMMIT_ID}.zip"
    PLUGIN_DWC_VERSION="$(unzip -p "${PLUGIN_MANIFEST}" plugin.json | jq -r '.dwcVersion')"
    PLUGIN_RRF_VERSION="$(unzip -p "${PLUGIN_MANIFEST}" plugin.json | jq -r '.rrfVersion')"
    if [[ -z "${PLUGIN_DWC_VERSION}" || "${PLUGIN_DWC_VERSION}" == "null" || -z "${PLUGIN_RRF_VERSION}" || "${PLUGIN_RRF_VERSION}" == "null" ]]; then
        echo "error: could not read resolved dwcVersion/rrfVersion from ${PLUGIN_MANIFEST}" >&2
        exit 1
    fi

    # Create the dwc-plugins.json file using jq to properly handle JSON
    jq -n \
      --arg id "NeXT" \
      --arg name "NeXT - Next-Gen Extended Tooling" \
      --arg author "NeXT Development Team" \
      --arg version "${COMMIT_ID}" \
      --arg license "GPL-3.0-or-later" \
      --arg homepage "https://github.com/benagricola/NeXT" \
      --arg dwcVersion "${PLUGIN_DWC_VERSION}" \
      --arg rrfVersion "${PLUGIN_RRF_VERSION}" \
      --argjson dwcFiles "${DWC_FILES}" \
      --argjson sdFiles "${SD_FILES}" \
      '{
        "NeXT": {
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
fi

# Generate NeXT runtime plugin dispatchers from metadata (or no-op defaults)
generate_nxt_plugin_dispatchers "${TMP_DIR}/plugin.json"

# Prefer catalog-driven dispatcher generation when available.
if [[ -f "${WD}/dist/generate-plugin-dispatchers.sh" && -f "${WD}/dist/plugins.catalog.json" ]]; then
    bash "${WD}/dist/generate-plugin-dispatchers.sh" "${WD}/dist/plugins.catalog.json" "${TMP_DIR}/sd/sys"
fi

# Create the final SD card release ZIP
# Ensure output directory exists
mkdir -p "$(dirname "${ZIP_PATH}")"
(
    cd "${TMP_DIR}/sd"
    zip -r "${ZIP_PATH}" * -x "*.gitkeep"
) || exit 1

cd "${WD}"
rm -rf "${TMP_DIR}"

echo "NeXT release created at ${ZIP_PATH}"