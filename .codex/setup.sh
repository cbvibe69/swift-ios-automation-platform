#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Swift iOS Automation Platform Setup"
echo "======================================"

# Display Swift version
echo "📍 Checking Swift version"
swift --version

# Display Xcode version if available
echo "📍 Checking Xcode version"
if command -v xcodebuild >/dev/null 2>&1; then
  xcodebuild -version
else
  echo "⚠️  xcodebuild not found - please install Xcode command line tools"
fi

# Clean any existing package cache/build artifacts
echo "🧹 Cleaning package cache and build artifacts"
if [ -d ".build" ]; then
  rm -rf .build
  echo "   Removed .build directory"
fi

if [ -d "Package.resolved" ]; then
  rm -f Package.resolved
  echo "   Removed Package.resolved"
fi

# Clear Swift package cache for this project
echo "🧹 Clearing Swift package cache"
swift package clean

# Reset and resolve package dependencies
echo "📦 Resolving Swift package dependencies"
swift package resolve

# Attempt to build to verify everything works
echo "🔨 Testing build"
swift build --configuration debug

echo "✅ Setup complete! Your Swift iOS Automation Platform is ready."
echo ""
echo "Next steps:"
echo "  1. Run: swift run XcodeAutomationServer --help"
echo "  2. Check documentation in ./Documentation/"
echo "  3. Review examples in ./Sources/"
