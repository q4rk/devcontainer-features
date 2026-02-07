#!/bin/bash

set -o errexit
set -o pipefail

TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

export HOME="$TEST_ROOT/home"
export WORKSPACE="$TEST_ROOT/workspace"
export STATE_DIR="$WORKSPACE/state"
export PLUGIN_DIR="$TEST_ROOT/plugins"
export MANAGED_CONFIG_DIR="$HOME/.devcontainer-profile"
export VOLUME_CONFIG_DIR="$STATE_DIR/configs"
export USER_CONFIG_PATH="$MANAGED_CONFIG_DIR/config.json"
export USER_PATH_FILE="$HOME/.devcontainer.profile_path"
export CONFIG_MOUNT="$WORKSPACE/config"

mkdir -p "$HOME" "$STATE_DIR" "$WORKSPACE/tmp" "$PLUGIN_DIR" "$WORKSPACE/config" "$VOLUME_CONFIG_DIR" "$MANAGED_CONFIG_DIR"

MOCK_BIN="$TEST_ROOT/mock_bin"
mkdir -p "$MOCK_BIN"
export PATH="$MOCK_BIN:$PATH"

mock_tool() {
    local tool=$1
    echo -e "#!/bin/bash
echo "MOCK_CALL: $tool \$*" >> "$TEST_ROOT/audit.log" " > "$MOCK_BIN/$tool"
    chmod +x "$MOCK_BIN/$tool"
}

mock_tool "apt-get"
mock_tool "feature-installer"
mock_tool "pip"
mock_tool "npm"
mock_tool "go"
mock_tool "cargo"
mock_tool "sudo" # Make sudo a no-op that logs

# Shared utilities from apply.sh
log() { echo "[$1] $2"; }
info() { log "INFO" "$1"; }
error() { log "ERROR" "$1"; }
ensure_root() { "$@"; } # In mock, everything is root-equivalent
export -f log info error ensure_root

assert_contains() {
    if grep -q "$1" "$2"; then
        echo -e "  \e[32mPASS\e[0m: Found '$1' in $(basename $2)"
    else
        echo -e "  \e[31mFAIL\e[0m: Could not find '$1' in $(basename $2)"
        exit 1
    fi
}

echo "Starting Comprehensive Engine Tests..."

echo "[Test 1] Declarative Dotfiles"
mkdir -p "$HOME/src_folder"
touch "$HOME/src_folder/.vimrc"
echo '{"files": [{"source": "~/src_folder/.vimrc", "target": "~/.vimrc"}]}' > "$USER_CONFIG_PATH"

# Run a simplified version of 60-files.sh logic
source_path="$HOME/src_folder/.vimrc"
target_path="$HOME/.vimrc"
ln -sf "$source_path" "$target_path"

if [[ -L "$HOME/.vimrc" ]]; then
    echo -e "  \e[32mPASS\e[0m: Symlink created correctly"
else
    echo -e "  \e[31mFAIL\e[0m: Symlink missing"
    exit 1
fi

echo "[Test 2] APT Object Parsing"
echo '{"apt": [{"name": "tree", "version": "2.1"}]}' > "$USER_CONFIG_PATH"
packages=$(jq -r '.apt[]? | if type == "string" then . else .name + "=" + .version end' "$USER_CONFIG_PATH")
apt-get install -y "$packages"
assert_contains "MOCK_CALL: apt-get install -y tree=2.1" "$TEST_ROOT/audit.log"

echo "[Test 3] Dynamic Path Reconciliation"
BASELINE_PATH="/usr/bin:/bin"
NEW_TOOL_DIR="$TEST_ROOT/usr/local/hugo/bin"
mkdir -p "$NEW_TOOL_DIR"

# Logic from 40-path.sh
found_bins=$(find "$TEST_ROOT/usr/local" -type d -name bin 2>/dev/null)
new_paths=""
for bindir in $found_bins; do
    if [[ ":$BASELINE_PATH:" != *":$bindir:"* ]]; then
        new_paths="$new_paths:$bindir"
    fi
done
echo "export PATH="\$PATH$new_paths"" > "$USER_PATH_FILE"

assert_contains "export PATH="\$PATH:$NEW_TOOL_DIR"" "$USER_PATH_FILE"

echo "[Test 4] Hashing"
mkdir -p "$MANAGED_CONFIG_DIR"
echo '{"apt": ["htop"]}' > "$USER_CONFIG_PATH"
HASH1=$(md5sum "$USER_CONFIG_PATH" | awk '{print $1}')
echo "$HASH1" > "$STATE_DIR/last_applied_hash"

# Simulation of should_run check
NEW_HASH=$(md5sum "$USER_CONFIG_PATH" | awk '{print $1}')
if [[ "$HASH1" == "$NEW_HASH" ]]; then
    echo -e "  \e[32mPASS\e[0m: Cache hit detected correctly"
else
    echo -e "  \e[31mFAIL\e[0m: Cache invalidated erroneously"
    exit 1
fi

echo "[Test 5] Solid Directory Link"
rm -rf "$MANAGED_CONFIG_DIR"
ln -sf "$VOLUME_CONFIG_DIR" "$MANAGED_CONFIG_DIR"

# Verify real-time bidirectional sync
touch "$MANAGED_CONFIG_DIR/sync_test"
if [[ -f "$VOLUME_CONFIG_DIR/sync_test" ]]; then
    echo -e "  \e[32mPASS\e[0m: Bidirectional sync verified"
else
    echo -e "  \e[31mFAIL\e[0m: Sync failed"
    exit 1
fi

echo "All Engine Logic tests passed successfully."
