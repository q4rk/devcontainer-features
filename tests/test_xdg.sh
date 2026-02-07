#!/bin/bash

set -o errexit
set -o pipefail

TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

export CONFIG_MOUNT="$TEST_ROOT/mount"
export FALLBACK_MOUNT="$TEST_ROOT/fallback"
export USER_CONFIG_PATH="$TEST_ROOT/user_link"
mkdir -p "$CONFIG_MOUNT" "$FALLBACK_MOUNT"

# Load the logic we want to test (Isolated Discovery Logic)
discover_config() {
    local config_source=""
    local discovery_dirs=("${CONFIG_MOUNT}" "${FALLBACK_MOUNT}")

    for d in "${discovery_dirs[@]}"; do
        if [[ -f "${d}" ]]; then
            config_source="${d}"
            break
        elif [[ -d "${d}" ]]; then
            if [[ -f "${d}/config.json" ]]; then config_source="${d}/config.json"
            elif [[ -f "${d}/devcontainer.profile.json" ]]; then config_source="${d}/devcontainer.profile.json"
            elif [[ -f "${d}/.devcontainer.profile" ]]; then config_source="${d}/.devcontainer.profile"
            fi
            
            if [[ -n "$config_source" ]]; then
                break
            fi
        fi
    done
    echo "$config_source"
}

assert_eq() {
    if [[ "$1" == "$2" ]]; then
        echo -e "  \e[32mPASS\e[0m: $3"
    else
        echo -e "  \e[31mFAIL\e[0m: $3 (Expected '$1', got '$2')"
        exit 1
    fi
}

echo "Running XDG Discovery Tests..."

rm -rf "$CONFIG_MOUNT"
touch "$CONFIG_MOUNT"
assert_eq "$CONFIG_MOUNT" "$(discover_config)" "Direct file mount detected"

rm -rf "$CONFIG_MOUNT" && mkdir -p "$CONFIG_MOUNT"
touch "$CONFIG_MOUNT/.devcontainer.profile"
assert_eq "$CONFIG_MOUNT/.devcontainer.profile" "$(discover_config)" "Directory: found .devcontainer.profile"

touch "$CONFIG_MOUNT/devcontainer.profile.json"
assert_eq "$CONFIG_MOUNT/devcontainer.profile.json" "$(discover_config)" "Directory: devcontainer.profile.json overrides .devcontainer.profile"

touch "$CONFIG_MOUNT/config.json"
assert_eq "$CONFIG_MOUNT/config.json" "$(discover_config)" "Directory: config.json overrides all"

rm -rf "$CONFIG_MOUNT"
mkdir -p "$FALLBACK_MOUNT"
touch "$FALLBACK_MOUNT/config.json"
assert_eq "$FALLBACK_MOUNT/config.json" "$(discover_config)" "Fallback mount detected"

echo "All XDG discovery tests passed successfully."
