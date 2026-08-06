#!/bin/bash
# Run unit tests (Debug configuration).
set -euo pipefail
cd "$(dirname "$0")/.."
DERIVED=".build/DerivedData"
xcodebuild test \
  -project LyricsMTMR.xcodeproj \
  -scheme UnitTests \
  -configuration Debug \
  -derivedDataPath "$DERIVED"
