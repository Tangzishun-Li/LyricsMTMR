#!/bin/bash
# Build the app (Release configuration).
set -euo pipefail
cd "$(dirname "$0")/.."
DERIVED=".build/DerivedData"

# Release 配置绑定的是发布团队（见 project.pbxproj，本机通常没有该证书），直接
# xcodebuild 会报 “No signing certificate”。本地构建自动改用本机可用的开发团队，
# 找不到任何签名证书时退回不签名（与 archive.sh 的口径一致）。
SIGN_ARGS=()
TEAM="$(xcodebuild -project LyricsMTMR.xcodeproj -scheme MTMR -configuration Debug \
  -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/^ *DEVELOPMENT_TEAM = /{print $2; exit}')"
if [ -z "${TEAM:-}" ]; then
  # 后备：从本机 Apple Development 证书的 OU 字段取 Team ID。
  TEAM="$(security find-certificate -c "Apple Development" -p 2>/dev/null \
    | openssl x509 -noout -subject -nameopt sep_multiline 2>/dev/null \
    | sed -n 's/^ *OU=//p' | head -1)"
fi
HAS_IDENTITY=0
if security find-identity -v -p codesigning 2>/dev/null | grep -q "Apple Development"; then
  HAS_IDENTITY=1
fi
if [ -n "${TEAM:-}" ] && [ "$HAS_IDENTITY" -eq 1 ]; then
  SIGN_ARGS=(
    "DEVELOPMENT_TEAM=${TEAM}"
    "CODE_SIGN_STYLE=Automatic"
    "CODE_SIGN_IDENTITY=Apple Development"
  )
else
  echo "⚠️  本机没有可用的 Apple Development 证书，改为不签名构建（TCC 权限可能在每次重装后失效）"
  SIGN_ARGS=("CODE_SIGNING_ALLOWED=NO")
fi

echo "🔏 本地签名：${SIGN_ARGS[*]}"
xcodebuild build \
  -project LyricsMTMR.xcodeproj \
  -scheme MTMR \
  -configuration Release \
  -derivedDataPath "$DERIVED" \
  "${SIGN_ARGS[@]}"
echo "✅ Built: $DERIVED/Build/Products/Release/LyricsMTMR.app"
