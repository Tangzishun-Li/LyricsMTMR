# ADR 0005：最低系统版本从产物读取，不写死

- 状态：已采纳
- 日期：2026-11-15

## 背景

appcast 曾硬编码 `minimumSystemVersion=13.0`，而安装包实际要求 15.0 → macOS 13/14 用户会被推送一个装完打不开的更新。

## 决策

publish 从包内 `LSMinimumSystemVersion` 取值写 feed；`rebuild_appcast.py --inspect-artifacts` 读包内 Info.plist 纠正历史条目；`verify_release.py` 解包逐项比对。

## 取舍

多一次解包/读 plist 的成本，换来声明与实物永远一致。

## 后果

线上 v0.3.4 feed 已从 13.0 纠正为 15.0。

## 证据

`publish.yml` 的 MIN_SYSTEM 段、`verify_release.py` 的 check_app_plist、README 系统要求。
