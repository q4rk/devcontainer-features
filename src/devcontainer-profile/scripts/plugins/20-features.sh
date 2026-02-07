#!/bin/bash

oci_features() {
    if ! command -v feature-installer >/dev/null 2>&1; then return; fi

    local features_json
    features_json=$(jq -c '.features[]? | select(. != null)' "${USER_CONFIG_PATH}")
    [[ -z "${features_json}" ]] && return

    info "[Features] Processing..."
    
    # We use a temporary directory for feature installation to avoid pollution
    local temp_dir="${WORKSPACE}/tmp/features-$(date +%s)"
    mkdir -p "$temp_dir"

    echo "${features_json}" | while read -r feature; do
        local id
        id=$(echo "$feature" | jq -r '.id')

        local options=()
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            options+=("--option" "$line")
        done < <(echo "$feature" | jq -r '(.options // {}) | to_entries[] | .key + "=" + (.value | tostring)')

        info "[Features] Installing: ${id}"

        # Some features expect to be run as root
        if ! TMPDIR="$temp_dir" ensure_root feature-installer feature install "$id" "${options[@]}" >>"${LOG_FILE}" 2>&1; then
            error "[Features] Failed: ${id}"
        fi
    done
    rm -rf "$temp_dir"
}

oci_features
