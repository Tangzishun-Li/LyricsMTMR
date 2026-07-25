# 归档 (Archive)

本目录存放从项目中移除的死代码、重复文件和废弃资源。
每项均标注了原始位置和移除原因，供日后参考或恢复。

---

## duplicate-LyricsRendering/

| 项目 | 说明 |
|------|------|
| **原始位置** | `MTMR/LyricsRendering/` |
| **内容** | CFStringTokenizerExtensions.swift, CoreGraphicsExtensions.swift, CoreTextExtensions.swift, KaraokeLabel.swift, LyricsTouchBarItem.swift, Then.swift |
| **移除原因** | 与顶层 `LyricsRendering/` 完全重复。Xcode 项目 (project.pbxproj) 只引用顶层 `LyricsRendering/`，此副本从未参与编译。 |

---

## dead-functions/

从源文件中提取并移除的未使用函数/属性。

| 文件 | 原始位置 | 移除内容 | 原因 |
|------|----------|----------|------|
| `CPU_dead_code.swift` | `MTMR/CPU.swift` | `applicationUsage()`, `threadIdentifierInfos()`, `flag()`, `threadActPointers()`, `threadBasicInfos()`, 注释掉的 `physicalCores`/`logicalCores` | 从未被调用；`threadIdentifierInfos` 带有 "in developing" TODO |
| `SupportHelpers_dead_code.swift` | `MTMR/SupportHelpers.swift` | `trim()`, `rotateByDegreess(degrees:)` | 全项目无任何调用 |
| `GeneralExtensions_dead_code.swift` | `MTMR/GeneralExtensions.swift` | `compactMap` Swift 4.1 兼容 shim | 项目已使用 Swift 5+，完全多余 |
| `LyricsEngine_dead_code.swift` | `MTMR/LyricsIntegration/LyricsEngine.swift` | `currentLineText`, `hasTimetag` | 计算属性从未被任何代码读取 |
| `LyricsFilter_dead_code.swift` | `MTMR/LyricsIntegration/LyricsFilter.swift` | `FilterMode.englishLabel`, `LyricsFilter.isRegexKey(_:)` | 从未被调用 |

---

## abandoned-scripts/

| 文件 | 原始位置 | 移除原因 |
|------|----------|----------|
| `add_web.py` | `LyricsMTMR/add_web.py` | 一次性脚本，用于向 Xcode 项目添加 `WebSettingsController.swift`，但该文件已不存在 |

---

## legacy-applescripts/

| 文件 | 原始位置 | 移除原因 |
|------|----------|----------|
| `iTunes.next.scpt` | `MTMR/AppleScripts/iTunes.next.scpt` | iTunes 在现代 macOS 上已被 Music.app 取代，脚本无用 |
| `iTunes.nowPlaying.scpt` | `MTMR/AppleScripts/iTunes.nowPlaying.scpt` | 同上 |

> 已从 Xcode 项目 (project.pbxproj) 中移除所有引用。
