# LyricsMTMR

> 在 MacBook Pro Touch Bar 上实时显示歌词 —— 将 [LyricsX](https://github.com/ddddxxx/LyricsX) 的歌词引擎与 [MTMR](https://github.com/Toxblh/MTMR) 的 Touch Bar 组件体系合二为一的 macOS 工具。

[![CI](https://github.com/Tangzishun-Li/LyricsMTMR/actions/workflows/build-test.yml/badge.svg)](https://github.com/Tangzishun-Li/LyricsMTMR/actions/workflows/build-test.yml)
[![Release v1.0.0](https://img.shields.io/badge/Release-v1.0.0-success)](https://github.com/Tangzishun-Li/LyricsMTMR/releases/tag/v1.0.0)
[![Pre-release v0.8](https://img.shields.io/badge/Pre--release-v0.8-orange)](https://github.com/Tangzishun-Li/LyricsMTMR/releases/tag/v0.8)

<p align="center">
  <img alt="LyricsMTMR 主设置窗口" src="docs/screenshots/main-window.png" width="720">
  <br><em>主设置窗口（22 个 Tab / 全局搜索 / 应用专属主题）</em>
</p>

---

## 这是什么

LyricsMTMR 是一款 macOS Touch Bar 增强工具：把 LyricsX 的多平台歌词引擎接入 MTMR 的组件体系，让你在 Touch Bar 上实时看到正在播放的歌词（逐字卡拉 OK 高亮），同时保留 MTMR 全部 widget 生态与可视化布局编辑器。

**核心定位**：一个「能显示歌词的 MTMR」——歌词只是开始，Touch Bar 上能看到什么完全由你定。

## ✨ 功能特性

### 🎵 歌词

- **多平台歌词源**：QQ 音乐 / 网易云 / 酷狗 / 咪咕 / 本地 `.lrc` / `.lrcx`，自动搜索匹配
- **逐字卡拉 OK 高亮**：逐字时间线与播放进度精确对齐
- **桌面歌词窗口**（R51+）：悬浮 NSPanel，3 行竖排 + 卡拉 OK 进度色 + 长行 marquee 滚动 + 位置记忆
- **浏览器视频字幕转歌词**：YouTube / Bilibili 字幕接入
- **歌词过滤**：自动剔除词/曲/编曲等制作人员 credit 行
- **翻译显示**：外文歌曲可同时显示译文
- **多播放器支持**：Music、Spotify、Vox、Swinsian、Audirvana 等

### 🧩 114 种 Widget

- **系统监控**：CPU / 内存 / 磁盘 / 网络 / 电池 / 风扇
- **音乐与媒体**：专辑封面 / 播放控制 / 音量 / 进度条
- **效率**：天气 / 时钟 / 日历 / 节假日倒计时 / 备忘录 / 剪贴板
- **数据面板**：股票（A 股 + 分时图）/ 快递 / OpenCode Go 用量 / BeeCount 记账同步
- **开发**：Git 状态 / Docker / AppleScript / Shell / API 测试器 / 二维码 / Latex / 论文进度
- **AI 助手**：内置对话组件，API Key / 服务地址 / 模型名完全自由填写

### 🎨 布局与主题

- **可视化 Ribbon 编辑器**：拖拽排列组件 / 实时预览 / 防误删确认 / 未保存提醒
- **Touch Bar 镜像窗口**：在设置窗内实时预览布局
- **15 套预设主题（theme1–15）+ 完全自定义**，Dock 图标主题联动
- **应用专属主题（Per-app bar switching）**：为指定 App 绑定独立布局，切应用自动换主题（[issue #40](https://github.com/Tangzishun-Li/LyricsMTMR/issues/40)）
- **预设导入导出**：JSON 格式，兼容手写注释的 `items.json`

### ⚙️ 设置

- **22 个分类 Tab，分 3 组折叠**（常用 / 数据 / 更多），带全局搜索与目录跳转
- **真实持久化**：所有设置项都接上了真实读写
- **快捷键绑定 / RSS 订阅 / 配置导入导出 / 一键重置**
- **健康 / 智能家居 / 快递 三域** schema 化渲染（R58~R61）

### 🔌 集成与扩展

- **AppleScript / Shell 脚本**：任意脚本输出显示在 Touch Bar（可视化代码生成器辅助）
- **第三方数据接入**：本地 JSON 文件接口（`expenses.json` 等）
- **HomeKit / Docker / MediaRemote** 系统能力集成

### 🆕 v0.8 之后新增

- **桌面歌词窗口**（R51~R53）：NSPanel 悬浮 / 卡拉 OK 同步 / 长行 marquee / 位置记忆 + 重置按钮
- **桌面歌词独立配色**（R55）：自定义文字色 / 进度色
- **应用专属主题**（v0.27 首发，v0.8+ 持续打磨）：激活模式三态
- **健康 / 智能家居 / 快递 schema 化**（R58~R61）
- **桌面歌词窗口位置守护**（R59）：防越界 + 重置按钮
- **设置架构重排**（R57）：3 组折叠 + 全局搜索
- **桌面歌词记账闭环**（R58）：savings.json 月预算/目标/currency 渲染 + BeeCount 今日收支摘要
- **启动三档化**（R62）：MAIN_IMMEDIATE / MAIN_NEXT_TICK / BACKGROUND，Touch Bar 与状态栏首帧更快就绪
- **隐私清单补建**（R50）：macOS 14+ 合规面 + 敏感 API 收集声明
- **密钥 Keychain 治理**（R43）：默认 UserDefaults，Keychain 切换机制完整可用
- **EditorTabView 死代码簇删除**（R63）：-1683 行，编译更快

> 完整版（v0.27 起的 60+ 轮迭代历史 + 工程流水）见 [docs/CHANGELOG.md](docs/CHANGELOG.md) 与 [GitHub Releases](https://github.com/Tangzishun-Li/LyricsMTMR/releases)。

## ⚠️ macOS 15.4+ 音乐信息获取风险

> 自 macOS 15.4 起，系统 `mediaremoted` 开始校验 entitlements，直接调用私有框架 MediaRemote 会报 `Operation not permitted`（[LyricFever#94](https://github.com/lyricfever/lyricfever) 等多方确认）。本项目通过 `mediaremote-adapter` 子进程桥接方案（系统 `perl` 加载应用内 `MediaRemoteMRBridge.dylib`）绕过该限制。
>
> **已知风险**：MediaRemote 是未公开框架，`/usr/bin/perl` 的特权行为随系统变化——Apple 未来系统更新可能再次封堵（macOS 26 曾出现一次并已修复）。曲目信息依赖播放 App 主动上报 Now Playing，部分 App 不提供/不更新时组件拿不到数据。
>
> 详情见 [issue #1](https://github.com/Tangzishun-Li/LyricsMTMR/issues/1)。

## 🚀 快速开始

### 方式一：下载发行版（推荐）

从 [Releases](https://github.com/Tangzishun-Li/LyricsMTMR/releases) 下载最新版本 `.app`（通用二进制，Intel / Apple Silicon 均可），拖入「应用程序」即可。

- **正式版**：[v1.0.0](https://github.com/Tangzishun-Li/LyricsMTMR/releases/tag/v1.0.0)（首个正式发行版）
- **预发布**：[v0.8](https://github.com/Tangzishun-Li/LyricsMTMR/releases/tag/v0.8)（更新更全，含桌面歌词 / 应用专属主题等 114 widget 大集合）

> 首次启动会在「系统设置 → 隐私与安全性 → 辅助功能」请求权限（Touch Bar 控制需要）。

### 方式二：从源码构建

需要 macOS 13+ 与 Xcode 15+（含命令行工具）。

```bash
git clone https://github.com/Tangzishun-Li/LyricsMTMR.git
cd LyricsMTMR

make build     # Debug 构建
make test      # 运行单元测试
make archive   # 生成通用（arm64 + x86_64）未签名归档
```

构建产物位于 `LyricsMTMR/Release/`，构建细节见 [LyricsMTMR/docs/file-structure.zh.md](LyricsMTMR/docs/file-structure.zh.md)。

## 📖 使用指南

首次启动后，在菜单栏点击 LyricsMTMR 图标进入设置窗口：

1. **选择主题**：设置 → 编辑器 → 顶部「配置」下拉选 15 套预设，或导入 `examples/presets/`
2. **加歌词组件**：设置 → 编辑器，拖入 `LyricsTouchBarItem` / `KaraokeLabel` 组件，播放音乐即可看到
3. **开桌面歌词**：设置 → 歌词 → 桌面歌词区，开启后弹出悬浮窗
4. **接数据源**：股票 / 天气 / 快递等外部数据组件的配置见 [外部数据使用指南](LyricsMTMR/docs/user-guide/external-data.zh.md)
5. **想自己写 widget**：AppleScript / Shell 自定义见 [脚本与自动化指南](LyricsMTMR/docs/user-guide/scripting.zh.md)

### 应用专属主题

为常用 App（Xcode、浏览器、播放器等）绑定独立的 Touch Bar 布局，切换应用时 Touch Bar 自动换主题，切回其他应用时自动恢复。

**入口**：
- 设置 → 通用 →「应用专属主题」区块
- 状态栏菜单 →「应用专属主题」卡片（对当前前台 App 操作最方便）

**创建规则**：点击「为当前应用创建主题」——以当前布局为模板生成该 App 的主题文件（存于 `Application Support/LyricsMTMR/app-themes/<BundleID>.json`）。

**激活模式三态**：

| 模式 | 含义 |
|------|------|
| 始终使用（Always） | 每次该 App 成为前台应用时都强制应用其专属主题 |
| 激活时使用（On Activation） | 仅在该 App 被激活（切换进入）时应用；激活后若用户手动切换主题，尊重手动选择 |
| 已停用（Disabled） | 规则保留但不生效 |

> 若主题文件被手动删除，对应规则会自动移除并回退到切换前的布局。

### 文档索引

| 文档 | 说明 |
|------|------|
| [更新日志](docs/CHANGELOG.md) | v0.27 起的 60+ 轮迭代 + 工程流水 |
| [外部数据使用指南](LyricsMTMR/docs/user-guide/external-data.zh.md) | 股票 / 天气 / 快递 / AI 用量等组件配置 |
| [脚本与自动化指南](LyricsMTMR/docs/user-guide/scripting.zh.md) | AppleScript / Shell 自定义组件 |
| [ITEMS_REFERENCE.md](LyricsMTMR/docs/ITEMS_REFERENCE.md) | 全部 114 种 widget type 与 JSON 配置参考 |
| [第三方接入](LyricsMTMR/docs/第三方接入.md) | 本地 JSON 数据文件接口 |
| [开发者 API 文档](LyricsMTMR/docs/README.md) | 外部 / 脚本 / 内部 API 中英双语参考 |
| [文件存放说明](LyricsMTMR/docs/file-structure.zh.md) | 目录职责与新增文件归属 |

## 🧩 项目结构

| 目录 | 说明 |
|------|------|
| `LyricsMTMR/` | Xcode 工程（`LyricsMTMR.xcodeproj`），源码按 App / Core / Support / Widgets / Preferences / LyricsIntegration 分层 |
| `LyricsMTMR/Scripts/` | 构建与开发脚本：`build.sh`、`test.sh`、`archive.sh`、主题/工程生成工具 |
| `LyricsMTMR/docs/` | 用户 / 开发者文档、API 参考、文件结构说明 |
| `docs/` | 仓库级文档（CHANGELOG 等） |
| `examples/presets/` | 主题预设示例（theme1–15、items.json） |
| `tools/` | 调试工具（`mr-dump`、虚拟键盘原型） |
| `.github/workflows/` | CI：push / PR 自动构建与测试，tag 触发通用架构归档 |

## 📝 更新日志

> 最近 3 个 release 的「用户能感知」摘要。完整版见 [docs/CHANGELOG.md](docs/CHANGELOG.md) 与 [GitHub Releases](https://github.com/Tangzishun-Li/LyricsMTMR/releases)。

### v0.8（预发布 · 2026-08-09）

**新增**
- 记账 BeeCount 同步（PAT 鉴权 + 连通性测试）
- AI 助手改为自带模型（API Key / 服务地址 / 模型名自由填写）
- 天气改用国内数据源（中国天气网，免 Key）+ 多城市切换
- 浏览器视频字幕接入（YouTube / Bilibili）
- OpenCode Go 用量 widget + theme4 预设
- 歌词搜索候选数量可配置，酷狗 accesskey 容错
- 长设置页目录跳转

**改进**
- 设置界面全部接上真实持久化（消除「改了白改」）
- Dock 设置真实生效（主题作用域 + 数量不限 + 图标大小）
- 股票 Tab 重构（按主题统计与增删改）
- 编辑器操作逻辑重构（拖拽 / 防误删 / 未保存提醒）
- 构建警告清零（68 → 0）

**修复**
- 卡拉 OK 跳字重影与逐字歌词显示异常
- `AppScrubberTouchBarItem` observer 泄漏
- widget timer/observer 泄漏，空闲 CPU 降低

**工程**
- 源码目录分层重构
- CI 修复 + entitlements 统一 + `make build/test/archive`
- 新增用户/开发者两册中英双语 API 文档

### v1.0.0（首个正式发行版 · 2026-07-29）

- 歌词渲染引擎优化（KaraokeLabel / LyricsTouchBarItem）
- 设置窗口全面重构：14+ Tab / 全局搜索 / 导入导出 / 一键重置
- 56+ Touch Bar item 全面升级，10 个新测试主题（theme6–15）
- 8 个新 widget：ApiTester / BilibiliFeed / CitationGen / FinderTags / LatexSymbols / PaperProgress / PaperTags / QRCode
- 快捷键绑定 / RSS 订阅 / Touch Bar 模拟器 / AppleScript 代码生成器 / 草稿管理器 / 异常捕获器

完整 Release Notes：[v1.0.0](https://github.com/Tangzishun-Li/LyricsMTMR/releases/tag/v1.0.0)

### 开发版（v0.27 起的 60+ 轮迭代）

v0.27 之后是密集的内迭代阶段：隐藏期零空转治理、桌面歌词窗口、设置架构重排、组件 schema 化、安全合规治理、内存泄漏修复、启动三档化……大量工程改进累积，但 GitHub 上**只发过 v1.0.0 与 v0.8 两个正式 Release**。

期间用户可感知的新增：桌面歌词窗口（R51+）、桌面歌词独立配色（R55）、应用专属主题（v0.27 起）、健康/智能家居/快递 schema 化（R58~R61）、桌面歌词窗口位置守护（R59）、设置架构重排（R57）、记账 BeeCount 今日收支摘要（R58）、隐私清单（R50）。

详细历史见 [docs/CHANGELOG.md](docs/CHANGELOG.md)。

---

## 数据来源

- **[LyricsKit](https://github.com/ddddxxx/LyricsKit)** — 多平台歌词搜索（网易云 / QQ 音乐 / 酷狗 / Gecimi）
- **[MusicPlayer](https://github.com/ddddxxx/MusicPlayer)** — macOS 音乐播放器集成

### 上游项目

- **LyricsX** — 原作者 [@ddddxxx](https://github.com/ddddxxx)，当前维护 [@MxIris-LyricsX-Project](https://github.com/MxIris-LyricsX-Project/LyricsX)（MPL 2.0）
- **MTMR** — 原作者 [@Toxblh](https://github.com/Toxblh)（MIT）
- **mtmr-designer** — 原作者 [@josmanvis](https://github.com/josmanvis/mtmr-designer)（MIT）

### 其他依赖

- [SwiftyOpenCC](https://github.com/ddddxxx/SwiftyOpenCC) — 简繁中文转换
- [CombineX](https://github.com/cx-org/CombineX) — Combine 框架的开源实现
- [SnapKit](https://github.com/SnapKit/SnapKit) — Auto Layout DSL
- [MASShortcut](https://github.com/shpakovski/MASShortcut) — 全局快捷键
- [Sparkle](https://github.com/sparkle-project/Sparkle) — 应用更新
- [Then](https://github.com/devxoul/Then) — Swift 语法糖

## ⚠️ 重要免责声明

> 这是一个**个人实验项目**，仅用于学习与技术探索，不提供任何形式的保证。

### 版权说明

所有歌词数据的版权归各自所有者所有。本项目仅用于展示技术实现，不用于商业用途。

### 侵权请告知

如果你认为本项目侵犯了你的合法权益，请通过 GitHub Issues 与我联系，我会立即：
- 删除相关内容
- 或关闭整个仓库

---

> _Last updated: 2026-08-26 · docs-only PR · main @ `01008ec`_

## Screenshots (placeholder)

> 图片占位，待你授权截屏后填入：
> - `docs/screenshots/main-window.png` — 主设置窗口（22 Tab / 全局搜索）
> - `docs/screenshots/desktop-lyrics.png` — 桌面歌词悬浮窗（NSPanel + 卡拉 OK）
> - `docs/screenshots/ribbon-editor.png` — 可视化 Ribbon 编辑器（拖拽布局中）
