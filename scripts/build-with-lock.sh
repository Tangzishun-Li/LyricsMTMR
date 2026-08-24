#!/bin/bash
# build-with-lock.sh — 全机串行构建锁（r62-b 交付物，契约见 docs/轨道文本_R62 §4.2）
#
# 用法: sh scripts/build-with-lock.sh <xcodebuild 原命令…>
#
# 行为:
#   - 全机互斥: 锁文件默认 /tmp/lyricsmtmr-build.lock（env MTMR_BUILD_LOCK 可覆盖）。
#   - 等锁期间向 stderr 打等待提示: 首次发现被占立即打一行，其后每 30s 一行。
#   - 对 xcodebuild 自动注入 -jobs ${MTMR_BUILD_JOBS:-4} 与
#     COMPILER_INDEX_STORE_ENABLE=NO（原命令已含则不重复加）。
#   - 退出码透传（仅用法错误/环境缺失用非 0 自身退出码）。
#   - bash 3.2 兼容: 不用关联数组; set -u 下所有变量一律 ${} 包裹。
#   - 锁实现说明见 docs/构建资源护栏.md「为什么」段。

set -u
set -o pipefail

PROG_NAME="build-with-lock.sh"
LOCK_WAIT_INTERVAL=30
DEFAULT_LOCK="/tmp/lyricsmtmr-build.lock"

usage() {
  cat <<EOF
用法: sh scripts/${PROG_NAME} <xcodebuild 原命令…>

全机串行构建锁。并发的是开发，串行的是构建（轨道 R62 §7 铁律）。

示例（仓库根目录规范构建命令，见轨道 R62 §2）:
  cd LyricsMTMR && sh ../scripts/${PROG_NAME} xcodebuild \\
      -project LyricsMTMR.xcodeproj -scheme MTMR \\
      -configuration Debug CODE_SIGNING_ALLOWED=NO build

环境变量:
  MTMR_BUILD_LOCK    锁文件路径（默认 /tmp/lyricsmtmr-build.lock）
  MTMR_BUILD_JOBS    注入给 xcodebuild 的并行度（默认 4，须为正整数）

行为:
  - 全机互斥: 同一时刻只放行一个经本脚本的构建。
  - 等锁提示: 首次发现被占立即打一行 stderr，其后每 ${LOCK_WAIT_INTERVAL}s 一行。
  - xcodebuild 自动注入 -jobs 与 COMPILER_INDEX_STORE_ENABLE=NO（已含则不重复加）。
  - 退出码透传。

无参数调用打印本用法并以非 0 退出。
EOF
}

die_usage() {
  usage >&2
  exit 64
}

# ---------- 参数与前置校验 ----------

[ $# -gt 0 ] || die_usage

LOCK_FILE="${MTMR_BUILD_LOCK:-${DEFAULT_LOCK}}"
JOBS="${MTMR_BUILD_JOBS:-4}"

case "${JOBS}" in
  ''|*[!0-9]*)
    echo "[${PROG_NAME}] MTMR_BUILD_JOBS 必须是正整数，当前为: ${JOBS}" >&2
    exit 64
    ;;
esac

PERL_BIN=""
if command -v perl >/dev/null 2>&1; then
  PERL_BIN="$(command -v perl)"
fi
if [ -z "${PERL_BIN}" ]; then
  echo "[${PROG_NAME}] 找不到 perl，无法实现构建锁，拒绝无护栏构建。" >&2
  exit 69
fi

# ---------- 注入决策（先算好，获锁后应用；仅对 xcodebuild，已含则不重复加） ----------

CMD_BASE="$(basename -- "$1")"
NEED_JOBS=0
NEED_INDEX_ENV=0
if [ "${CMD_BASE}" = "xcodebuild" ]; then
  NEED_JOBS=1
  NEED_INDEX_ENV=1
  for ARG in "$@"; do
    case "${ARG}" in
      -jobs|-jobs=*) NEED_JOBS=0 ;;
      *COMPILER_INDEX_STORE_ENABLE=*) NEED_INDEX_ENV=0 ;;
    esac
  done
fi

# ---------- 锁实现 ----------
# macOS 不自带 flock(1)。flock(2) 锁属于「文件描述 + 进程」，持锁进程退出即释放，
# 所以必须有一个活到构建结束的 holder 进程持有锁: 后台 perl 打开锁文件并对句柄加
# LOCK_EX|LOCK_NB，成功后写 ready 标记，然后每 0.5s 探测父进程 pid——父进程存活期间
# 持续持锁，父进程死亡（含 SIGKILL，无需 trap）即自行退出放锁。竞争失败者立即退出，
# 由父 shell 以 0.2s 粒度探测标记/死亡并隔时重试。无陈锁残留问题。

HOLDER_PID=""

release_holder() {
  if [ -n "${HOLDER_PID}" ] && kill -0 "${HOLDER_PID}" 2>/dev/null; then
    kill "${HOLDER_PID}" 2>/dev/null
    wait "${HOLDER_PID}" 2>/dev/null
  fi
}
trap release_holder EXIT
trap 'release_holder; exit 130' INT
trap 'release_holder; exit 143' TERM

run_holder() {
  # $1 = ready 标记路径（成功获锁时 holder 写入自己的 pid）
  "${PERL_BIN}" -e '
use strict; use warnings;
use Fcntl qw(:flock LOCK_EX LOCK_NB);
my ($lockfile, $marker, $watch_pid) = @ARGV;
open my $fh, ">>", $lockfile or exit 66;
exit 65 unless flock($fh, LOCK_EX | LOCK_NB);
open my $mk, ">", $marker or exit 66;
print $mk "$$\n";
close $mk;
while (kill 0, $watch_pid) {
  select undef, undef, undef, 0.5;
}
exit 0;
' "${LOCK_FILE}" "$1" "$$" >/dev/null 2>&1 &
}

ATTEMPT_NO=0
LAST_HINT=""

hint_locked_out() {
  # 首次发现被占立即打一行；此后距上一行满 30s 再打
  NOW="${SECONDS}"
  if [ -z "${LAST_HINT}" ] || [ $((NOW - LAST_HINT)) -ge ${LOCK_WAIT_INTERVAL} ]; then
    echo "[${PROG_NAME}] 第 ${NOW}s: 构建锁被占用，等待中 (${LOCK_FILE})。并发的是开发，串行的是构建。" >&2
    LAST_HINT="${NOW}"
  fi
}

acquire_lock() {
  while :; do
    ATTEMPT_NO=$((ATTEMPT_NO + 1))
    # 标记路径每次尝试唯一，绝不复用旧文件，故无需清理
    MARKER_PATH="${TMPDIR:-/tmp}/${PROG_NAME}-ready-$$-${ATTEMPT_NO}"
    run_holder "${MARKER_PATH}"
    HOLDER_PID=$!
    POLLS=0
    DENIED=0
    while [ ${POLLS} -lt 600 ]; do
      if [ -s "${MARKER_PATH}" ]; then
        if [ ${NEED_JOBS} -eq 1 ]; then
          echo "[${PROG_NAME}] pid $$ 获得锁 ${LOCK_FILE}，开始构建 (-jobs ${JOBS})。" >&2
        else
          echo "[${PROG_NAME}] pid $$ 获得锁 ${LOCK_FILE}，开始构建。" >&2
        fi
        return 0
      fi
      if ! kill -0 "${HOLDER_PID}" 2>/dev/null; then
        # holder 已退出且无标记: 66=锁文件不可用; 65=锁被占
        wait "${HOLDER_PID}" 2>/dev/null
        H_RC=$?
        HOLDER_PID=""
        if [ ${H_RC} -eq 66 ]; then
          echo "[${PROG_NAME}] 无法创建/打开锁文件: ${LOCK_FILE}" >&2
          exit 66
        fi
        DENIED=1
        break
      fi
      sleep 0.2
      POLLS=$((POLLS + 1))
    done
    if [ ${DENIED} -eq 1 ]; then
      hint_locked_out
      continue
    fi
    # 600 次(≈2min)既无标记也未退出属异常尝试，收掉重来
    kill "${HOLDER_PID}" 2>/dev/null
    wait "${HOLDER_PID}" 2>/dev/null
    HOLDER_PID=""
  done
}

acquire_lock

# ---------- 注入应用 ----------

if [ ${NEED_INDEX_ENV} -eq 1 ]; then
  COMPILER_INDEX_STORE_ENABLE=NO
  export COMPILER_INDEX_STORE_ENABLE
fi
if [ ${NEED_JOBS} -eq 1 ]; then
  # 注入到命令名之后（xcodebuild 的选项与动作可任意混排，首参须仍是命令本体）
  CMD="$1"
  shift
  set -- "${CMD}" -jobs "${JOBS}" "$@"
fi

# ---------- 执行与退出码透传 ----------

RC=0
"$@" || RC=$?
exit ${RC}
