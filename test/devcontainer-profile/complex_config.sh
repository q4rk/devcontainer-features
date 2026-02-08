#!/bin/bash
set -e
source dev-container-features-test-lib

echo ">>> Scenario: Complex Configuration"

# Setup: Create a config that uses multiple features
cat <<EOF > "$HOME/.devcontainer.profile"
{
    "apt": ["sl"],
    "env": { "SCENARIO_TEST": "TRUE" },
    "scripts": ["touch $HOME/script_ran"]
}
EOF

# Run Engine
/usr/local/share/devcontainer-profile/scripts/apply.sh

# Verify APT
check "APT installed 'sl'" command -v sl

# Verify Env (Sourcing required)
source "$HOME/.devcontainer.profile_env"
check "Env var set" [ "$SCENARIO_TEST" == "TRUE" ]

# Verify Scripts
check "Script executed" test -f "$HOME/script_ran"

reportResults