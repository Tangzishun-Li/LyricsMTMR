# ADR 0009：全机构建串行锁

- 状态：已采纳
- 日期：2026-08-13

## 背景

并行 `xcodebuild` 在这台机器上会互相抢内存，导致构建被系统杀掉（R62 复盘）。

## 决策

所有 xcodebuild 必须经 `scripts/build-with-lock.sh` 排队，锁文件全机互斥，默认注入 `-jobs 4` 与关闭索引存储。

## 取舍

本地构建不能并行，单次构建变慢；换来构建可预期、不再 OOM。

## 后果

CI 不受影响（runner 独立）；本地文档与脚本都指向锁脚本。

## 证据

`docs/构建资源护栏.md`、`scripts/build-with-lock.sh`。
