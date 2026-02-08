#!/bin/bash
# 30-languages.sh - Polyglot package manager support
source "${LIB_PATH}"


# Helper: Extract binary name, defaulting if necessary
# Usage: get_tool_bin "pip" "pip"
get_tool_bin() {
    local key="$1"
    local default="$2"
    if [[ -f "${USER_CONFIG_PATH}" ]]; then
        # Check if it's an object with a 'bin' key, otherwise use default
        jq -r ".[\"${key}\"] | if type==\"object\" then (.bin // \"${default}\") else \"${default}\" end" "${USER_CONFIG_PATH}" 2>/dev/null
    else
        echo "$default"
    fi
}

# Helper: Extract packages list regardless of format
# Usage: get_tool_pkgs "pip"
get_tool_pkgs() {
    local key="$1"
    if [[ -f "${USER_CONFIG_PATH}" ]]; then
        # Handle Array (direct list) OR Object (.packages list)
        jq -r ".[\"${key}\"] | if type==\"object\" then .packages[]? else .[]? end" "${USER_CONFIG_PATH}" 2>/dev/null
    fi
}

# Helper to resolve binaries (Check PATH, then common locations)
resolve_binary() {
    local cmd="$1"
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "$cmd"
        return 0
    fi
    
    # Check specific high-probability locations only (Optimization)
    local candidates=(
        "${TARGET_HOME}/.cargo/bin/${cmd}"
        "${TARGET_HOME}/go/bin/${cmd}"
        "${TARGET_HOME}/.local/bin"
        "/usr/local/cargo/bin"
        "/usr/local/rustup/bin"
        "/usr/local/go/bin/${cmd}"
        "/usr/local/bin/${cmd}"
        "/usr/local/go/bin"
        "/usr/local/bin"
        "/usr/bin"
        "/bin"
        "/usr/games"
    )
    for c in "${candidates[@]}"; do
        if [[ -x "$c" ]]; then
            echo "$c"
            return 0
        fi
    done
    return 1
}
install_pip() {
    local packages
    packages=$(get_tool_pkgs "pip")
    [[ -z "$packages" ]] && return 0

    # Determine binary name (e.g. "pip" or "pip3.11")
    local raw_bin_name
    raw_bin_name=$(get_tool_bin "pip" "pip")
    
    # Resolve absolute path or valid command
    local pip_bin
    pip_bin=$(resolve_binary "$raw_bin_name")
    
    if [[ -n "$pip_bin" ]]; then
        info "Pip" "Installing packages using '$raw_bin_name'..."
        local args=("install" "--user" "--upgrade")
        
        # Check for PEP 668 compliance (Debian 12+)
        if "$pip_bin" install --help 2>&1 | grep -q "break-system-packages"; then
            args+=("--break-system-packages")
        fi
        
        mapfile -t pkg_array <<< "$packages"
        "$pip_bin" "${args[@]}" "${pkg_array[@]}" || warn "Pip" "Installation failed"
    else
        warn "Pip" "Binary '$raw_bin_name' not found. Skipping."
    fi
}

install_npm() {
    local packages
    packages=$(get_tool_pkgs "npm")
    [[ -z "$packages" ]] && return 0

    local raw_bin_name
    raw_bin_name=$(get_tool_bin "npm" "npm")
    local npm_bin
    npm_bin=$(resolve_binary "$raw_bin_name")

    if [[ -n "$npm_bin" ]]; then
        info "Npm" "Installing global packages using '$raw_bin_name'..."
        mapfile -t pkg_array <<< "$packages"
        "$npm_bin" install -g "${pkg_array[@]}" || warn "Npm" "Installation failed"
    else
        warn "Npm" "Binary '$raw_bin_name' not found. Skipping."
    fi
}

install_go() {
    local packages
    packages=$(get_tool_pkgs "go")
    [[ -z "$packages" ]] && return 0

    local raw_bin_name
    raw_bin_name=$(get_tool_bin "go" "go")
    local go_bin
    go_bin=$(resolve_binary "$raw_bin_name")

    if [[ -n "$go_bin" ]]; then
        info "Go" "Installing tools using '$raw_bin_name'..."
        while IFS= read -r pkg; do
             [[ -z "$pkg" ]] && continue
             [[ "$pkg" != *"@"* ]] && pkg="${pkg}@latest"
             "$go_bin" install "$pkg" || warn "Go" "Failed: $pkg"
        done <<< "$packages"
    else
        warn "Go" "Binary '$raw_bin_name' not found. Skipping."
    fi
}

install_cargo() {
    local packages
    packages=$(get_tool_pkgs "cargo")
    [[ -z "$packages" ]] && return 0
    
    local raw_bin_name
    raw_bin_name=$(get_tool_bin "cargo" "cargo")
    local cargo_bin
    cargo_bin=$(resolve_binary "$raw_bin_name")

    if [[ -n "$cargo_bin" ]]; then
        info "Cargo" "Installing crates using '$raw_bin_name'..."
        
        # Optimization: Update registry index once
        "$cargo_bin" search --limit 1 verify-network >/dev/null 2>&1 || true

        while IFS= read -r pkg; do
            [[ -z "$pkg" ]] && continue
            "$cargo_bin" install "$pkg" || warn "Cargo" "Failed: $pkg"
        done <<< "$packages"
    else
        warn "Cargo" "Binary '$raw_bin_name' not found. Skipping."
    fi
}

install_pip
install_npm
install_go
install_cargo