#!/bin/bash

# Change directory to your project root
cd "$(dirname "$0")/.."

# Ensure SwiftLint is available (installed through SPM)
if which swiftlint >/dev/null; then
    swiftlint
else
    echo "SwiftLint is not installed, skipping linting."
fi
