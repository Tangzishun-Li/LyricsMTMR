# LyricsMTMR

> 在 MacBook Pro Touch Bar 上实时显示歌词 —— 将 [LyricsX](https://github.com/ddddxxx/LyricsX) 的歌词能力与 [MTMR](https://github.com/Toxblh/MTMR) 的 Touch Bar 组件体系合二为一的实验项目。

[![Release v0.1](https://img.shields.io/badge/release-v0.1-brightgreen)](https://github.com/Tangzishun-Li/LyricsMTMR/releases/tag/v0.1) [![Pre-release v0.2](https://img.shields.io/badge/pre--release-v0.2-blue)](https://github.com/Tangzishun-Li/LyricsMTMR/releases/tag/v0.2) [![Latest v0.3](https://img.shields.io/badge/latest-v0.3-orange)](https://github.com/Tangzishun-Li/LyricsMTMR/releases/tag/v0.3) [![CI](https://github.com/Tangzishun-Li/LyricsMTMR/actions/workflows/build-test.yml/badge.svg)](https://github.com/Tangzishun-Li/LyricsMTMR/actions/workflows/build-test.yml)

[**📥 下载最新版本 (v0.3)**](https://github.com/Tangzishun-Li/LyricsMTMR/releases/latest) · [**v0.2 预发布**](https://github.com/Tangzishun-Li/LyricsMTMR/releases/tag/v0.2) · [**v0.1 正式**](https://github.com/Tangzishun-Li/LyricsMTMR/releases/tag/v0.1)

---

## 截图速览

<!-- 截图待补：docs/screenshots/ 目录下应放 2-3 张关键截图 -->
<!-- 用户决策：截屏授权方式（自截 / screencapture 远程 / 占位图）尚待拍板 -->

| 主设置窗口 | Touch Bar 镜像 | Ribbon 编辑器 |
|---|---|---|
| _（截图待补）_ | _（截图待补）_ | _（截图待补）_ |

## ✨ 功能特性

### 🎵 歌词系统
- **多平台歌词源**：QQ 音乐 / 网易云 / 酷狗 / 咪咕 / 本地 `.lrc` / `.lrcx`，自动搜索与匹配
- **逐字卡拉 OK 高亮**：逐字时间线与播放进度精确对齐
- **歌词过滤**：自动过滤制作人员（词/曲/编曲/混音等 credit 行）
- **翻译显示**：外文歌曲可同时显示译文
- **多播放器支持**：Music、Spotify、Vox、Swinsian、Audirvana 等
- _（v0.2 之后）浏览器视频字幕转歌词：YouTube / Bilibili 视频字幕接入（开发版功能，可用性未完全保证）_

### 🧩 Widget 组件库（114 种）
- **系统监控**：CPU / 内存 / 磁盘 / 网络 / 电池 / 风扇
- **音乐与媒体**：专辑封面、播放控制、音量、进度条
- **效率工具**：天气、时钟、日历、节假日倒计时、备忘录、剪贴板
- **数据面板**：股票（A 股 + 分时图）、天气（中国天气网国内数据源）、快递、BeeCount 记账同步
- **开发相关**：Git 状态、Docker、AppleScript、Shell 脚本、API 测试器、二维码、Latex 符号
- **AI 助手**：内置对话组件，API Key / 服务地址 / 模型名完全自由填写（不锁定厂商）
- _（v0.2 之后）健康 / 智能家居（HomeKit）/ 快递 schema 化重构：相关 widget 已存在并接入设置面板，使用体验随实际配置而定_

### 🎨 布局与主题
- **可视化 Ribbon 编辑器**：拖拽排列 Touch Bar 组件、实时预览、防误删确认、未保存提醒
- **Touch Bar 模拟器 / 镜像窗口**：在设置窗口内实时预览布局效果
- **主题系统**：15 套预设主题（theme1–15）+ 完全自定义，Dock 图标主题联动
- **应用专属主题（Per-app bar switching）**：为指定 App 绑定独立 Touch Bar 布局，切换应用自动换主题（[使用指南](#应用专属主题per-app-bar-switching)）
- **预设导入导出**：JSON 格式，兼容手写注释的 `items.json`

### ⚙️ 设置与集成
- **22 个分类设置 Tab**：通用 / 歌词 / 槽位 / 编辑器 / 键位 / 服务 / 关于 / 股票 / 番茄钟 / 天气 / RSS / 快递 / 日历 / 智能家居 / AI 助手 / 记账 / Dock / 通知 / 系统监控 / 健康 / 生活 / 快捷工具，带全局搜索与目录跳转
- **快捷键集成**：全局快捷键管理与 Music 播放控制
- **AppleScript / Shell / HTTP API**：通过脚本 widget 调用任意外部能力
- **⚠️ macOS 15.4+ 风险说明**：Touch Bar API 在 macOS 15.4+ 有兼容性变化，详见 [使用指南](#macos-154-风险说明)

### 📊 数据来源
- 歌词：QQ 音乐 / 网易云 / 酷狗 / 咪咕 / 本地文件 / 浏览器视频字幕
- 天气：中国天气网（国内数据源，免 Key）
- 节假日：复用法定节假日表
- 股票：A 股分时数据（按主题统计）
- 快递：第三方快递查询接口（具体可用性视 API 提供方）
- 健康 / 智能家居：macOS HealthKit / HomeKit（需用户授权）

## 🚀 快速开始

### 方式一：下载 Release（推荐）
1. 访问 [Releases 页面](https://github.com/Tangzishun-Li/LyricsMTMR/releases/latest)
2. 下载对应 macOS 版本的 `.dmg`
3. 拖入「应用程序」文件夹
4. 首次启动需在「系统设置 → 隐私与安全性 → 辅助功能」中授权 LyricsMTMR

### 方式二：源码构建
```bash
git clone https://github.com/Tangzishun-Li/LyricsMTMR.git
cd LyricsMTMR
open LyricsMTMR.xcodeproj
# 用 Xcode 构建并运行
```

> 详细构建说明见 [构建指南](docs/build-guide.md)（如不存在，请通过 Issue 反馈）

## 📖 使用指南

### 应用专属主题（Per-app bar switching）
1. 打开「设置 → 通用」
2. 在「应用专属主题」中点 + 添加 App
3. 选择目标 App，配置独立布局
4. 切换该 App 时 Touch Bar 自动切换主题

### Ribbon 编辑器
1. 打开「设置 → 编辑器」
2. 拖拽左侧组件到 Touch Bar 预览区
3. 调整顺序与属性，保存即可生效

### 快捷键管理
- 「设置 → 键位」中查看和修改全局快捷键
- 支持音乐控制、显示模式切换、组件触发等

### 启动问题排查
- 如果 Touch Bar 不显示：检查「系统设置 → 辅助功能」授权
- 如果歌词不显示：检查对应播放器是否在支持列表中
- 如果组件无响应：尝试「设置 → 通用 → 重置 Touch Bar」

### macOS 15.4+ 风险说明
macOS 15.4+ 对 Touch Bar 系统 API 做了调整，LyricsMTMR 在该系统版本上可能存在：
- 组件渲染延迟
- 主题切换偶发失效
- 部分 widget 数据刷新异常

建议在 macOS 15.4+ 上使用最新 v0.3 版本以获得最佳兼容性。

## 🧩 项目结构

```
LyricsMTMR/
├── LyricsMTMR/         # Xcode 项目
│   ├── MTMR/            # 主程序源码
│   │   ├── Items/       # Touch Bar 组件（widget）
│   │   ├── Widgets/     # widget 分类（Life/Productivity/...）
│   │   ├── Preferences/ # 设置面板
│   │   └── Lyrics/      # 歌词引擎（来自 LyricsX）
│   └── Resources/       # 资源文件
├── docs/                # 文档
├── examples/            # 预设与示例
├── scripts/             # 构建与开发脚本
└── README.md            # 本文件
```

## 📝 更新日志

### v0.3（2026-08-26，当前）
- 营销版本号降档：v0.63 → 0.3，与新 Release tag 对齐
- 工程 build 号：488 → 489（严格 +1）
- 整体版本语义：v0.1 正式 / v0.2 预发布 / v0.3 当前
- 健康 / 智能家居 / 快递 widget 接入设置面板（功能可用性视实际配置）
- 浏览器视频字幕转歌词接入（开发版功能）
- 详细历史：见 [docs/CHANGELOG.md](docs/CHANGELOG.md#v063当前开发版本)

### v0.2（2026-08-09，预发布）
- 首个对外预发布版本
- 完整支持 114 种 Touch Bar widget
- 多平台歌词源整合（QQ 音乐 / 网易云 / 酷狗 / 咪咕）
- 逐字卡拉 OK 高亮
- 应用专属主题（Per-app bar switching）
- 详细历史：见 [docs/CHANGELOG.md](docs/CHANGELOG.md#v08预发布)

### v0.1（2026-07-29，首个正式发行版）
- 项目首个正式发行版
- 基于上游 MTMR v0.27.0 fork，整合 LyricsX 歌词引擎
- 完整 ribbon 编辑器 + 主题系统
- 详细历史：见 [docs/CHANGELOG.md](docs/CHANGELOG.md#v100首个正式发行版)

### 完整历史
- [docs/CHANGELOG.md](docs/CHANGELOG.md) —— 详细历史（每个迭代轮次的技术细节）
- [GitHub Releases](https://github.com/Tangzishun-Li/LyricsMTMR/releases) —— 所有正式发布

## 📚 文档索引

- [docs/CHANGELOG.md](docs/CHANGELOG.md) —— 完整更新日志
- [docs/轮次速查.md](docs/轮次速查.md) —— 各轮次快速索引
- [docs/设置项对照表_R60.md](docs/设置项对照表_R60.md) —— 设置项权威对照
- [docs/轨道文本_R*.md](docs/) —— 各轮次轨道文本

## 🙏 致谢

本项目基于以下开源项目：

- [LyricsX](https://github.com/ddddxxx/LyricsX) — 多平台歌词引擎
- [MTMR](https://github.com/Toxblh/MTMR) — Touch Bar 组件体系
- [SnapKit](https://github.com/SnapKit/SnapKit) — Auto Layout DSL
- [MASShortcut](https://github.com/shpakovski/MASShortcut) — 全局快捷键管理
- [Sparkle](https://github.com/sparkle-project/sparkle) — 应用更新框架
- [Then](https://github.com/devxoul/Then) — Swift 语法糖

## ⚠️ 重要免责声明

> 这是一个**个人实验项目**，仅用于学习与技术探索，不提供任何形式的保证。

### 版权说明
所有歌词数据的版权归各自所有者所有。本项目仅用于展示技术实现，不用于商业用途。

### 侵权请告知
如果你认为本项目侵犯了你的合法权益，请通过 GitHub Issues 与我联系，我会立即：
- 删除相关内容
- 或关闭整个仓库

## ⚠️ Important Disclaimer

> This is a **personal experimental project** solely for learning and technical exploration. No warranties of any kind are provided.

### Copyright Notice
All lyrics content is the property and copyright of their respective owners. This project is for demonstrating technical implementation only and is not intended for commercial use.

### Takedown Request
If you believe this project infringes upon your legal rights, please contact me via GitHub Issues and I will promptly:
- Remove the relevant content
- Or take down this entire repository
