#!/bin/bash
set -e
source dev-container-features-test-lib

echo ">>> Scenario: Default Installation"

# Ensure logs are printed on exit (success or failure)
show_logs() {
    echo ">>> Final Profile Log: Scenario: Default Installation"
    cat /var/tmp/devcontainer-profile/state/profile.log 2>/dev/null || echo "(Log file empty or missing)"
}
trap show_logs EXIT

# Filesystem check
check "apply.sh exists" test -x /usr/local/share/devcontainer-profile/scripts/apply.sh
check "plugins exist" test -d /usr/local/share/devcontainer-profile/plugins
check "lib exists" test -f /usr/local/share/devcontainer-profile/lib/utils.sh
check "apply-profile symlink exists" test -L /usr/local/bin/apply-profile
check "apply-profile is executable" test -x /usr/local/bin/apply-profile
check "edit-profile script exists" test -f /usr/local/bin/edit-profile
check "edit-profile is executable" test -x /usr/local/bin/edit-profile

# edit-profile (EDITOR Fallback)
# We use a subshell to isolate PATH changes
(
    # Create a temp dir for mocks
    MOCK_DIR=$(mktemp -d)
    
    # We want to hide 'code'. 
    # If 'code' is in /usr/local/bin, we can't hide it by appending to PATH.
    # We can only hide it if we PREPEND a mock that returns 'command not found' (exit 127)?
    # No, 'command -v' checks existence.
    
    # If we can't hide the system 'code', we can't test the fallback easily in this environment.
    # So we skip this check if 'code' is present.
    if ! command -v code >/dev/null 2>&1; then
        export EDITOR="echo"
        OUTPUT=$(edit-profile)
        check "edit-profile respects EDITOR" [[ "$OUTPUT" == *"/config.json"* ]]
    else
        echo "(!) Skipping EDITOR fallback test because 'code' is present in the base image."
    fi
    rm -rf "$MOCK_DIR"
)

# edit-profile (VS Code Priority)
(
    MOCK_DIR=$(mktemp -d)
    # Create mock code
    echo '#!/bin/bash' > "$MOCK_DIR/code"
    echo 'echo "VS Code opened args: $@"' >> "$MOCK_DIR/code"
    chmod +x "$MOCK_DIR/code"
    
    # Prepend to PATH so our mock is found first
    export PATH="$MOCK_DIR:$PATH"
    hash -r # Clear cache
    
    OUTPUT_CODE=$(edit-profile 2>&1)
    if [[ "$OUTPUT_CODE" == *"VS Code opened"* ]]; then
        check "edit-profile prefers code" true
    else
        echo "(!) edit-profile failed. Output: $OUTPUT_CODE"
        echo "Debug: PATH=$PATH"
        echo "Debug: which code -> $(which code)"
        check "edit-profile prefers code" false
    fi
    
    rm -rf "$MOCK_DIR"
)



# show-profile-logs
check "show-profile-logs script exists" test -f /usr/local/bin/show-profile-logs
check "show-profile-logs is executable" test -x /usr/local/bin/show-profile-logs

# It should output something (the log file exists)
OUTPUT_LOGS=$(show-profile-logs)
check "show-profile-logs outputs content" [[ -n "$OUTPUT_LOGS" ]]

reportResults
