#!/bin/bash
# 01-diagnostics.sh - System health check
source "${LIB_PATH}"

info "Diagnostics" "User: ${TARGET_USER} (UID: $(id -u))"
info "Diagnostics" "Home: ${TARGET_HOME}"
info "Diagnostics" "Config: ${USER_CONFIG_PATH}"

check_loc() {
    local cmd="$1"
    local loc
    loc=$(type -P "$cmd" 2>/dev/null || true)
    if [[ -n "$loc" ]]; then
        info "  > Binary '$cmd' found at: $loc"
    else
        info "  > Binary '$cmd' NOT in PATH"
    fi
}

info "[Diagnostics] Toolchain Probe:"
check_loc "cargo"
check_loc "rustup"
check_loc "go"
check_loc "pip"
check_loc "npm"
check_loc "gem"
check_loc "python3"
check_loc "node"


check_tool() {
    if command -v "$1" >/dev/null 2>&1; then
        info "Diagnostics" "Found: $1 ($(command -v "$1"))"
    else
        info "Diagnostics" "Missing: $1"
    fi
}

check_tool jq
check_tool curl
check_tool git
check_tool code