#!/bin/bash
set -e
source dev-container-features-test-lib

echo ">>> Scenario: Root User"

check "Running as root" [ "$(id -u)" -eq 0 ]

echo '{"env": {"ROOT_TEST": "1"}}' > "/root/.devcontainer.profile"

/usr/local/share/devcontainer-profile/scripts/apply.sh

source "/root/.devcontainer.profile_env"
check "Root env applied" [ "$ROOT_TEST" == "1" ]

reportResults