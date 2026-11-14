# 第三方组件与许可声明（THIRD PARTY NOTICES）

LyricsMTMR 以 **MIT** 许可发布（见仓库根 `LICENSE`），但其中部分文件改编自其他开源项目，
这些文件保留其原始许可。本文件是**唯一权威口径**：`LICENSE`、`NOTICE.md`、`README.md`
和 App 内的声明都以本文件为准。

> 历史问题：`NOTICE.md` 曾写"整体 GPL 2.0"，部分源码头写"licensed under GPL 2.0"，
> 而实际上游是 **MPL-2.0**。已在 2026-11 统一为本文件的映射关系。

## 1. 映射总表

| 组件 | 上游 | 许可 | 在本项目中的分布 |
| --- | --- | --- | --- |
| MTMR | https://github.com/Toxblh/MTMR | MIT | 基础工程与 widget 体系（大多数 `MTMR/**` 文件） |
| LyricsX | https://github.com/MxIris-LyricsX-Project/LyricsX （早期 https://github.com/ddddxxx/LyricsX） | **MPL-2.0** | `LyricsRendering/`、`LyricsIntegration/` 中的改编文件（见 §2） |
| FrameworkToolbox | https://github.com/Mx-Iris/FrameworkToolbox | MIT | `LyricsRendering/` 中 3 个扩展文件（见 §2） |
| Sparkle | https://github.com/sparkle-project/Sparkle | MIT 风格（见原文） | 自动更新框架，以 `Sparkle.framework` 形式随 App 分发 |
| LyricsMTMR 自有代码 | 本仓库 | MIT | 其余全部文件 |

## 2. MPL-2.0 覆盖的文件（改编自 LyricsX）

以下文件包含改编自 LyricsX 的代码，按 **MPL-2.0** 分发。完整许可文本见
[`LICENSES/MPL-2.0.txt`](LICENSES/MPL-2.0.txt)；对应源码即本仓库同路径文件。

- `LyricsMTMR/LyricsRendering/KaraokeLabel.swift`（改编自 LyricsX `KaraokeLabel`）
- `LyricsMTMR/LyricsRendering/LyricsTouchBarItem.swift`（改编自 LyricsX `TouchBarLyricsItem`）
- `LyricsMTMR/LyricsRendering/Then.swift`
- `LyricsMTMR/LyricsRendering/CFStringTokenizerExtensions.swift`（同时改编自 FrameworkToolbox）
- `LyricsMTMR/MTMR/LyricsIntegration/LyricsItemConfig.swift`
- `LyricsMTMR/MTMR/LyricsIntegration/LyricsProviderProtocol.swift`
- `LyricsMTMR/MTMR/LyricsIntegration/LyricsMatchManager.swift`
- `LyricsMTMR/MTMR/LyricsIntegration/LyricsSelectionCache.swift`
- `LyricsMTMR/MTMR/LyricsIntegration/LyricsLRUCache.swift`
- `LyricsMTMR/MTMR/LyricsIntegration/BrowserURLDetector.swift`
- `LyricsMTMR/MTMR/LyricsIntegration/KugouProvider.swift`
- `LyricsMTMR/MTMR/LyricsIntegration/MiguProvider.swift`
- `LyricsMTMR/MTMR/LyricsIntegration/NetEaseProviderAdapter.swift`
- `LyricsMTMR/MTMR/LyricsIntegration/QQMusicProviderAdapter.swift`
- `LyricsMTMR/MTMR/LyricsIntegration/SubtitleProviderPlaceholder.swift`
- `LyricsMTMR/MTMR/Preferences/LyricsMatchView.swift`

MPL-2.0 是**文件级**弱 copyleft：上述文件及其修改仍受 MPL-2.0 约束，其余文件可按 MIT 分发。
本项目以 MIT 分发"更大作品"（Larger Work），并在此完整提供 MPL 覆盖文件的源码路径。

## 3. MIT 覆盖的 FrameworkToolbox 衍生文件

- `LyricsMTMR/LyricsRendering/CoreTextExtensions.swift`
- `LyricsMTMR/LyricsRendering/CoreGraphicsExtensions.swift`
- `LyricsMTMR/LyricsRendering/CFStringTokenizerExtensions.swift`（与 LyricsX 同源的部分按 MPL-2.0 处理，从严）

## 4. Sparkle（随 App 分发的二进制）

`Sparkle.framework` 以二进制形式嵌入 App。其版权声明：

```
Copyright (c) 2006-2013 Andy Matuschak.
Copyright (c) 2009-2013 Elgato Systems GmbH.
Copyright (c) 2011-2014 Kornel Lesiński.
Copyright (c) 2015-2017 Mayur Pawashe.
Copyright (c) 2014 C.W. Betts.
Copyright (c) 2014 Petroules Corporation.
Copyright (c) 2014 Big Nerd Ranch.
```

许可正文见 <https://github.com/sparkle-project/Sparkle/blob/2.x/LICENSE>。

## 5. 不随本仓库分发的运行时依赖

以下组件由用户自行安装，本项目仅调用其本机接口，不打包、不重新分发：
Apple Music / Spotify 等播放器、Ollama 等本地模型服务、各歌词数据源服务。

歌词文本版权归各版权方所有；本项目的歌词抓取仅用于本机显示，不存储、不再分发。

## 6. 分发要求（发版前自检）

1. `LICENSE`、`THIRD_PARTY_NOTICES.md`、`LICENSES/MPL-2.0.txt` 必须打进 App 的
   `Contents/Resources/`（由 Xcode Resources 构建阶段完成）。
2. 修改 MPL 覆盖文件时，保留文件头部的上游来源与许可说明。
3. 新增第三方代码时，在本文件 §1 增行，并在 §2/§3 登记具体文件。

以上由 `MTMRTests/LicenseComplianceContractTests.swift` 在 CI 中自动校验。
