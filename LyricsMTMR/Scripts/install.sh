#!/bin/bash
# 把最新构建安装到 /Applications，让启动台 / 聚焦 / Dock 打开的就是最新版本。
#
# 为什么需要这一步：
#   Launchpad 里的 LyricsMTMR 图标指向 /Applications/LyricsMTMR.app，
#   而 Xcode 的 ⌘R / ⌘B 只更新 ~/Library/Developer/Xcode/DerivedData 下的产物，
#   不会自动替换 /Applications 里的已安装副本。
#
# 用法：
#   Scripts/install.sh                  # 先构建 Release，再安装
#   Scripts/install.sh --no-build       # 只安装已有构建产物
#   Scripts/install.sh --bump           # 构建前把 CFBundleVersion +1（能区分新旧）
#   Scripts/install.sh --refresh-dock   # 安装后重启 Dock，刷新启动台图标缓存
#   Scripts/install.sh /path/to/App.app # 安装指定 .app（隐含 --no-build）
#
# 安装前会自动把旧版本备份到 ~/Library/Application Support/LyricsMTMR/Backups/（保留最近 3 份）。
# 首次运行可能弹「App 管理」权限；允许终端/编辑器修改 App 即可，无需 sudo。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."

DEST="/Applications/LyricsMTMR.app"
APP=".build/DerivedData/Build/Products/Release/LyricsMTMR.app"
PLIST="MTMR/Info.plist"
BACKUP_DIR="${LYRICSMTMR_BACKUP_DIR:-$HOME/Library/Application Support/LyricsMTMR/Backups}"
KEEP_BACKUPS=3

DO_BUILD=1
DO_BUMP=0
REFRESH_DOCK=0
SOURCE=""

usage() {
  cat <<'EOF'
把最新构建安装到 /Applications，让启动台 / 聚焦 / Dock 打开的就是最新版本。

用法：
  Scripts/install.sh                  # 先构建 Release，再安装
  Scripts/install.sh --no-build       # 只安装已有构建产物
  Scripts/install.sh --bump           # 构建前把 CFBundleVersion +1（能区分新旧）
  Scripts/install.sh --refresh-dock   # 安装后重启 Dock，刷新启动台图标缓存
  Scripts/install.sh /path/to/App.app # 安装指定 .app（隐含 --no-build）

安装前会自动备份旧版本到 ~/Library/Application Support/LyricsMTMR/Backups/（保留最近 3 份）。
EOF
}

for arg in "$@"; do
  case "$arg" in
    --no-build) DO_BUILD=0 ;;
    --bump) DO_BUMP=1 ;;
    --refresh-dock) REFRESH_DOCK=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "❌ 未知参数：$arg" >&2; exit 2 ;;
    *) SOURCE="$arg"; DO_BUILD=0 ;;
  esac
done
if [ -n "$SOURCE" ]; then
  APP="$SOURCE"
fi

# 安全检查：脚本只会删除这一个固定路径，绝不接受别的目标。
if [ "$DEST" != "/Applications/LyricsMTMR.app" ]; then
  echo "❌ 目标路径异常：$DEST" >&2
  exit 1
fi

if [ "$DO_BUMP" -eq 1 ] && [ "$DO_BUILD" -eq 1 ]; then
  OLD_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")"
  NEW_BUILD="$((OLD_BUILD + 1))"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_BUILD" "$PLIST"
  echo "→ build 号：$OLD_BUILD → $NEW_BUILD（修改了 $PLIST，提交前留意）"
fi

if [ "$DO_BUILD" -eq 1 ]; then
  ./Scripts/build.sh
fi

if [ ! -d "$APP" ]; then
  echo "❌ 找不到构建产物：$APP" >&2
  echo "   请先执行 make build，或去掉 --no-build。" >&2
  exit 1
fi

echo "→ 退出正在运行的 LyricsMTMR …"
pkill -x LyricsMTMR 2>/dev/null || true
# 退出时 run.pl（MediaRemote 桥）可能残留成孤儿进程，一并清掉。
pkill -f 'LyricsMTMR\.app/Contents/Resources/run\.pl' 2>/dev/null || true
sleep 1

# 安装前备份旧版本，出问题可回滚。
if [ -d "$DEST" ]; then
  mkdir -p "$BACKUP_DIR"
  OLD_SHORT="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$DEST/Contents/Info.plist" 2>/dev/null || echo unknown)"
  OLD_BUILD_NO="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$DEST/Contents/Info.plist" 2>/dev/null || echo 0)"
  BACKUP="$BACKUP_DIR/LyricsMTMR-${OLD_SHORT}-${OLD_BUILD_NO}-$(date +%Y%m%d-%H%M%S).app"
  echo "→ 备份旧版本到：$BACKUP"
  ditto "$DEST" "$BACKUP"
  # 只保留最近 $KEEP_BACKUPS 份
  ls -1dt "$BACKUP_DIR"/LyricsMTMR-*.app 2>/dev/null | tail -n +"$((KEEP_BACKUPS + 1))" | while read -r old; do
    rm -rf "$old"
  done
fi

echo "→ 安装：$APP"
echo "     到：$DEST"
rm -rf "$DEST"
ditto "$APP" "$DEST"

LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$LSREG" -f "$DEST" || true

# xcodebuild 构建时会把自己产物注册进 LaunchServices（-trusted）；这里把构建产物
# 注销掉，避免「按 bundle id 打开 / 打开方式」命中 DerivedData 里的副本。
ABS_SRC="$(cd "$(dirname "$APP")" && pwd)/$(basename "$APP")"
if [ "$ABS_SRC" != "$DEST" ]; then
  "$LSREG" -u "$ABS_SRC" 2>/dev/null || true
fi

if [ "$REFRESH_DOCK" -eq 1 ]; then
  echo "→ 重启 Dock（刷新启动台图标/缓存）…"
  killall Dock 2>/dev/null || true
fi

echo "✅ 已安装到 $DEST"
printf '   版本：%s (%s)\n' \
  "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$DEST/Contents/Info.plist")" \
  "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$DEST/Contents/Info.plist")"
stat -f '   二进制构建时间：%Sm' -t '%F %T' "$DEST/Contents/MacOS/LyricsMTMR"
echo
echo "提示：下一行可核对启动台副本与构建产物是否同一份："
echo "   shasum -a 256 '$DEST/Contents/MacOS/LyricsMTMR' '$PWD/$APP/Contents/MacOS/LyricsMTMR'"
