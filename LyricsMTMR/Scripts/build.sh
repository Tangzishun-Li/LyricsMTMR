#!/bin/bash
# Build the app (Debug configuration).
set -euo pipefail
cd "$(dirname "$0")/.."
DERIVED=".build/DerivedData"
xcodebuild build \
  -project LyricsMTMR.xcodeproj \
  -scheme MTMR \
  -configuration Debug \
  -derivedDataPath "$DERIVED"
echo "✅ Built: $DERIVED/Build/Products/Debug/LyricsMTMR.app"
