#!/bin/bash
#
# MediaRemote Debug Dumper — 编译 & 运行
#
# 用法:
#   ./run_dump.sh          # 编译并运行（监听模式）
#   ./run_dump.sh build    # 仅编译
#   ./run_dump.sh clean    # 清理产物
#
# 测试流程:
#   1. 运行本脚本
#   2. 在浏览器中播放 YouTube 视频 → 观察输出
#   3. 在浏览器中播放 B站 视频 → 观察输出
#   4. 打开 QQ音乐/网易云/Apple Music 播放歌曲 → 观察输出
#   5. 对比各来源的字段差异，特别关注 🔑 标记的字段:
#      - isMusicApp        (布尔，是否音乐应用)
#      - mediaType          (数字，媒体类型枚举)
#      - album              (视频通常为空)
#      - externalContentIdentifier  (可能含 URL/ID)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$SCRIPT_DIR/mr_dump.m"
BIN="$SCRIPT_DIR/mr_dump"

build() {
    echo "🔨 Compiling mr_dump..."
    clang \
        -framework Foundation \
        -framework CoreFoundation \
        -O2 \
        -o "$BIN" \
        "$SRC"
    echo "✅ Built: $BIN"
}

clean() {
    rm -f "$BIN"
    echo "🧹 Cleaned."
}

case "${1:-run}" in
    build)
        build
        ;;
    clean)
        clean
        ;;
    run|*)
        [ -f "$BIN" ] || build
        echo ""
        echo "🚀 Starting mr_dump (Ctrl+C to stop)..."
        echo "────────────────────────────────────────────"
        exec "$BIN"
        ;;
esac
