# ADR 0001：许可口径收敛为 MIT + MPL-2.0

- 状态：已采纳
- 日期：2026-11-14

## 背景

仓库曾同时存在三种说法：根 `LICENSE`=MIT、`NOTICE.md`="整体 GPL 2.0"、19 个源码头="licensed under GPL 2.0"。核对上游后发现 LyricsX 是 **MPL-2.0**、FrameworkToolbox 是 MIT，GPL 说法没有依据。

## 决策

整体以 MIT 分发（Larger Work），改编自 LyricsX 的文件保留 MPL-2.0；新增 `THIRD_PARTY_NOTICES.md` 作为唯一口径，文件头逐条改正；三份法律文件打进 App Resources。

## 取舍

MPL-2.0 是文件级弱 copyleft：比整体 GPL 更容易被下游接受，但要求保留 MPL 文件的源码可得与告知义务。

## 后果

下游可以按 MIT 使用本项目，但改动 `LyricsRendering/` 等 MPL 文件时必须继续开源这些文件。

## 证据

`THIRD_PARTY_NOTICES.md`、`LICENSES/MPL-2.0.txt`、`LicenseComplianceContractTests`（8 用例）。
