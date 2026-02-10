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

# 3. edit-profile
export EDITOR="echo"
OUTPUT=$(edit-profile)
check "edit-profile respects EDITOR" [[ "$OUTPUT" == *"/config.json"* ]]

# 4. edit-profile (VS Code Priority)
# Backup existing code binary if it exists
if [ -f /usr/local/bin/code ]; then
    mv /usr/local/bin/code /usr/local/bin/code.bak
fi

# Create a mock 'code' command in /usr/local/bin
echo '#!/bin/bash' > /usr/local/bin/code
echo 'echo "VS Code opened args: $@"' >> /usr/local/bin/code
chmod +x /usr/local/bin/code

OUTPUT_CODE=$(edit-profile 2>&1)
if [[ "$OUTPUT_CODE" == *"VS Code opened"* ]]; then
    check "edit-profile prefers code" true
else
    echo "(!) edit-profile failed. Output: $OUTPUT_CODE"
    check "edit-profile prefers code" false
fi

rm /usr/local/bin/code
if [ -f /usr/local/bin/code.bak ]; then
    mv /usr/local/bin/code.bak /usr/local/bin/code
fi

reportResults
