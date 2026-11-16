#!/bin/bash
# 用最新发布的 DMG 更新本地 Cask 配方里的 version / sha256。
# 用法：scripts/update-cask.sh v0.3.6
set -euo pipefail
cd "$(dirname "$0")/.."
TAG="${1:?用法: scripts/update-cask.sh vX.Y.Z}"
VERSION="${TAG#v}"
DMG="LyricsMTMR-${TAG}.dmg"
URL="https://github.com/Tangzishun-Li/LyricsMTMR/releases/download/${TAG}/${DMG}"
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
curl -fsSL "$URL" -o "$TMP"
SHA=$(shasum -a 256 "$TMP" | awk '{print $1}')
CASK="packaging/homebrew/Casks/lyricsmtmr.rb"
python3 - "$CASK" "$VERSION" "$SHA" <<'PY'
import re, sys
path, version, sha = sys.argv[1:4]
text = open(path).read()
text = re.sub(r'version "[^"]*"', f'version "{version}"', text, count=1)
text = re.sub(r'sha256 "[^"]*"', f'sha256 "{sha}"', text, count=1)
open(path, "w").write(text)
print(f"cask 已更新：version={version} sha256={sha[:16]}…")
PY
