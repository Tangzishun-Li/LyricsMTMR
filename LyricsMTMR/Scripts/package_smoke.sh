#!/bin/bash
# 发布前打包冒烟：不做签名（CI/PR 没有私钥），只验证"这个 tag 打得出来、打得对"。
# 目标是把"archive 挂了 / Sparkle 没嵌进去 / Info.plist 版本号没改 / feed 地址写错"
# 这类事故挡在打 tag 之前，而不是等 release 上传失败才发现。
#
# 用法：Scripts/package_smoke.sh [--keep]
# 退出码：0 = 通过；1 = 有检查失败。
set -euo pipefail
cd "$(dirname "$0")/.."

KEEP_ZIP=0
[ "${1:-}" = "--keep" ] && KEEP_ZIP=1

ARCHIVE="Release/LyricsMTMR.xcarchive"
APP="$ARCHIVE/Products/Applications/LyricsMTMR.app"
BIN="$APP/Contents/MacOS/LyricsMTMR"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fail() { echo "[FAIL] $*" >&2; exit 1; }
pass() { echo "[PASS] $*"; }

echo "== 1/6 archive（unsigned, universal）"
rm -rf "$ARCHIVE"
# 本机构建必须过全机串行锁（docs/构建资源护栏.md）；CI 没有该脚本时直接跑。
if [ -f ../scripts/build-with-lock.sh ]; then
  BUILD_CMD=(sh ../scripts/build-with-lock.sh xcodebuild)
else
  BUILD_CMD=(xcodebuild)
fi
"${BUILD_CMD[@]}" archive \
  -project LyricsMTMR.xcodeproj \
  -scheme MTMR \
  -configuration Release \
  -archivePath "$ARCHIVE" \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_ALLOWED=NO \
  ARCHS="arm64 x86_64" \
  > "$WORK/archive.log" 2>&1 || { tail -40 "$WORK/archive.log" >&2; fail "xcodebuild archive 失败"; }
test -d "$APP" || fail "archive 里没有 $APP"
pass "archive 产物存在"

echo "== 2/6 通用二进制"
lipo -info "$BIN" | tee "$WORK/lipo.txt"
grep -q arm64 "$WORK/lipo.txt" || fail "缺少 arm64 架构"
grep -q x86_64 "$WORK/lipo.txt" || fail "缺少 x86_64 架构"
pass "arm64 + x86_64"

echo "== 3/6 Sparkle 与关键资源"
test -d "$APP/Contents/Frameworks/Sparkle.framework" || fail "Sparkle.framework 未嵌入（自动更新会失效）"
pass "Sparkle.framework 已嵌入"
for res in "Contents/Resources/items.json"; do
  test -e "$APP/$res" || fail "缺少资源 $res"
done
pass "默认预设 items.json 已打包"

echo "== 4/6 Info.plist 关键字段"
SHORT=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist" 2>/dev/null || true)
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP/Contents/Info.plist" 2>/dev/null || true)
FEED=$(/usr/libexec/PlistBuddy -c "Print :SUFeedURL" "$APP/Contents/Info.plist" 2>/dev/null || true)
KEY=$(/usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" "$APP/Contents/Info.plist" 2>/dev/null || true)
[[ "$SHORT" =~ ^[0-9]+(\.[0-9]+)+([-.][A-Za-z0-9.]+)?$ ]] || fail "CFBundleShortVersionString 非法：'$SHORT'"
[[ "$BUILD" =~ ^[0-9]+$ ]] || fail "CFBundleVersion 必须是数字：'$BUILD'"
[[ "$FEED" == https://* ]] || fail "SUFeedURL 必须是 https：'$FEED'"
[[ ${#KEY} -eq 44 ]] || fail "SUPublicEDKey 长度应为 44（base64 Ed25519 公钥）：'$KEY'"
pass "版本 $SHORT ($BUILD)，feed=$FEED，EdDSA 公钥在位"

echo "== 5/6 打包 zip 并校验结构"
ZIP="$WORK/smoke.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
unzip -tq "$ZIP" >/dev/null || fail "zip 损坏"
# 先落文件再 grep：`unzip -l | grep -q` 会让 unzip 吃到 SIGPIPE，在 pipefail 下误报失败
unzip -Z1 "$ZIP" > "$WORK/ziplist.txt"
grep -qx "LyricsMTMR.app/Contents/MacOS/LyricsMTMR" "$WORK/ziplist.txt" || fail "zip 内没有主可执行文件"
SIZE=$(stat -f%z "$ZIP")
[ "$SIZE" -gt 1000000 ] || fail "zip 太小（$SIZE bytes），可能漏打资源"
pass "zip 结构正常（$((SIZE / 1024 / 1024)) MB）"

echo "== 6/6 版本号 ↔ tag（打 tag 时才有）"
if [ -n "${GITHUB_REF_NAME:-}" ]; then
  TAG_VERSION=$(printf '%s' "$GITHUB_REF_NAME" | sed -E 's/^v//; s/-.*$//')
  case "$SHORT" in
    "$TAG_VERSION"*) pass "tag=$GITHUB_REF_NAME 与版本 $SHORT 一致" ;;
    *) fail "tag=$GITHUB_REF_NAME 与 CFBundleShortVersionString=$SHORT 不一致（发版前先改 Info.plist 版本号）" ;;
  esac
else
  pass "本地运行，跳过 tag 比对"
fi

if [ "$KEEP_ZIP" -eq 1 ]; then
  cp "$ZIP" "./LyricsMTMR-smoke.zip"
  echo "保留产物：./LyricsMTMR-smoke.zip"
fi

echo "✅ 打包冒烟全部通过"
