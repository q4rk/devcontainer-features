#!/bin/bash
set -e

echo "Running standard tests..."
devcontainer features test -f devcontainer-profile --project-folder .

echo "Running scenario tests..."
devcontainer features test --scenarios test/devcontainer-profile --project-folder .
