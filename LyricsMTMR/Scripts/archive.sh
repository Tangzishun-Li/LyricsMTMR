#!/bin/bash
# Archive a universal (arm64 + x86_64) unsigned build.
# Usage: Scripts/archive.sh [archive-path]
set -euo pipefail
cd "$(dirname "$0")/.."
ARCHIVE_PATH="${1:-Release/LyricsMTMR.xcarchive}"
xcodebuild archive \
  -project LyricsMTMR.xcodeproj \
  -scheme MTMR \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_ALLOWED=NO \
  ARCHS="arm64 x86_64"
echo "✅ Archive: $ARCHIVE_PATH"
echo "  Verify universal binary: lipo -info $ARCHIVE_PATH/Products/Applications/LyricsMTMR.app/Contents/MacOS/LyricsMTMR"
