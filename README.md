# LyricsMTMR

> 在 MacBook Pro Touch Bar 上实时显示歌词 —— 将 [LyricsX](https://github.com/ddddxxx/LyricsX) 的歌词能力与 [MTMR](https://github.com/Toxblh/MTMR) 的 Touch Bar 组件体系合二为一的实验项目。

[![CI](https://github.com/Tangzishun-Li/LyricsMTMR/actions/workflows/build-test.yml/badge.svg)](https://github.com/Tangzishun-Li/LyricsMTMR/actions/workflows/build-test.yml)

---

## 这是什么

LyricsMTMR 是一款 macOS Touch Bar 增强工具。它把 LyricsX 的多平台歌词引擎集成进 MTMR 的 Touch Bar 组件体系中，让你在 Touch Bar 上实时看到正在播放歌曲的歌词（支持逐字卡拉 OK 高亮），同时保留了 MTMR 完整的组件生态：100+ 内置 widget、可视化布局编辑器、多主题、脚本集成等。

**核心定位**：一个"能显示歌词的 MTMR"——歌词只是开始，Touch Bar 上的任何信息都可以自定义。

## ✨ 功能特性

### 🎵 歌词系统
- **多平台歌词源**：QQ 音乐 / 网易云 / 酷狗 / Gecimi / 本地 `.lrc` / `.lrcx`，自动搜索与匹配
- **逐字卡拉 OK 高亮**：逐字时间线与播放进度精确对齐（修复了跳字重影、解析崩溃与时间漂移）
- **歌词过滤**：自动过滤制作人员（词/曲/编曲/混音等 credit 行）
- **浏览器视频字幕转歌词**：YouTube / Bilibili 视频字幕接入，边看视频边在 Touch Bar 上看"歌词"
- **翻译显示**：外文歌曲可同时显示译文
- **多播放器支持**：Music、Spotify、Vox、Swinsian、Audirvana 等（通过 MusicPlayer 框架）

### 🧩 Widget 组件库（100+）
- **系统监控**：CPU / 内存 / 磁盘 / 网络 / 电池 / 风扇
- **音乐与媒体**：专辑封面、播放控制、音量、进度条
- **效率工具**：天气、时钟、日历、备忘录、剪贴板
- **数据面板**：股票（A 股 + 分时图，按主题统计）、天气（中国天气网国内数据源，免 Key、多城市）、快递、OpenCode Go 用量、BeeCount 记账同步
- **开发相关**：Git 状态、Docker、AppleScript、Shell 脚本、API 测试器、二维码、Latex 符号、论文进度等
- **AI 助手**：内置对话组件，API Key / 服务地址 / 模型名完全自由填写（自带模型，不锁定厂商）

### 🎨 布局与主题
- **可视化 Ribbon 编辑器**：拖拽排列 Touch Bar 组件、实时预览、防误删确认、未保存提醒
- **Touch Bar 模拟器 / 镜像窗口**：在设置窗口内实时预览布局效果
- **主题系统**：15 套预设主题（theme1–15）+ 完全自定义，Dock 图标主题联动（主题作用域、数量不限、图标大小可调）
- **按软件切换布局（Per-app bar switching）**：为指定 App 绑定专属布局，前台切换到该 App 时自动加载（状态栏菜单 / 设置中一键创建规则，三种模式：始终 / 激活时 / 停用），切走时自动回落到默认布局
- **预设导入导出**：JSON 格式，兼容手写注释的 `items.json`

### ⚙️ 设置
- **14+ 分类设置 Tab**：歌词 / 组件 / 主题 / 快捷键 / 数据源 / 服务 / 高级……带全局搜索与目录跳转
- **真实持久化**：所有设置项均已接上真实读写，消除"改了白改"的摆设设置
- **快捷键绑定**：自定义全局快捷键触发任意 Touch Bar 组件
- **RSS 订阅**：配置 RSS 源并在 Touch Bar 查看未读
- **配置导入导出 / 一键重置**

### 🔌 集成与扩展
- **AppleScript / Shell 脚本**：任意脚本输出显示在 Touch Bar（可视化代码生成器辅助）
- **第三方数据接入**：本地 JSON 数据文件接口（`expenses.json` 等），外部程序可写入后实时显示
- **HomeKit / Docker / MediaRemote** 等系统能力集成
- **全局快捷键**：MASShortcut 支持

## 🚀 快速开始

### 方式一：直接下载发行版
从 [Releases](https://github.com/Tangzishun-Li/LyricsMTMR/releases) 页面下载最新版本的 `.app`（通用二进制，Intel / Apple Silicon 均可运行），拖入「应用程序」即可。

> 首次启动会在系统设置中请求「辅助功能」权限（Touch Bar 控制需要）。

### 方式二：从源码构建
需要 macOS 13+ 与 Xcode 15+（含命令行工具）。

```bash
git clone https://github.com/Tangzishun-Li/LyricsMTMR.git
cd LyricsMTMR

make build     # Debug 构建
make test      # 运行单元测试
make archive   # 生成通用（arm64 + x86_64）未签名归档
```

构建产物位于 `LyricsMTMR/Release/`。详细构建说明见 [file-structure.zh.md](LyricsMTMR/docs/file-structure.zh.md)。

## 📖 使用指南

首次启动后，在菜单栏点击 LyricsMTMR 图标进入设置窗口：

1. **选择主题**：设置 → 主题，从 15 套预设中选择，或导入 `examples/presets/` 下的示例
2. **添加歌词组件**：设置 → 编辑器，拖入 `LyricsTouchBarItem` / `KaraokeLabel` 组件，播放任意音乐即可看到歌词
3. **自定义组件**：设置 → 组件，从 100+ widget 中选择；或使用 AppleScript / Shell 脚本显示任意内容
4. **配置数据源**：股票、天气、快递等外部数据组件的配置方法见文档

### 文档索引

| 文档 | 说明 |
|------|------|
| [外部数据使用指南](LyricsMTMR/docs/user-guide/external-data.zh.md) | 股票 / 天气 / 快递 / AI 用量等组件配置 |
| [脚本与自动化指南](LyricsMTMR/docs/user-guide/scripting.zh.md) | AppleScript / Shell 自定义组件 |
| [ITEMS_REFERENCE.md](LyricsMTMR/docs/ITEMS_REFERENCE.md) | 全部组件 type 与 JSON 配置参考 |
| [第三方接入](LyricsMTMR/docs/第三方接入.md) | 本地 JSON 数据文件接口 |
| [开发者 API 文档](LyricsMTMR/docs/README.md) | 外部 / 脚本 / 内部 API 中英双语参考 |
| [文件存放说明](LyricsMTMR/docs/file-structure.zh.md) | 目录职责与新增文件归属 |

## 🧩 项目结构

| 目录 | 说明 |
|------|------|
| `LyricsMTMR/` | Xcode 工程（`LyricsMTMR.xcodeproj`），源码按 App / Core / Support / Widgets / Preferences / LyricsIntegration 分层 |
| `LyricsMTMR/Scripts/` | 构建与开发脚本：`build.sh`、`test.sh`、`archive.sh`、主题/工程生成工具 |
| `LyricsMTMR/docs/` | 用户 / 开发者文档、API 参考、文件结构说明 |
| `examples/presets/` | 主题预设示例（theme1–15、items.json） |
| `tools/` | 调试工具（`mr-dump`、虚拟键盘原型） |
| `.github/workflows/` | CI：push / PR 自动构建与测试，tag 触发通用架构归档 |

## 📝 更新日志

### v0.8（预发布）
#### 新增
- **记账 BeeCount 同步**：SecretsManager 新增 `beecountURL` / `beecountPAT` 配置 + 连通性测试
- **AI 助手改为自带模型**：API Key / 服务地址 / 模型名自由填写，不再锁定内置服务
- **天气改用国内数据源**（中国天气网，免 Key）+ 多城市切换
- **浏览器视频字幕接入**：YouTube / Bilibili 字幕转歌词，边看视频边看"歌词"
- **OpenCode Go 用量 widget** + theme4 预设 + 工具 Tab
- **歌词搜索候选数量可配置**，酷狗 accesskey 容错
- **长设置页目录跳转**，快速定位设置项

#### 改进
- **设置界面全部接上真实持久化**——消除"改了白改"的摆设设置；读写兼容手写注释的 `items.json`
- **Dock 设置真实生效**——主题作用域 + 数量不限 + 图标大小
- **股票 Tab 重构**——按主题统计与增删改
- **编辑器操作逻辑重构**——主题编辑/切换修复、组件插入与拖拽、防误删确认、保存/关闭流程优化（未保存提醒、错误提示、实时预览防抖）
- **widget 增强**：修复 sparkline 布局并新增可配置项
- **构建警告清零**（68 → 0）：弃用 API 迁移与死代码清理

#### 性能与稳定性
- 修复卡拉 OK 跳字重影与逐字歌词显示异常，补全歌词解析链路
- 修复 `AppScrubberTouchBarItem` observer 泄漏
- 修复 widget timer/observer 泄漏并降低空闲 CPU
- 重复定时器加 tolerance、封面缓存降采样
- 退出时清理 LyricsEngine 孤儿进程，移除启动空转 timer
- 显式重载 preset 后不再冻结未构建的 Touch Bar

#### 工程与文档
- 源码目录分层重构（App / Core / Support、Preferences / Editor、Widgets 按领域分组）
- 构建逻辑优化：CI 修复、entitlements 统一、一键构建脚本；Sparkle.framework 入库
- 新增用户 / 开发者两册中英双语 API 文档与文件存放说明

### v1.0.0（首个正式发行版）
- 歌词渲染引擎优化（KaraokeLabel 逐字高亮 / LyricsTouchBarItem 滚动）
- 设置窗口全面重构：14+ Tab 页、全局搜索、配置导入导出、一键重置
- 56+ Touch Bar item 全面升级，10 个新测试主题（theme6–15）
- 8 个新 widget：ApiTester、BilibiliFeed、CitationGen、FinderTags、LatexSymbols、PaperProgress、PaperTags、QRCode
- 快捷键绑定、RSS 订阅、Touch Bar 模拟器、AppleScript 代码生成器、草稿管理器、异常捕获器
- 完整 Release Notes 见 [GitHub Releases](https://github.com/Tangzishun-Li/LyricsMTMR/releases/tag/v1.0.0)

## TODO

- [x] 完成歌词和封面的显示
- [x] 逐字歌词（卡拉 OK 式跳字高亮）
- [x] 每个软件自定义类别
- [x] 加入股市的 api，包括 A 股并加入分时图
- [ ] 剪切板快捷查看
- [ ] ……

## 数据来源

本项目中的歌词数据来自以下开源项目提供的歌词源：

- **[LyricsKit](https://github.com/ddddxxx/LyricsKit)** — 提供多平台歌词搜索能力（支持网易云音乐、QQ 音乐、酷狗、Gecimi 等）
- **[MusicPlayer](https://github.com/ddddxxx/MusicPlayer)** — 提供与 macOS 音乐播放器（Music、Spotify、Vox、Swinsian、Audirvana 等）的集成

### 上游项目

- **LyricsX** — 原作者 [@ddddxxx](https://github.com/ddddxxx)，当前维护 [@MxIris-LyricsX-Project](https://github.com/MxIris-LyricsX-Project/LyricsX)
  - 许可证：MPL 2.0
- **MTMR** — 原作者 [@Toxblh](https://github.com/Toxblh) (Anton Palgunov)
  - 许可证：MIT
- **mtmr-designer** — 原作者 [@josmanvis](https://github.com/josmanvis/mtmr-designer)
  - 许可证：MIT

### 其他依赖

- [OpenCC (SwiftyOpenCC)](https://github.com/ddddxxx/SwiftyOpenCC) — 简繁中文转换
- [CombineX](https://github.com/cx-org/CombineX) — Combine 框架的开源实现
- [SnapKit](https://github.com/SnapKit/SnapKit) — Auto Layout DSL
- [MASShortcut](https://github.com/shpakovski/MASShortcut) — 全局快捷键管理
- [Sparkle](https://github.com/sparkle-project/Sparkle) — 应用更新框架
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

## ⚠️ Important Disclaimer

> This is a **personal experimental project** solely for learning and technical exploration. No warranties of any kind are provided.

### Copyright Notice
All lyrics content is the property and copyright of their respective owners. This project is for demonstrating technical implementation only and is not intended for commercial use.

### Takedown Request
If you believe this project infringes upon your legal rights, please contact me via GitHub Issues and I will promptly:
- Remove the relevant content
- Or take down this entire repository
