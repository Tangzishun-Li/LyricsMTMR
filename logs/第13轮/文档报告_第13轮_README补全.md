# 文档报告 第13轮 — README 补全

> 第 13 轮子任务 B（文档卡，t_2d42b7e3）｜分支 r13/docs（基于 main@77faefe）｜2026-08-12
> 职责：README 增补「macOS 15.4+ 音乐信息获取机制与已知风险」+「应用专属主题」功能说明，核对其余章节漂移。

---

## 一、本次改了什么

### 1. README.md 增补（2 处新增）

**A. 新增小节「### 🎵 macOS 15.4+ 音乐信息获取机制与已知风险」**（位于「🔌 集成与扩展」之后、「🚀 快速开始」之前）

- **背景**：macOS 15.4+ `mediaremoted` 校验客户端 entitlements，裸调 `MRMediaRemoteGetNowPlayingInfo` 报 `Operation not permitted`（LyricFever#94 多方确认）；
- **工作机制**（mediaremote-adapter 架构）：
  1. Swift 侧 `MediaRemoteAdapter` 拉起系统自带特权二进制 `/usr/bin/perl` 子进程（`run.pl`）；
  2. `run.pl` 经 `DynaLoader::dl_load_file` 加载 `MediaRemoteMRBridge.dylib`（App 私有 Frameworks 内），dylib 内部 `dlopen/dlsym` 运行时解析 MediaRemote 私有框架符号；
  3. 子进程 `loop` 模式注册 Now Playing 通知，JSON 行流经 stdout 管道回传 Swift 主进程；
  4. 播放控制经同一子进程一次性命令执行；
- **已知风险**：① 依赖私有框架与平台二进制特权，Apple 未来可能再次封堵（macOS 26 曾出现一次并已跟进修复）；② 曲目信息依赖来源 App 主动上报，部分 App 不可用；
- **关联 issue #1**：用户反馈 macOS 15.7 获取音乐信息困难即由此机制解决（commit `b2e24aa`，随 v0.27 发布）。

**B. 新增「应用专属主题（Per-app bar switching）」功能说明**（两处）：

- 「🎨 布局与主题」特性列表新增 1 条：一句话点明功能 + 对应 issue #40 + 指向使用指南锚点；
- 「📖 使用指南」新增独立小节「### 应用专属主题（Per-app bar switching）」：
  - **入口**：设置 → 通用 →「应用专属主题」区块；或状态栏菜单 →「应用专属主题」卡片；
  - **创建规则**：「为当前应用创建主题」——以当前布局为模板生成 `Application Support/LyricsMTMR/app-themes/<BundleID>.json`，默认「始终使用」并自动打开编辑；
  - **编辑 / 删除**：规则列表内可编辑主题文件、切换激活模式、移除规则（连带删除主题文件）；
  - **激活模式三态表格**：始终使用（每次前台强制）/ 激活时使用（仅切换进入时应用，尊重手动覆盖）/ 已停用（保留但不生效）；
  - 附注：主题文件被手动删除时规则自动移除并回退（对应代码 `handleAppThemeSwitch` 的文件缺失回退逻辑）；
  - 与 issue #40 的关系：即 backlog「Per-app bar switching」需求的实现（commit `2b84be3` 的 `appThemeRules` / `app-themes` 机制）。

### 2. README.md 漂移修正（4 处小改）

| # | 原文（漂移） | 修正后 | 依据 |
|---|---|---|---|
| 1 | 「100+ 内置 widget」（3 处：简介 / 组件库标题 / 使用指南） | 「99 种内置 widget」 | `ItemsParsing.swift` ItemTypeRaw 枚举实测 **97** 个 type + 额外注册 `close` / `exitTouchbar` = **99** 种（ITEMS_REFERENCE 亦载明 80+ 为旧口径，本报告以实测为准） |
| 2 | 「设置 → 主题，从 15 套预设中选择」 | 「设置 → 编辑器，顶部「配置」下拉…」+ 补充 themeSwitch / 状态栏菜单入口 | 设置窗口 SettingsTab 枚举 22 个 Tab 中**无「主题」Tab**；主题选择实现在 EditorTabView 顶部「配置」下拉（themePopup） |
| 3 | 「设置 → 组件，从 100+ widget 中选择」 | 「设置 → 编辑器，从左侧元素面板的 99 种 widget 中选择」 | 设置窗口**无「组件」Tab**；widget 添加入口在编辑器 Tab 的 EditorPaletteView 元素面板 |
| 4 | 「14+ 分类设置 Tab：歌词 / 组件 / 主题 / 快捷键 / 数据源 / 服务 / 高级……」 | 「22 个分类设置 Tab：通用 / 歌词 / 槽位 / 编辑器 / 键位 / 服务 / 关于 / 股票 / 番茄钟 / 天气 / RSS / 快递 / 日历 / 智能家居 / AI 助手 / 记账 / Dock / 通知 / 系统监控 / 健康 / 生活 / 快捷工具」 | `UnifiedSettingsWindowController.swift` SettingsTab 枚举实测 **22** case，原列举的「组件 / 主题 / 数据源 / 高级」均非实际 Tab 名 |
| 5 | 「QQ 音乐 / 网易云 / 酷狗 / **Gecimi** / 本地 .lrc / .lrcx」 | 「…/ **咪咕** / …」 | `LyricsProviderID` 枚举实测 provider 为 netease / qqMusic / kugou / **migu** / spotify / subtitle / custom，**代码中无 Gecimi**（仅 README 数据来源章节对上游 LyricsKit 能力的描述保留 Gecimi 字样，未动） |

> 说明：第 1、3 条合并为同一事实（widget 数量）；上表按修改点编号。未涉及「15 套预设主题（theme1–15）」——`examples/presets/` 实测 15 个 theme*.json，与 README 一致，无需修改。

### 3. 链接核对（README 引用文件全部在位）

- `LyricsMTMR/docs/file-structure.zh.md` ✅
- `LyricsMTMR/docs/user-guide/external-data.zh.md` ✅
- `LyricsMTMR/docs/user-guide/scripting.zh.md` ✅
- `LyricsMTMR/docs/ITEMS_REFERENCE.md` ✅
- `LyricsMTMR/docs/第三方接入.md` ✅
- `LyricsMTMR/docs/README.md` ✅
- 新增锚点 `#应用专属主题per-app-bar-switching`（GitHub 中文锚点生成规则：去括号、空格转连字符）

---

## 二、核对结论（README 其余章节 vs 现状）

| 核对项 | 结论 |
|---|---|
| 主题数量「15 套预设（theme1–15）」 | ✅ 一致（examples/presets 实测 15 个 theme*.json） |
| v1.0.0「10 个新测试主题（theme6–15）」 | ✅ 一致（theme6–15 恰 10 个） |
| v1.0.0「8 个新 widget：ApiTester / BilibiliFeed / CitationGen / FinderTags / LatexSymbols / PaperProgress / PaperTags / QRCode」 | ✅ 一致（ItemsParsing.swift 8 个 case 全部实测命中） |
| 多播放器「Music / Spotify / Vox / Swinsian / Audirvana（MusicPlayer 框架）」 | ✅ 一致（MusicPlayer 枚举实测包含这些 bundle id） |
| 「天气（中国天气网国内数据源，免 Key、多城市）」 | ✅ 一致（weather case 含 apiSource="china" 与 cities） |
| 「OpenCode Go 用量 / BeeCount 记账 / theme4 预设 / 工具 Tab」 | ✅ 一致（opencodeGoUsage case、beecountURL/PAT、theme4.json、ToolsTabView 均实测在位） |
| 歌词组件「LyricsTouchBarItem / KaraokeLabel」 | ✅ 一致（KaraokeLabel 用于逐字渲染，LyricsTouchBarItem 为歌词 item） |
| 集成列表「HomeKit / Docker / MediaRemote」 | ✅ 一致（HomekitTabView / DockerStatus / MediaRemoteAdapter 均在位） |
| widget 数量「100+」 | ⚠️ 已修正为 99（见上表） |
| 设置 Tab 描述「14+」 | ⚠️ 已修正为 22（见上表） |
| 其余（更新日志为历史记录，不追溯） | ✅ 无需改动 |

---

## 三、未改动项与理由

- **ITEMS_REFERENCE.md 的「80+ 种 Item 类型」**：同为旧口径（实测 97+2=99），但本文档职责为 README；ITEMS_REFERENCE 属独立参考手册，留待后续轮次单独核对（本报告已记录差异，可作下轮依据）。
- **README 数据来源章节「LyricsKit 支持…Gecimi 等」**：描述的是**上游 LyricsKit 库**的能力，非本项目自带 provider 列表，属准确陈述，保留。
- **v0.8 / v1.0.0 更新日志**：历史记录，不改。

---

## 四、约束遵守

- 纯文档改动（README.md + 本报告 + iteration-log.md + file-structure.zh.md），**零代码改动** → 按任务约束不触发构建/测试（xcodebuild 可跳过）；
- 所有改动仅在本工作区（`/Users/litz/codespace/MTMR with LyricsX /.worktrees/round13-B`）与分支 r13/docs；
- 未 push 远端（父任务收口统一合并）；未开新分支 / 新子任务。
