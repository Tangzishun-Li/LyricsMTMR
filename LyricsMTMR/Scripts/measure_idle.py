#!/usr/bin/env python3
"""默认预设空闲基线：启动 App → 等它安静 → 采样 CPU / 内存 / idle wakeups → 与阈值比对。

用法：
    python3 Scripts/measure_idle.py --app /path/to/LyricsMTMR.app
    python3 Scripts/measure_idle.py --build          # 先 Release 构建再测
    python3 Scripts/measure_idle.py --duration 60 --interval 5 --json-out /tmp/idle.json
    python3 Scripts/measure_idle.py --update-baseline  # 用本次实测重写阈值（留余量）

退出码：0 = 在预算内；1 = 超预算或测量失败。

测量口径（写进 docs/性能基线.md）：
  - 用临时 HOME 启动，保证用**默认预设**而不是本机 ~/Library 里的 items.json；
  - 启动后 10s 预热（歌词引擎、感知器、首次网络请求都不计入）；
  - 每 5s 采一次：`top -l 2 -stats pid,cpu,idlew` 取第二次采样（瞬时值），
    `ps -o rss=` 取常驻内存；
  - CPU 取平均，内存取峰值，idle wakeups 取平均；
  - 任一指标超过 thresholds 即非零退出。
"""

from __future__ import annotations

import argparse
import json
import os
import platform
import shutil
import signal
import subprocess
import sys
import tempfile
import time

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)
DEFAULT_THRESHOLDS = os.path.join(SCRIPT_DIR, "idle-baseline.json")
WARMUP_SECONDS = 10


def log(message: str) -> None:
    print(message, flush=True)


def build_app() -> str:
    derived = "/tmp/LyricsMTMR-idle-build"
    cmd = [
        "xcodebuild", "build",
        "-project", os.path.join(PROJECT_DIR, "LyricsMTMR.xcodeproj"),
        "-scheme", "MTMR",
        "-configuration", "Release",
        "-derivedDataPath", derived,
        "CODE_SIGNING_ALLOWED=NO",
    ]
    log("== 构建 Release（用于空闲测量）")
    result = subprocess.run(cmd, cwd=PROJECT_DIR, capture_output=True, text=True)
    if result.returncode != 0:
        sys.stderr.write(result.stdout[-4000:] + result.stderr[-2000:])
        raise SystemExit("xcodebuild build 失败")
    return os.path.join(derived, "Build/Products/Release/LyricsMTMR.app")


def launch(app: str, home: str) -> tuple[subprocess.Popen, int]:
    binary = os.path.join(app, "Contents/MacOS/LyricsMTMR")
    env = dict(os.environ)
    env["HOME"] = home
    env["CFFIXED_USER_HOME"] = home
    log(f"== 启动（隔离 HOME={home}）")
    proc = subprocess.Popen([binary], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    deadline = time.time() + 30
    while time.time() < deadline:
        if proc.poll() is not None:
            raise SystemExit(f"App 启动后立即退出（code={proc.returncode}）")
        out = subprocess.run(["ps", "-p", str(proc.pid), "-o", "comm="], capture_output=True, text=True)
        if out.stdout.strip():
            return proc, proc.pid
        time.sleep(0.5)
    raise SystemExit("App 30s 内没有进入运行状态")


def sample(pid: int, interval: int) -> dict:
    """一次采样：瞬时 CPU%、idle wakeups、常驻内存。"""
    out = subprocess.run(
        ["top", "-l", "2", "-s", "1", "-stats", "pid,cpu,idlew"],
        capture_output=True, text=True,
    ).stdout
    cpu = None
    idlew = None
    for line in reversed(out.splitlines()):
        parts = line.split()
        if len(parts) >= 3 and parts[0] == str(pid):
            try:
                # 第二块采样行形如：<pid> <cpu> <idlew>
                cpu = float(parts[1])
                idlew = int(parts[2])
            except ValueError:
                continue
            break
    rss_kb = subprocess.run(["ps", "-p", str(pid), "-o", "rss="], capture_output=True, text=True).stdout.strip()
    rss_mb = (int(rss_kb) / 1024.0) if rss_kb.isdigit() else None
    time.sleep(max(0, interval - 2))
    return {"cpu": cpu, "idlew": idlew, "rss_mb": rss_mb}


def measure(pid: int, duration: int, interval: int) -> dict:
    log(f"== 预热 {WARMUP_SECONDS}s")
    time.sleep(WARMUP_SECONDS)
    log(f"== 采样 {duration}s / 每 {interval}s")
    cpus: list[float] = []
    idlews: list[int] = []
    rss: list[float] = []
    started = time.time()
    while time.time() - started < duration:
        s = sample(pid, interval)
        if s["cpu"] is not None:
            cpus.append(s["cpu"])
        if s["idlew"] is not None:
            idlews.append(s["idlew"])
        if s["rss_mb"] is not None:
            rss.append(s["rss_mb"])
        log(f"   cpu={s['cpu']}%  rss={s['rss_mb']:.0f}MB  idlew={s['idlew']}")
    if not cpus:
        raise SystemExit("没有采到 CPU 样本（top 输出解析失败）")
    return {
        "samples": len(cpus),
        "cpu_avg": round(sum(cpus) / len(cpus), 2),
        "cpu_max": round(max(cpus), 2),
        "rss_max_mb": round(max(rss), 1) if rss else None,
        "idlew_avg": round(sum(idlews) / len(idlews), 1) if idlews else None,
        "idlew_max": max(idlews) if idlews else None,
    }


def load_thresholds(path: str) -> dict:
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--app", help="LyricsMTMR.app 路径；省略则配合 --build")
    parser.add_argument("--build", action="store_true", help="先 Release 构建")
    parser.add_argument("--duration", type=int, default=60)
    parser.add_argument("--interval", type=int, default=5)
    parser.add_argument("--thresholds", default=DEFAULT_THRESHOLDS)
    parser.add_argument("--json-out", help="把实测结果写到文件（CI artifact）")
    parser.add_argument("--update-baseline", action="store_true", help="用本次实测重写阈值（留余量）")
    args = parser.parse_args()

    app = args.app
    if args.build or not app:
        app = build_app()
    if not os.path.isdir(app):
        raise SystemExit(f"找不到 App：{app}")

    temp_home = tempfile.mkdtemp(prefix="lyricsmtmr-idle-home-")
    proc = None
    try:
        proc, pid = launch(app, temp_home)
        result = measure(pid, args.duration, args.interval)
    finally:
        if proc is not None and proc.poll() is None:
            proc.send_signal(signal.SIGTERM)
            try:
                proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                proc.kill()
        shutil.rmtree(temp_home, ignore_errors=True)

    result.update(
        {
            "measured_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
            "host": f"{platform.platform()}",
            "duration_s": args.duration,
            "interval_s": args.interval,
        }
    )
    log("\n== 实测结果")
    print(json.dumps(result, ensure_ascii=False, indent=2))

    if args.json_out:
        with open(args.json_out, "w", encoding="utf-8") as handle:
            json.dump(result, handle, ensure_ascii=False, indent=2)
        log(f"已写入 {args.json_out}")

    if args.update_baseline:
        thresholds = {
            "updated_at": result["measured_at"],
            "host": result["host"],
            "method": "Scripts/measure_idle.py：临时 HOME 启动默认预设，10s 预热，每 5s 采样 top(cpu,idlew)+ps(rss)，持续 60s。",
            # 留 50% CPU / 25% 内存 / 50% wakeups 余量，避免机器抖动误报
            "cpu_avg_max": round(max(3.0, result["cpu_avg"] * 1.5), 1),
            "rss_max_mb": round(max(200.0, (result["rss_max_mb"] or 300) * 1.25), 0),
            "idlew_avg_max": round(max(20.0, (result["idlew_avg"] or 30) * 1.5), 0),
        }
        with open(args.thresholds, "w", encoding="utf-8") as handle:
            json.dump(thresholds, handle, ensure_ascii=False, indent=2)
            handle.write("\n")
        log(f"已更新阈值 {args.thresholds}")
        return 0

    thresholds = load_thresholds(args.thresholds)
    failures = []
    if result["cpu_avg"] > thresholds["cpu_avg_max"]:
        failures.append(f"CPU 平均 {result['cpu_avg']}% > {thresholds['cpu_avg_max']}%")
    if result["rss_max_mb"] and result["rss_max_mb"] > thresholds["rss_max_mb"]:
        failures.append(f"内存峰值 {result['rss_max_mb']}MB > {thresholds['rss_max_mb']}MB")
    if result["idlew_avg"] is not None and result["idlew_avg"] > thresholds["idlew_avg_max"]:
        failures.append(f"idle wakeups 平均 {result['idlew_avg']} > {thresholds['idlew_avg_max']}")

    log("\n== 预算对比（" + args.thresholds + "）")
    log(f"  CPU 平均 : {result['cpu_avg']}%  (max {thresholds['cpu_avg_max']}%)")
    log(f"  内存峰值 : {result['rss_max_mb']}MB  (max {thresholds['rss_max_mb']}MB)")
    log(f"  idle 唤醒: {result['idlew_avg']}  (max {thresholds['idlew_avg_max']})")
    if failures:
        log("\n❌ 超出空闲预算：")
        for item in failures:
            log("   - " + item)
        return 1
    log("\n✅ 在空闲预算内")
    return 0


if __name__ == "__main__":
    sys.exit(main())
