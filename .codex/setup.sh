#!/usr/bin/env bash
set -euo pipefail

# Display Swift version
echo "Checking Swift version"
swift --version

# Display Xcode version if available
echo "Checking Xcode version"
if command -v xcodebuild >/dev/null 2>&1; then
  xcodebuild -version
else
  echo "xcodebuild not found"
fi

# Resolve package dependencies
echo "Resolving Swift package dependencies"
swift package resolve
