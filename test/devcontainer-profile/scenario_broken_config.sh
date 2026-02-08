#!/bin/bash
set -e
source dev-container-features-test-lib

echo ">>> Scenario: Broken Configuration (Fail Soft)"

# 1. Inject Invalid JSON
mkdir -p "$HOME/.devcontainer-profile"
echo '{ "invalid": "json", broken_comma, }' > "$HOME/.devcontainer-profile/config.json"

# 2. Run Engine (Should NOT exit 1)
if /usr/local/share/devcontainer-profile/scripts/apply.sh; then
    check "Engine survived invalid JSON" true
else
    check "Engine survived invalid JSON" false
fi

# 3. Verify Log
LOG_FILE="/var/tmp/devcontainer-profile/state/profile.log"
if grep -qi "error" "$LOG_FILE"; then
    check "Errors logged to file" true
else
    check "Errors logged to file" false
    cat "$LOG_FILE"
fi

reportResults