#!/bin/bash
set -e

# Import test library
source dev-container-features-test-lib

# Integration checks: Verify installation
check "apply.sh is installed" ls /usr/local/share/devcontainer-profile/scripts/apply.sh
check "plugins are installed" ls /usr/local/share/devcontainer-profile/plugins/10-apt.sh

# Logic checks: Run unit tests
check "unit-test-engine" ./test_engine.sh
check "unit-test-parsing" ./test_parsing.sh
check "unit-test-plugins" ./test_plugins.sh
check "unit-test-xdg" ./test_xdg.sh

reportResults
