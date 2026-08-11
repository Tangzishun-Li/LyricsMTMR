#!/bin/bash
# Build the app (Release configuration).
set -euo pipefail
cd "$(dirname "$0")/.."
DERIVED=".build/DerivedData"
xcodebuild build \
  -project LyricsMTMR.xcodeproj \
  -scheme MTMR \
  -configuration Release \
  -derivedDataPath "$DERIVED"
echo "✅ Built: $DERIVED/Build/Products/Release/LyricsMTMR.app"
