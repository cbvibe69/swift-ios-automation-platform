#!/usr/bin/env bash
set -euo pipefail

# Resolve Swift package dependencies and run a basic build/test cycle
swift package resolve
swift build
swift test --parallel

