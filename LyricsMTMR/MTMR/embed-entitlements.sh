#!/bin/bash
set -e
APP="$TARGET_BUILD_DIR/$PRODUCT_NAME.app"
ENT="$SRCROOT/MTMR/MTMR.entitlements"
if [ -f "$ENT" ] && [ -d "$APP" ]; then
    echo "Re-signing with entitlements for media access..."
    codesign -f -s - --entitlements "$ENT" "$APP"
    echo "Entitlements embedded."
fi
