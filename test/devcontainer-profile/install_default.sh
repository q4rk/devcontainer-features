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

# 1. Filesystem check
check "apply.sh exists" test -x /usr/local/share/devcontainer-profile/scripts/apply.sh
check "plugins exist" test -d /usr/local/share/devcontainer-profile/plugins
check "lib exists" test -f /usr/local/share/devcontainer-profile/lib/utils.sh

# 2. Path check
check "PATH includes feature bin" bash -c "echo $PATH | grep -q '/usr/local/bin'"

reportResults
