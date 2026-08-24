#!/bin/bash
# 用法: measure.sh <label> <derivedDataPath> <xcodebuild 额外参数...>
# 输出: /tmp/r62d-<label>-build.log   构建完整输出
#       /tmp/r62d-<label>-time.txt    /usr/bin/time -l 结果
#       /tmp/r62d-<label>-mem.log     每 0.5s 一行：swift/clang/xcodebuild/ld 进程 RSS 之和(KB)
set -u
LABEL="$1"; shift
DD="$1"; shift
LOG="/tmp/r62d-${LABEL}-build.log"
TIMEF="/tmp/r62d-${LABEL}-time.txt"
MEMF="/tmp/r62d-${LABEL}-mem.log"
: > "$MEMF"
( while :; do
    LINE=$(ps -axo rss=,comm= | awk 'tolower($0) ~ /swift|clang|xcodebuild|\/ld$/ {s+=$1} tolower($0) ~ /swift-frontend/ {f++} END{printf "%d %d", s+0, f+0}')
    echo "$(date +%s) ${LINE}" >> "$MEMF"
    sleep 0.5
  done ) &
SAMPLER=$!
SWAP_BEFORE=$(sysctl -n vm.swapusage)
START=$(date +%s)
cd "$(dirname "$0")/../LyricsMTMR" || exit 9
/usr/bin/time -l sh -c "xcodebuild -project LyricsMTMR.xcodeproj -scheme MTMR -configuration Debug CODE_SIGNING_ALLOWED=NO build -derivedDataPath '$DD' $*" >"$LOG" 2>"$TIMEF"
RC=$?
kill "$SAMPLER" 2>/dev/null
END=$(date +%s)
PEAK_ROW=$(sort -k2 -n "$MEMF" | tail -1)
PEAK_TS=${PEAK_ROW%% *}
PEAK_KB=${PEAK_ROW##* }
echo "== label=$LABEL rc=$RC"
echo "wall=$((END-START))s (time -l 见 $TIMEF)"
echo "peak_build_procs_rss=${PEAK_KB}KB = $((PEAK_KB/1024))MB at $(date -r "$PEAK_TS" +%H:%M:%S)"
echo "swap_before=$SWAP_BEFORE"
echo "swap_after=$(sysctl -n vm.swapusage)"
grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" "$LOG" | head -5
exit $RC
