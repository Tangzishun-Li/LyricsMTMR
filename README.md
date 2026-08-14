# LyricsMTMR

> 在 MacBook Pro Touch Bar 上实时显示歌词 —— 将 [LyricsX](https://github.com/ddddxxx/LyricsX) 的歌词能力与 [MTMR](https://github.com/Toxblh/MTMR) 的 Touch Bar 组件体系合二为一的实验项目。

[![CI](https://github.com/Tangzishun-Li/LyricsMTMR/actions/workflows/build-test.yml/badge.svg)](https://github.com/Tangzishun-Li/LyricsMTMR/actions/workflows/build-test.yml)

---

## 这是什么

LyricsMTMR 是一款 macOS Touch Bar 增强工具。它把 LyricsX 的多平台歌词引擎集成进 MTMR 的 Touch Bar 组件体系中，让你在 Touch Bar 上实时看到正在播放歌曲的歌词（支持逐字卡拉 OK 高亮），同时保留了 MTMR 完整的组件生态：114 种内置 widget、可视化布局编辑器、多主题、脚本集成等。

**核心定位**：一个"能显示歌词的 MTMR"——歌词只是开始，Touch Bar 上的任何信息都可以自定义。

## ✨ 功能特性

### 🎵 歌词系统
- **多平台歌词源**：QQ 音乐 / 网易云 / 酷狗 / 咪咕 / 本地 `.lrc` / `.lrcx`，自动搜索与匹配
- **逐字卡拉 OK 高亮**：逐字时间线与播放进度精确对齐（修复了跳字重影、解析崩溃与时间漂移）
- **歌词过滤**：自动过滤制作人员（词/曲/编曲/混音等 credit 行）
- **浏览器视频字幕转歌词**：YouTube / Bilibili 视频字幕接入，边看视频边在 Touch Bar 上看"歌词"
- **翻译显示**：外文歌曲可同时显示译文
- **多播放器支持**：Music、Spotify、Vox、Swinsian、Audirvana 等（通过 MusicPlayer 框架）

### 🧩 Widget 组件库（114 种）
- **系统监控**：CPU / 内存 / 磁盘 / 网络 / 电池 / 风扇
- **音乐与媒体**：专辑封面、播放控制、音量、进度条
- **效率工具**：天气、时钟、日历、节假日倒计时（holidayCountdown，复用法定节假日表）、备忘录、剪贴板
- **数据面板**：股票（A 股 + 分时图，按主题统计）、天气（中国天气网国内数据源，免 Key、多城市）、快递、OpenCode Go 用量、BeeCount 记账同步
- **开发相关**：Git 状态、Docker、AppleScript、Shell 脚本、API 测试器、二维码、Latex 符号、论文进度等
- **AI 助手**：内置对话组件，API Key / 服务地址 / 模型名完全自由填写（自带模型，不锁定厂商）

### 🎨 布局与主题
- **可视化 Ribbon 编辑器**：拖拽排列 Touch Bar 组件、实时预览、防误删确认、未保存提醒
- **Touch Bar 模拟器 / 镜像窗口**：在设置窗口内实时预览布局效果
- **主题系统**：15 套预设主题（theme1–15）+ 完全自定义，Dock 图标主题联动（主题作用域、数量不限、图标大小可调）
- **应用专属主题（Per-app bar switching）**：为指定 App 绑定独立 Touch Bar 布局，切换应用自动换主题（对应 [issue #40](https://github.com/Tangzishun-Li/LyricsMTMR/issues/40)，用法见[使用指南](#应用专属主题per-app-bar-switching)）
- **预设导入导出**：JSON 格式，兼容手写注释的 `items.json`

### ⚙️ 设置
- **22 个分类设置 Tab**：通用 / 歌词 / 槽位 / 编辑器 / 键位 / 服务 / 关于 / 股票 / 番茄钟 / 天气 / RSS / 快递 / 日历 / 智能家居 / AI 助手 / 记账 / Dock / 通知 / 系统监控 / 健康 / 生活 / 快捷工具，带全局搜索与目录跳转
- **真实持久化**：所有设置项均已接上真实读写，消除"改了白改"的摆设设置
- **快捷键绑定**：自定义全局快捷键触发任意 Touch Bar 组件
- **RSS 订阅**：配置 RSS 源并在 Touch Bar 查看未读
- **配置导入导出 / 一键重置**

### 🔌 集成与扩展
- **AppleScript / Shell 脚本**：任意脚本输出显示在 Touch Bar（可视化代码生成器辅助）
- **第三方数据接入**：本地 JSON 数据文件接口（`expenses.json` 等），外部程序可写入后实时显示
- **HomeKit / Docker / MediaRemote** 等系统能力集成（MediaRemote 机制与风险见下文）
- **全局快捷键**：MASShortcut 支持

### 🎵 macOS 15.4+ 音乐信息获取机制与已知风险

> **背景**：自 macOS 15.4 起，系统 `mediaremoted` 开始校验客户端 entitlements，直接调用私有框架 MediaRemote 的 `MRMediaRemoteGetNowPlayingInfo` 会报 `Operation not permitted`（LyricFever#94 等多方确认）。本项目通过 **mediaremote-adapter** 子进程桥接方案绕过该限制。

**工作机制**（架构见 `LyricsIntegration/MediaRemoteAdapter.swift` + `CBridge/MediaRemoteMRBridge.m` + `Resources/run.pl`）：

- 应用启动后，Swift 侧 `MediaRemoteAdapter` 拉起一个**系统自带特权二进制 `/usr/bin/perl`** 的子进程（`run.pl`）；
- `run.pl` 通过 `DynaLoader::dl_load_file` 加载应用内随附的桥接动态库 `MediaRemoteMRBridge.dylib`（位于 `Frameworks/`），dylib 内部以 `dlopen/dlsym` 在运行时解析 MediaRemote 私有框架符号（不静态链接）；
- 子进程以 `loop` 模式注册 Now Playing 通知（`kMRMediaRemoteNowPlayingInfoDidChangeNotification` 等），将曲目信息 / 播放状态以 **JSON 行流** 经 stdout 管道回传给 Swift 主进程；
- 播放控制（播放 / 暂停 / 上一首 / 下一首 / 跳转等）同样经由该子进程以一次性命令执行。

**已知风险**：

- **依赖私有框架与平台二进制特权**：MediaRemote 为未公开框架，`/usr/bin/perl` 的特权行为随系统变化——Apple 未来系统更新可能再次封堵（**macOS 26 曾出现一次并已跟进修复**）；届时曲目信息获取将失效，直至适配修复；
- **信息来源 App 可能不可用**：曲目信息依赖播放 App 主动上报 Now Playing 数据，部分 App 不提供或不更新该信息时，音乐相关组件无法获取到数据（非本项目可控制）。

**关联 Issue**：[#1](https://github.com/Tangzishun-Li/LyricsMTMR/issues/1)（用户反馈 macOS 15.7 获取音乐信息困难）即由此机制解决（集成于 commit `b2e24aa`，随 v0.27 发布）；若在特定系统版本遇到音乐信息获取异常，优先检查是否为本节所述的封堵问题，并到 issue 中反馈系统版本与日志。

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

1. **选择主题**：设置 → 编辑器，在顶部「配置」下拉中选择 15 套预设主题（theme1–15），或导入 `examples/presets/` 下的示例；也可通过 Touch Bar 上的 `themeSwitch` 组件或状态栏菜单切换
2. **添加歌词组件**：设置 → 编辑器，拖入 `LyricsTouchBarItem` / `KaraokeLabel` 组件，播放任意音乐即可看到歌词
3. **自定义组件**：设置 → 编辑器，从左侧元素面板的 114 种 widget 中选择；或使用 AppleScript / Shell 脚本显示任意内容
4. **配置数据源**：股票、天气、快递等外部数据组件的配置方法见文档

### 应用专属主题（Per-app bar switching）

为常用 App（如 Xcode、浏览器、播放器）绑定独立的 Touch Bar 布局，切换应用时 Touch Bar 自动换成对应主题，切回其他应用时自动恢复之前的布局。功能对应 [issue #40](https://github.com/Tangzishun-Li/LyricsMTMR/issues/40)（backlog 中的 Per-app bar switching 需求，实现于 commit `2b84be3` 的 `appThemeRules` / `app-themes` 机制）。

**入口**（二选一）：
- 设置 → 通用 →「应用专属主题」区块
- 状态栏菜单 →「应用专属主题」卡片（对当前前台 App 操作最方便）

**创建规则**：点击「为当前应用创建主题」——以当前布局为模板生成该 App 的主题文件（存于 `Application Support/LyricsMTMR/app-themes/<BundleID>.json`），规则默认「始终使用」并自动打开文件供编辑。

**编辑 / 删除规则**：在规则列表中可对每条规则：
- **编辑主题**：用默认 JSON 编辑器打开该 App 的主题文件，修改布局后保存即生效；
- **切换激活模式**：三态含义见下表；
- **移除规则**：删除规则并同时删除对应的主题文件。

**激活模式三态**：

| 模式 | 含义 |
|------|------|
| 始终使用（Always） | 每次该 App 成为前台应用时都强制应用其专属主题 |
| 激活时使用（On Activation） | 仅在该 App **被激活（切换进入）时**应用主题；激活后若用户手动切换主题，尊重手动选择，直到下次切换 App |
| 已停用（Disabled） | 规则保留但不生效，等同于未配置 |

> 提示：若主题文件被手动删除，对应规则会自动移除并回退到切换前的布局，不会卡在空主题上。

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

### 版本史说明

> **考古结论（2026-08-13 第 25 轮实证，详见《考古报告_第25轮_版本体系考古.md》】**：本项目正式发布记录仅 2 枚——v1.0.0（首个正式发行版，2026-07-29 发布）与 v0.8（预发布，2026-08-09 发布）；git tag 另有 1 枚内部快照（pre-opt-20260812-0114，非版本发布）。**v0.9 ~ v0.26 从未以 Release / tag / Info.plist 版本号任何形式存在过**——该区间是更新日志编号序列中的空洞：Info.plist 的 0.27/452 为 fork 自上游 MTMR（最高版本 v0.27.0）时继承的工程版本号，v1.0.0 / v0.8 两 tag 指向的提交中均为 0.27/452（营销版本号与工程版本号长期脱节），至第 24 轮收口（2026-08-13）方升为 0.28/453。更新日志自 v0.27 起按迭代轮次补记（v0.27=第 13~18 轮快照，v0.28=第 20~23 轮，v0.29=第 24~27 轮，v0.30=第 28~29 轮，v0.31=第 30 轮，v0.32=第 31 轮，v0.33=第 32 轮，v0.34=第 33 轮，v0.35=第 34 轮，v0.36=第 35 轮，v0.37=第 36 轮，v0.38=第 37 轮，v0.39=第 38 轮，v0.40=第 39 轮，v0.41=第 40 轮，v0.42=第 41 轮，v0.43=第 42 轮），此前条目为发布时实况。

### v0.43（当前开发版本）

> 承接第 42 轮：注册表写入侧 encode 审计与治理（数据与存储维度——decode 迁移系列写侧镜像：全仓写入侧盘点分类——9 处 JSONEncoder 全部同型 JSONDecoder 读配对 + 23 处 UserDefaults .set + LyricsItemConfig 12 处全部同键读侧配对 + items.json 字典写路径 JSONSerialization 透传非 Item encode 路径，核心结论 93 类已迁 Item 双向对称由架构保证；发现并根因修复真实问题 2 处——SettingsSync.writeBack 无匹配仍无条件 saveItems 重写 items.json（空写清掉用户手写注释+规范化格式=数据损坏风险）→ 加 didMatch 守卫无匹配不落盘、AITabView.swift:227 死写路径 writeBack(type:"ai")（不存在 type "ai"）→ 删除该行；新增 WriteSideContractTests 6 用例（无匹配不重写×3 + 匹配合并保未知键×3，红 2 failure→绿 6/6 双跑实证未放宽断言）；449 用例实证 0 失败（443 基线 + 新增 6 零偏差，98.6s））、锚点巡检收口复跑接入保持（连续第十八轮 0 ERROR），并完成工程版本号对齐（Info.plist 0.41/466 → 0.42/467）。

#### 工程与稳定性

- **注册表写入侧 encode 审计与治理（数据与存储维度——decode 迁移系列写侧镜像）**：decode 迁移系列（第 30~36 轮）已把 93/98 类 Item 读侧迁入注册表混合架构并全链路闭环（契约测试 173 用例 + RegistryReconciliationTests 6 + WidgetLeakTests 30，443 用例基线 0 失败），本轮写侧镜像审计验证「decode 已迁、encode 未迁 = 不对称风险点」是否成立——全仓写入侧路径盘点分类：9 处 JSONEncoder（SlotManager:74 / KeyBindingModel:316/:347 / LyricsSelectionCache:108 / WidgetKit:957 / ExpenseTracker:106 / ClipboardHistory:129 / PaperProgress:44 / PaperTags:82）全部有同型 JSONDecoder 读配对（含 KeyBinding Set<KeyModifier> CodingKeyRepresentable 自定义编解码、LyricsItemConfig NSKeyedArchiver 颜色归档）逐点核对对称；23 处 UserDefaults .set（ToolsTabView 9 / UnifiedSettingsWindowController 3 / OpenCodeGo 2 / AITabView 2 / AppSettings 2 / PostureReminder 1 / SecretsManager 1 / SettingsSync 1 / GeneralTab 1 / StatusBarMenu 1）+ LyricsItemConfig 12 处全部同键读侧配对；items.json 字典写路径（SettingsSync.saveItems / DraftManager / RibbonEditorView / SlotManager themeSwitch 注入）为 `[[String: Any]]` 字典透传（JSONSerialization，非 Item encode 路径）——**写侧不经过 Item 编码，读侧注册表 decodeIfPresent 容缺键，双向对称由架构保证：93 类已迁 Item 不存在「decode 已迁、encode 未迁」不对称**；序列化失败静默吞错（try? encode/write）评估为全仓既有风格、无编码失败实际触发路径（基础类型数据），登记已知取舍不扩大改动面；**发现并根因修复真实问题 2 处**：① SettingsSync.writeBack(type:/matcher:) 无匹配仍无条件 saveItems 重写 items.json——空写清掉用户手写注释+规范化格式（.prettyPrinted+.sortedKeys）纯副作用数据损坏风险（实测触发实例：AITabView 以不存在的 type "ai" 每次 AI 设置变更必触发整文件重写）→ 加 didMatch 守卫无匹配不落盘（index 重载已有越界守卫保持）；② AITabView.swift:227 死写路径 SettingsSync.writeBack(type:"ai")——不存在 type "ai"（真实类型 aiSelectedText 仅 model/prompt 两属性；streamOutput/showBalance 是 UserDefaults 专属设置，load() 同源读）→ 删除该行，行为零变化（读写两端同为 UserDefaults），消除无效写路径；新增契约测试 WriteSideContractTests.swift 6 用例（无匹配不重写×3（type/matcher/index）+ 匹配合并保未知键×3（非匹配 item 与 customKey 原样保留=写侧不吞键契约），沿用 ClipboardHistoryItem.persistHistory 同型测试钩子 SettingsSync.itemsJSONPathOverride（生产恒 nil 走真实路径，测试指向临时目录 tearDown 清理），红（2 failure：无匹配重写两用例实测文件被重写注释被清）→ 绿（6/6）双跑实证未放宽断言（XCTAssertEqual 原文件字节比对））；**449 用例实证（443 基线 + 新增 6 零偏差，98.6s）0 失败**（金丝雀 StockMarketHoursTests 16 + WidgetLeakTests 30 + RegistryReconciliationTests 6 + ItemTypeDecodeRegistryTests 173 全绿）
- **锚点巡检收口复跑接入保持**：scripts/anchor-patrol.py 收口复跑接入（第 29 轮 B 卡固化）连续第十八轮保持——第 42 轮 A 卡复跑 PASS 72 / WARN 11 / INFO 5 / ERROR 0 退出码 0，与第 41 轮收口基线逐项一致零新漂移，机器检查零回归
- **工程版本号对齐**：Info.plist 0.41/466 → 0.42/467（第 42 轮收口落地，B 卡版本决策建议收口采纳、README v0.42 条目对齐，营销版本号与工程版本号对齐惯例延续）

### v0.42

> 承接第 41 轮：编译告警清零与工程规范治理（代码质量与工程规范维度——xcodebuild 全量采集 12 条 warning 逐条分类（10 条代码警告集中在 7 文件 + 2 条 appintentsmetadataprocessor 工具提示豁免登记）；发现并根因修复真实显示 bug 1 类 8 处同源（917983f7 双反斜杠插值退化字面文本，恢复 8 处单反斜杠插值）；其余 7 条行为等价修复；治理后代码警告 10→0）、锚点巡检收口复跑接入保持（连续第十七轮 0 ERROR），并完成工程版本号对齐（Info.plist 0.40/465 → 0.41/466）。

#### 工程与稳定性

- **编译告警清零与工程规范治理（代码质量与工程规范维度）**：xcodebuild 全量采集 12 条 warning 逐条分类——10 条代码警告集中在 7 文件（WeatherBarItem 3 条 unused value / LyricsEngine 2 条 non-sendable NSImage? 跨隔离边界 / KeyBindingTabView 2 + TouchBarSimulatorView 1 条 onChange(of:perform:) 弃用 / UpNextScrubberTouchBarItem 1 条 .authorized 弃用 / RegistryReconciliationTests 1 条作用域末 defer）+ 2 条 appintentsmetadataprocessor 工具提示豁免登记（零 AppIntents.framework 依赖刻意设计，清零需引入依赖即行为变更）；**发现并根因修复真实显示 bug 1 类（8 处同源）**：commit 917983f7（2026-08-08 天气改国内数据源）把 Swift 插值 `\(` 写成 `\\(`（源码双反斜杠=转义反斜杠+字面文本，swiftc 最小复现 + hexdump `5c5c 28`→`5c 28` + git 历史旧版单反斜杠三方取证）——renderChinaWeather 标题/OpenWeather URL/scheduler identifier 全部退化为字面文本（Touch Bar 显示 `\(icon)\(cityLabel) 26°C`），同文件 205 行单反斜杠为意图之证；恢复 8 处单反斜杠插值（74/176/239/257/259/262/266/268），消除 W-1~3 及 5 处无警告同源 bug；其余 7 条全部行为等价修复（CoverCache 新增 `struct CoverArtwork: @unchecked Sendable { let image: NSImage? }` 盒化非 Sendable 返回（Swift 6 前瞻，2 调用点解包 .image）/ onChange(of:perform:) → 两参数闭包 `{ _, v in ... }` 迁移 3 处（部署目标 15.0 新 API 可用，旧闭包只用新值语义等价）/ UpNextScrubberTouchBarItem isAuthorized 去除 #available else 死代码分支（部署目标 15.0 #available 恒真，.authorized 不可达，保留 14+ 双态判定行为等价）/ RegistryReconciliationTests 作用域末 defer→直接调用（同一程序点行为等价，用例数不变））；WidgetKit.swift:973 显式 else 分支内 .authorized 编译器未报警告保持不动；治理后重新 build-for-testing 验证**代码警告 10→0**（剩余 2 条工具提示 + 1 条 xcodebuild destination 提示均登记豁免）；**443 用例实证（基线零偏差，97.1s）0 失败**（金丝雀 StockMarketHoursTests 16 全绿 + WidgetLeakTests 30/30 + RegistryReconciliationTests 6/6 + ItemTypeDecodeRegistryTests 173/173 全绿）
- **锚点巡检收口复跑接入保持**：scripts/anchor-patrol.py 收口复跑接入（第 29 轮 B 卡固化）连续第十七轮保持——第 41 轮收口后复跑 PASS 72 / WARN 11 / INFO 5 / ERROR 0 退出码 0，与第 40 轮收口基线逐项一致零新漂移，机器检查零回归
- **工程版本号对齐**：Info.plist 0.40/465 → 0.41/466（第 41 轮收口落地，B 卡版本决策建议收口采纳、README v0.41 条目对齐，营销版本号与工程版本号对齐惯例延续）

### v0.41

> 承接第 40 轮：异步闭包捕获链泄漏契约覆盖面扩展（非 timer/observer 的 block 捕获防回归网续织三——全仓审计 27 处 URLSession completion + 181 处 async + 39 处 asyncAfter + 34 处 DispatchWorkItem + 2 处 CoreAudio block listener 逐点分类（弱捕获在位 46 处/widget 级强捕获 2 处/零 self 单例值类型有界一次性豁免 42 处）；发现并根因修复真实永久泄漏 1 处——VolumeViewController CoreAudio property-listener block 方法引用强捕获 self + deinit 永不移除（bar 每次重建累积）→弱闭包 + block 恒等存储 + deinit 成对移除，红（1 failure）→绿（3/3）双跑实证未放宽断言；修复陈旧回调强捕获 1 处——WeatherBarItem:178 dataTask [weak self]；WidgetLeakTests 27→30 用例；443 用例实证 0 失败）、锚点巡检收口复跑接入保持（连续第十五轮 0 ERROR），并完成工程版本号对齐（Info.plist 0.39/464 → 0.40/465）。

#### 工程与稳定性

- **异步闭包捕获链泄漏契约覆盖面扩展（非 timer/observer 的 block 捕获防回归网续织三，内存修复主线续篇三）**：泄漏契约测试 27 → 30 用例（同一文件追加，沿用 autoreleasepool + weak var + letRunLoopSpin + XCTAssertNil 模式）——testVolumeViewControllerDoesNotLeak（修复点红绿实证，仅注册 CoreAudio 监听 + 读音量属性，零权限弹窗零硬件激活）/ testShellScriptTouchBarItemDoesNotLeak（NoExecShellScriptItem 子类 execute() 覆写为空零进程 spawn；asyncAfter 自循环 hop 弱捕获契约钉——interval 3600，hop 若改强捕获测试即红）/ testAppleScriptTouchBarItemDoesNotLeak（NoExecAppleScriptItem 子类 + EmptySource 桩零 Apple Events 弹窗；同上契约钉，为全仓仅有的 2 个 asyncAfter 自循环 widget 契约钉）；全仓审计 27 处 URLSession completion + 181 处 DispatchQueue.async（自捕获子集逐点核查）+ 39 处 asyncAfter + 34 处 DispatchWorkItem + 2 处 CoreAudio property-listener block（perform(after:)/NSURLSession 全仓 0 处）逐点分类（按对象生命周期与捕获强度，同前两轮口径：单例=app 豁免、无对象捕获豁免、widget/窗口级需契约）——弱捕获在位 46 处、widget 级强捕获 2 处、零 self/单例/值类型/有界一次性豁免 42 处；**发现并根因修复真实永久泄漏 1 处——VolumeViewController 的 AudioObjectAddPropertyListenerBlock 直接传实例方法引用默认强捕获 self + deinit 从不移除监听 → CoreAudio 系统对象进程生命周期持有每个构造实例（bar 每次重建累积）= 真实泄漏，改为 `[weak self]` 弱闭包 + block 存属性保证 add/remove 恒等（AudioObjectRemovePropertyListenerBlock 要求恒等）+ deinit 成对移除（removeAudioRouteChangedListener/removeLastAudioVolumeChangeListener）——红（1 failure）→绿（3/3）双跑实证未放宽断言**；另修复陈旧回调强捕获 1 处——WeatherBarItem.swift:178 dataTask completion `[weak self]`（有界保留消除；location==nil 测试路径零副作用不触发请求故以审计论证登记，构造路径 dealloc 由既有 testWeatherBarItemDoesNotLeak 钉住）；443 用例实证（440 基线 + 新增 3）0 失败，任务预算零偏差；金丝雀三锚点 + WidgetLeakTests 30 全绿（原 27 + 新增 3）；零生产代码改动面外（仅泄漏修复 2 处）
- **锚点巡检收口复跑接入保持**：scripts/anchor-patrol.py 收口复跑接入（第 29 轮 B 卡固化）连续第十五轮保持——第 40 轮收口后复跑 PASS 72 / WARN 11 / INFO 5 / ERROR 0 退出码 0，与第 39 轮收口基线逐项一致零新漂移，机器检查零回归
- **工程版本号对齐**：Info.plist 0.39/464 → 0.40/465（第 40 轮收口落地，B 卡版本决策建议收口采纳、README v0.40 条目对齐，营销版本号与工程版本号对齐惯例延续）

### v0.40

> 承接第 39 轮：Observer 泄漏契约覆盖面扩展（非 timer 资源类防回归网续织二——全仓审计 22 处 NotificationCenter 注册点分类（widget/窗口级 6 处需契约 + 单例或无对象捕获 6 处豁免）+ 1 处 CF 通知 + 1 处非 timer DispatchSource，KVO 全仓 0 处；发现并根因修复真实泄漏 1 处——UpNextScrubberTouchBarItem.swift:300 UpNextCalenderSource storeObserver 强捕获 self 保留环→弱闭包，红→绿→全量 440 三跑实证未放宽断言；WidgetLeakTests 23→27 用例；440 用例实证 0 失败）、锚点巡检收口复跑接入保持（连续第十三轮 0 ERROR），并完成工程版本号对齐（Info.plist 0.38/463 → 0.39/464）。

#### 工程与稳定性

- **Observer 泄漏契约覆盖面扩展（非 timer 资源类防回归网续织二，内存修复主线续篇二）**：泄漏契约测试 23 → 27 用例（同一文件追加，沿用 autoreleasepool + weak var + letRunLoopSpin + XCTAssertNil 模式）——testUpNextCalenderSourceDoesNotLeak（修复点钉契约，EKEventStore init + authorizationStatus TCC-safe 零弹窗）/ testThemeSwitchBarItemDoesNotLeak（2 block observer 弱闭包 + deinit 移除双 token）/ testAppScrubberTouchBarItemDoesNotLeak（3 NSWorkspace selector observer deinit/barItemWillDiscard unregister）/ testAudioSpectrumSettingsDrivenObserverDoesNotLeak（settingsDriven 路径，round-38 测试刻意跳过的路径）；全仓审计 22 处 NotificationCenter 注册点逐点分类（widget/窗口级 6 处需契约：ThemeSwitchBarItem 2 block / AudioSpectrumBarItem 1 block / UpNextCalenderSource 1 block / NetworkBarItem 1 block / AppScrubberTouchBarItem 3 selector / UnifiedSettingsWindowController 5 block；单例或无对象捕获 6 处豁免：AppDelegate 3 selector / TouchBarController 3 selector / LyricsEngine 1 selector+deinit removeObserver(self) / MediaRemoteMRBridge.m 2 block 零对象捕获 / InputSourceBarItem 1 CF unretained+deinit RemoveEveryObserver 在位）+ 1 处 CF 通知 + 1 处非 timer DispatchSource（AppDelegate fileSystemSource 单例豁免）；KVO 全仓 0 处；**发现并根因修复真实泄漏 1 处——UpNextScrubberTouchBarItem.swift:300 UpNextCalenderSource storeObserver `using: handleUpdate` 方法引用默认强捕获 self，形成 token→block→self 保留环使 deinit 永不可达、observer 永不移除，源对象 + EKEventStore 进程生命周期泄漏，改为 `{ [weak self] ... }` 弱闭包（第 8/38 轮既定模式）——红（原代码 1 failure）→绿（4/4）→全量 440 三跑实证未放宽断言**；440 用例实证（436 基线 + 新增 4）0 失败，任务预算零偏差；金丝雀三锚点 + WidgetLeakTests 27 全绿（原 23 + 新增 4）；零生产代码改动面外（仅泄漏修复 1 处）
- **锚点巡检收口复跑接入保持**：scripts/anchor-patrol.py 收口复跑接入（第 29 轮 B 卡固化）连续第十三轮保持——第 39 轮收口后复跑 PASS 72 / WARN 11 / INFO 5 / ERROR 0 退出码 0，与第 38 轮收口基线逐项一致零新漂移，机器检查零回归
- **工程版本号对齐**：Info.plist 0.38/463 → 0.39/464（第 39 轮收口落地，B 卡版本决策建议收口采纳、README v0.39 条目对齐，营销版本号与工程版本号对齐惯例延续）

### v0.39

> 承接第 38 轮：WidgetLeakTests 泄漏契约覆盖面扩展（8→23 类全覆盖，新增 15 用例——TBPausableTimer 弱闭包 11 + DispatchSourceTimer 1 + 直接 Timer 3；发现并根因修复真实泄漏 1 处——PomodoroBarItem.swift:87 setEventHandler 强捕获 self 保留环→弱闭包，红→绿双跑实证未放宽断言；436 用例实证 0 失败）、锚点巡检收口复跑接入保持（第 29 轮落地后连续第十一轮 0 ERROR），并完成工程版本号对齐（Info.plist 0.37/462 → 0.38/463）。

#### 工程与稳定性

- **WidgetLeakTests 泄漏契约覆盖面扩展（timer 类 widget 防回归网络密，内存修复主线续篇）**：泄漏契约测试 8 → 23 类全覆盖，新增 15 用例（同一文件追加，沿用 autoreleasepool + weak var + letRunLoopSpin + XCTAssertNil 模式）——TBPausableTimer 弱闭包模式 11（UsageBarItem / StockBarItem（双 timer）/ ClipboardHistory / PlaybackProgressBarItem / MusicBarItem / AudioSpectrumBarItem / DeepseekBalanceBarItem / OpenCodeGoUsageBarItem / ExpenseTracker / TimestampConvert / BrightnessViewController）+ DispatchSourceTimer 1（PomodoroBarItem）+ 直接 Timer 3（ReadTimer / BreathingGuide / StandupTimer）；构造无副作用策略（空 providers/symbols 免网络、假 key/假 workspace 免真实密钥、NoScriptingMusicItem / NoCaptureSpectrumItem 子类避开 ScriptingBridge 与 SCK/mic 硬件）；**发现并根因修复真实泄漏 1 处——PomodoroBarItem.swift:87 `setEventHandler(handler: tick)` 方法引用强捕获 self，形成 item → timer → handler → item 保留环（运行中的番茄钟永远无法回收，deinit cancel 永不被执行），改为 `{ [weak self] in self?.tick() }` 弱闭包（第 8 轮既定模式）——红→绿双跑实证未放宽断言**；436 用例实证（421 基线 + 新增 15）0 失败，任务预算零偏差；零生产代码改动面外（仅泄漏修复 1 处），金丝雀三锚点 + WidgetLeakTests 23 全绿
- **锚点巡检收口复跑接入保持**：scripts/anchor-patrol.py 收口复跑接入（第 29 轮 B 卡固化）连续第十一轮保持——第 38 轮收口后复跑 PASS 72 / WARN 11 / INFO 5 / ERROR 0 退出码 0，与第 37 轮收口基线逐项一致零新漂移，机器检查零回归
- **工程版本号对齐**：Info.plist 0.37/462 → 0.38/463（第 38 轮收口落地，B 卡版本决策建议收口采纳、README v0.38 条目对齐，营销版本号与工程版本号对齐惯例延续）

### v0.38

> 承接第 37 轮：保留 5 类非注册分支 switch 路径契约测试补齐（staticButton/group/expandable/themeSwitch 4 类 8 用例，契约测试 165→173、键集 93 键零改动，穷尽性兜底从编译期保证升级为运行时行为断言）、锚点巡检收口复跑接入保持（第 29 轮落地后连续第九轮 0 ERROR），并完成工程版本号对齐（Info.plist 0.36/461 → 0.37/462）。

#### 工程与稳定性

- **保留 5 类非注册分支 switch 路径契约测试补齐（穷尽性兜底运行时断言化）**：TECHDEBT ② 续篇八——保留 5 类（staticButton/group/expandable/themeSwitch/audioSpectrum，ItemsParsing.swift:1108/:1174/:1178/:1240/:1258）中尚无 switch 路径契约覆盖的 4 类补齐（audioSpectrum 已有回退锚点用例不重复）：ItemTypeDecodeRegistryTests.swift 165 → 173 用例（手写独立文件，不并入生成文件 RegistryReconciliationTests.swift）——staticButton title 必填透传 + 缺失 title 降级 unknown / group items 嵌套 [BarItemDefinition] 递归解码（2 子项分别命中 switch 路径 staticButton 与注册表路径 cpu，验证两级解码在嵌套上下文均生效）+ 缺失 items 降级 / expandable 最小 JSON 默认值断言（closePosition=="left"、cardWidthRatio==0.5）+ 显式值透传 / themeSwitch 缺省 themes==[] + 显式数组透传（含 label 缺省回退 preset 去扩展名、matchAppIds 可选两形态）；**键集断言保持 93 键零改动**（新增用例不改键集枚举，防迁移面悄然回退/无序扩张护栏原样保留）；**零生产代码改动**，编译期穷尽性安全网零损失；保留 5 类分支至此全部有 switch 路径契约钉住——穷尽性兜底从编译期保证升级为运行时行为断言，回退路径锚点体系完备；文档四处同步（internal-apis zh/en §2.3.2 用例数 165→173、ITEMS_REFERENCE 注册表注、TECHNICAL_DEBT 第 2 条，anchor-patrol.py 零改动——REG-2 范围锚点无位移）；**421 用例实证（413 基线 + 新增 8）0 失败**，金丝雀三锚点 + WidgetLeakTests 8 全绿，任务预算 421 用例/新增 8 零偏差
- **锚点巡检收口复跑接入保持**：scripts/anchor-patrol.py 收口复跑接入（第 29 轮 B 卡固化）连续第九轮保持——第 37 轮收口后复跑 PASS 72 / WARN 11 / INFO 5 / ERROR 0 退出码 0，与第 36 轮收口基线逐项一致零新漂移，机器检查零回归
- **工程版本号对齐**：Info.plist 0.36/461 → 0.37/462（第 37 轮收口落地，B 卡版本决策建议收口采纳、README v0.37 条目对齐，营销版本号与工程版本号对齐惯例延续）

### v0.37

> 承接第 36 轮：注册表混合架构 decode 迁移系列最终收官（base64Tool 换锚补迁、注册表键集 92→93、契约测试 163→165 用例、回退路径测试锚点换为 audioSpectrum、413 用例实证 0 失败）、锚点巡检收口复跑接入保持（第 29 轮落地后连续第八轮 0 ERROR），并完成工程版本号对齐（Info.plist 0.36/461）。

#### 工程与稳定性

- **注册表混合架构 decode 迁移系列最终收官（base64Tool 换锚补迁）**：TECHDEBT ② 续篇七——方案甲（换锚补迁）落地：base64Tool 迁入注册表（形态 A「全 decodeIfPresent + 默认值」单字段透传，闭包代码逐字节复制自 switch 分支仅末行 `self =` 改 `return`，程序化比对实证 tools/verify_round36_equiv.py 1/1 等价）；**新锚点选型 audioSpectrum**（保留 5 类中唯一含真实计算逻辑者——width→barCount 密度派生 `width > 0 ? max(8, min(48, Int(width/8))) : 16`，回退测试从简单透传升级为派生计算断言；排除 staticButton/group/expandable/themeSwitch 四排除表论证在案）；注册表键集 92→93，契约测试 163→165 用例（键集断言扩到实际 93 键 + base64Tool 默认值+显式值 2 用例），switch 98 分支中非注册保留 6→5（staticButton/group/expandable/themeSwitch/audioSpectrum），编译期穷尽性安全网零损失；**decode 迁移系列最终收官**——可迁分支全部迁完（93/98 迁入注册表），仅保留 5 类非注册分支为穷尽性兜底（均为语义保留，无新迁移候选）；RegistryReconciliationTests 6 用例零改动 + generate_registry_test.py 重跑 byte-identical（20046 bytes/98 entries，生成文件不在 git diff）；文档六处同步（internal-apis zh/en §2.3 行号 :1096-1494 + §2.3.2、ITEMS_REFERENCE :1701/:1709、TECHNICAL_DEBT 第 2 条、anchor-patrol REG-2 范围锚点），锚点巡检复跑 PASS 72/ERROR 0；413 用例实证（411 基线 + 新增 2）0 失败，金丝雀三锚点 + WidgetLeakTests 8 全绿，任务预算 413 用例/新增 2 零偏差
- **锚点巡检收口复跑接入保持**：scripts/anchor-patrol.py 收口复跑接入（第 29 轮 B 卡固化）连续第八轮保持——第 36 轮收口后复跑 PASS 72 / WARN 11 / INFO 5 / ERROR 0 退出码 0，与第 35 轮收口基线逐项一致零新漂移，机器检查零回归
- **工程版本号对齐**：Info.plist 0.35/460 → 0.36/461（第 36 轮收口落地，B 卡版本决策建议收口采纳、README v0.36 条目对齐，营销版本号与工程版本号对齐惯例延续）

### v0.36

> 承接第 35 轮：注册表混合架构 decode 迁移第六批·收官批完成（可迁未迁剩余 10 分支除回退锚点外全部迁移 9 类型、注册表键集 83→92、契约测试 145→163 用例、411 用例实证 0 失败）、锚点巡检收口复跑接入保持（第 29 轮落地后连续第七轮 0 ERROR）、PR #42 CI locale 修复并入，并完成工程版本号对齐（Info.plist 0.35/460）。

#### 工程与稳定性

- **注册表混合架构 decode 迁移第六批·收官批完成**：TECHDEBT ② 续篇六——可迁未迁剩余 10 分支除回退锚点外全部迁移 9 类型（全部形态 A「全 decodeIfPresent + 默认值」——pixelPet/homekitScene/aiSelectedText/rssUnread/citationGen/paperProgress/paperTags/bilibiliFeed/apiTester，低频繁/细分族按任务口径全部收尾）；闭包代码逐字节复制自 switch 分支零语义改写（程序化比对实证：tools/verify_round35_equiv.py 提取 9 闭包体与 switch 分支体逐语句 diff 9/9 等价）；注册表键集 83→92，契约测试 145→163 用例（键集断言扩到实际 92 键 + 逐类型等价性），switch 98 分支中 6 保留为穷尽性兜底（base64Tool + staticButton/group/expandable/themeSwitch/audioSpectrum），编译期穷尽性安全网零损失；**decode 迁移系列收官（除回退锚点）**——可迁分支全部迁完（92/98 迁入注册表），仅 base64Tool 保留未迁（switch 回退路径测试锚点，确定换锚方案前不迁，换锚后可按同一模板补迁 + 2 用例）；RegistryReconciliationTests 6 用例零改动 + generate_registry_test.py 重跑 byte-identical（98 entries 前后一致 sha256 一致，生成文件不在 git diff）；文档六处同步（internal-apis zh/en §2.3 行号 :1087-1485 + §2.3.2、ITEMS_REFERENCE :1701/:1709、TECHNICAL_DEBT 第 2 条、anchor-patrol REG-2 范围锚点），锚点巡检复跑 PASS 72/ERROR 0；411 用例实证（393 基线 + 新增 18）0 失败，金丝雀三锚点 + WidgetLeakTests 8 全绿，任务预算 411 用例/新增 18 零偏差
- **锚点巡检收口复跑接入保持**：scripts/anchor-patrol.py 收口复跑接入（第 29 轮 B 卡固化）连续第七轮保持——第 35 轮收口后复跑 PASS 72 / WARN 11 / INFO 5 / ERROR 0 退出码 0，与第 34 轮收口基线逐项一致零新漂移，机器检查零回归（PR #42 合并后重跑仍 0 ERROR）
- **PR #42 CI locale 测试确定性修复并入**：用户 PR #42（fix/ci-locale-test-determinism——权限提示文案测试钉定中文语言环境，仅 PausableTimerTests.swift +21 行，非新增用例）合入 main；收口前检测到 main 被并行推进，父分支先合并 origin/main（零冲突）后重跑整体实证 411 用例 0 失败（第 31 轮教训执行）
- **工程版本号对齐**：Info.plist 0.34/459 → 0.35/460（第 35 轮收口落地，B 卡版本决策建议收口采纳、README v0.35 条目对齐，营销版本号与工程版本号对齐惯例延续）

### v0.35

> 承接第 34 轮：注册表混合架构 decode 迁移第五批推进（可迁未迁剩余 30 分支按常用度再迁 20 类型、注册表键集 63→83、契约测试 109→145 用例、393 用例实证 0 失败）、锚点巡检收口复跑接入保持（第 29 轮落地后连续第六轮 0 ERROR），并完成工程版本号对齐（Info.plist 0.34/459）。

#### 工程与稳定性

- **注册表混合架构 decode 迁移第五批推进**：TECHDEBT ② 续篇五——可迁未迁剩余 30 分支按常用度再迁 20 类型（形态 A「全 decodeIfPresent + 默认值」16——breathingGuide/postureReminder/travelCountdown/birthdayCountdown/holidayCountdown/classCountdown/ddlList/readingProgress/noteCapture/quickScreenshot/savingsGoal/taxEstimate/creditCardDue/ciPipeline/systemTemp/diskIO；形态 B「无参」4——billSplit/screenPicker/latexSymbols/finderTags，全部迁完）；闭包代码逐字节复制自 switch 分支零语义改写（程序化比对实证：tools/verify_round34_equiv.py 提取 20 闭包体与 switch 分支体逐语句 diff 20/20 等价）；注册表键集 63→83，契约测试 109→145 用例（键集断言扩到实际 83 键 + 逐类型等价性 + 回退路径用例 base64Tool 零改动——本轮未迁，switch 路径继续被钉），RegistryReconciliationTests 6 用例零改动 + generate_registry_test.py 重跑 byte-identical（生成文件不在 git diff）；文档六处同步（internal-apis zh/en §2.3 行号 :1043-1441 + §2.3.2、ITEMS_REFERENCE :1701/:1709、TECHNICAL_DEBT 第 2 条、anchor-patrol REG-2 范围锚点），锚点巡检复跑 PASS 72/ERROR 0；393 用例实证（357 基线 + 新增 36）0 失败，金丝雀三锚点 + WidgetLeakTests 8 全绿；可迁未迁剩余 10 分支登记后续轮次候选（base64Tool 建议在确定换锚前保持未迁）
- **锚点巡检收口复跑接入保持**：scripts/anchor-patrol.py 收口复跑接入（第 29 轮 B 卡固化）连续第六轮保持——第 34 轮收口后复跑 PASS 72 / WARN 11 / INFO 5 / ERROR 0 退出码 0，与第 33 轮收口基线逐项一致零新漂移，机器检查零回归
- **工程版本号对齐**：Info.plist 0.33/458 → 0.34/459（第 34 轮收口落地，随 v0.34 条目对齐，营销版本号与工程版本号对齐惯例延续）

### v0.34

> 承接第 33 轮：注册表混合架构 decode 迁移第四批推进（可迁未迁剩余 50 分支按常用度再迁 20 类型、注册表键集 43→63、契约测试 75→109 用例、357 用例实证 0 失败）、锚点巡检收口复跑接入保持（第 29 轮落地后连续第四轮 0 ERROR），并完成工程版本号对齐（Info.plist 0.33/458）。

#### 工程与稳定性

- **注册表混合架构 decode 迁移第四批推进**：TECHDEBT ② 续篇四——可迁未迁剩余 50 分支按常用度再迁 20 类型（形态 A「全 decodeIfPresent + 默认值」14——noiseMeter/expenseTracker/subscriptionCountdown/dailyQuote/emailBadge/meetingCountdown/slackUnread/printerStatus/standupTimer/clipboardHistory/wordLookup/dockerStatus/serverMonitor/opencodeGoUsage；形态 B「无参」6——regexTester/colorConvert/regexReference/screenLock/bluetoothToggle/shortcutHints）；闭包代码逐字节复制自 switch 分支零语义改写（程序化比对实证：python 提取 20 闭包体与 switch 分支体逐语句 diff 20/20 等价）；注册表键集 43→63，契约测试 75→109 用例（键集断言扩到实际 63 键 + 逐类型等价性 + 回退路径用例 base64Tool 零改动——本轮未迁，switch 路径继续被钉），RegistryReconciliationTests 6 用例零改动 + generate_registry_test.py 重跑 byte-identical（生成文件不在 git diff）；文档六处同步（internal-apis zh/en §2.3 行号 :955-1353 + §2.3.2、ITEMS_REFERENCE :1701/:1709、TECHNICAL_DEBT 第 2 条、anchor-patrol REG-2 范围锚点），锚点巡检复跑 PASS 72/ERROR 0；357 用例实证（323 基线 + 新增 34）0 失败，金丝雀三锚点 + WidgetLeakTests 8 全绿；可迁未迁剩余 30 分支登记后续轮次候选（base64Tool 建议在确定换锚前保持未迁）
- **锚点巡检收口复跑接入保持**：scripts/anchor-patrol.py 收口复跑接入（第 29 轮 B 卡固化）连续第四轮保持——第 33 轮收口后复跑 PASS 72 / WARN 11 / INFO 5 / ERROR 0 退出码 0，与第 32 轮收口基线逐项一致零新漂移，机器检查零回归
- **工程版本号对齐**：Info.plist 0.32/457 → 0.33/458（第 33 轮收口落地，随 v0.33 条目对齐，营销版本号与工程版本号对齐惯例延续）

### v0.33

> 承接第 32 轮：注册表混合架构 decode 迁移第三批推进（可迁未迁 70 分支按常用度再迁 20 类型、注册表键集 23→43、契约测试 41→75 用例、323 用例实证 0 失败）、锚点巡检收口复跑接入保持（第 29 轮落地后连续第三轮 0 ERROR），并完成工程版本号对齐（Info.plist 0.32/457）。

#### 工程与稳定性

- **注册表混合架构 decode 迁移第三批推进**：TECHDEBT ② 续篇三——可迁未迁 70 分支按常用度再迁 20 类型（形态 A「全 decodeIfPresent + 默认值」14——dock/weather/yandexWeather/currency/playbackProgress/quickReply/gitStatus/apiLatency/sshStatus/portChecker/hashCalc/packageTracker/foodDelivery/weatherOutfit；形态 B「无参」6——dnd/jsonFormatter/timestampConvert/httpCodes/qrCode/readTimer）；闭包代码逐字节复制自 switch 分支零语义改写（程序化比对实证：python 提取 20 闭包体与 switch 分支体逐语句 diff 20/20 等价）；注册表键集 23→43，契约测试 41→75 用例（键集断言扩到实际 43 键 + 逐类型等价性 + 回退路径用例改写——原 dock 用例因 dock 迁入注册表，锚点改为 base64Tool，switch 路径继续被钉），RegistryReconciliationTests 6 用例零改动 + generate_registry_test.py 重跑 byte-identical（生成文件不在 git diff）；文档六处同步（internal-apis zh/en §2.3 行号 + §2.3.2、ITEMS_REFERENCE、TECHNICAL_DEBT 第 2 条、anchor-patrol REG-2 范围锚点），锚点巡检复跑 PASS 72/ERROR 0；323 用例实证（289 基线 + 新增 34）0 失败，金丝雀三锚点 + WidgetLeakTests 8 全绿；可迁未迁剩余 50 分支登记后续轮次候选
- **锚点巡检收口复跑接入保持**：scripts/anchor-patrol.py 收口复跑接入（第 29 轮 B 卡固化）连续第三轮保持——第 32 轮收口后复跑 PASS 72 / WARN 11 / INFO 5 / ERROR 0 退出码 0，与第 31 轮收口基线逐项一致零新漂移，机器检查零回归
- **工程版本号对齐**：Info.plist 0.31/456 → 0.32/457（第 32 轮收口落地，随 v0.32 条目对齐，营销版本号与工程版本号对齐惯例延续）

### v0.32

> 承接第 31 轮：注册表混合架构 decode 迁移扩大化（适配性分类全量 98 分支，迁入注册表 23 键、契约测试 7→41 用例、281 用例实证 0 失败）、用户问题卡 t_aeb0b769 权限弹窗零自动申请治理合并入 main（7 组件授权惰性化 + 8 用例，248 用例实证 + TCC 日志实证弹窗 0 次）、锚点巡检收口复跑接入保持（第 29 轮落地后连续第二轮 0 ERROR），并完成工程版本号对齐（Info.plist 0.31/456）。

#### 改进

- **权限弹窗零自动申请治理（用户问题修复 t_aeb0b769 合并入 main）**：根因三连（TCC 日志 + 代码双实证）——构建产物 ad-hoc 签名致每轮重建 cdhash 变化、TCC 视作全新应用授权回到 notDetermined（弹窗每轮重演）；测试宿主全量实例化 98 种 widget 中 7 种组件 init 即自动触碰受保护服务（单轮 27 次请求、3 次真实弹窗）；组件「init 即自动申请」本身不符合最小权限 UX。修复为权限惰性化（init 零自动 TCC，显式点按才申请）：天气 / Yandex 天气定位（`.notDetermined` 不再算可用，显示「点按定位/定位未授权」+ 点按申请/跳设置，didChangeAuthorization 授权后接续启动 + 补刷）/ 音频频谱麦克风授权门 + 录屏预检 + 点按按源分流 / 噪音计引擎授权门 / 出行、会议倒计时 init 删除自动 requestAccess / UpNext 播放源仅在已授权时刷新 + 「点按授权日历」提示项（顺带修复原 authorized 分支漏置 hasPermission 致组件恒空的潜在 bug）；`IUpNextSource` 协议新增 `requestAccessIfNeeded`（扩展默认 no-op）+ 内部注入点 6 处；PausableTimerTests Round 30 段 8 用例（计数子类模式），248 用例全量回归 0 失败 + TCC log stream 全程并行采集实证弹窗 0 次（修复前单轮 3 次），金丝雀三锚点 + WidgetLeakTests 8 全绿

#### 工程与稳定性

- **注册表混合架构 decode 迁移扩大化**：TECHDEBT ② 从试点推进为批量迁移——适配性分类全量 98 分支（迁入注册表 23：试点 3 + 本轮 20（形态 A「全 decodeIfPresent + 默认值」12 / 形态 B「无参」6 / 形态 C「必填字段抛错」2）；保留 switch 5 类及理由——staticButton（unknown 降级目标语义特殊）/ group+expandable（嵌套递归解码）/ themeSwitch（预注册重复键迁入零收益）/ audioSpectrum（派生计算逻辑）；可迁未迁 70 登记后续轮次候选）；闭包代码逐字节复制自 switch 分支零语义改写，switch 分支保留穷尽性兜底；注册表键集 3→23，契约测试 7→41 用例（键集断言扩到实际 23 键 + 三形态覆盖 + 回退路径改写 + 抛错降级保留），RegistryReconciliationTests 6 用例零改动 + generate_registry_test.py 重跑 byte-identical；文档五处同步（internal-apis zh/en §2.3 行号 + §2.3.2、ITEMS_REFERENCE、TECHNICAL_DEBT 第 2 条、anchor-patrol REG-2 范围锚点），锚点巡检复跑 PASS 72/ERROR 0；281 用例实证（247 基线 + 新增 34）0 失败，金丝雀三锚点 + WidgetLeakTests 8 全绿
- **锚点巡检收口复跑接入保持**：scripts/anchor-patrol.py 收口复跑接入（第 29 轮 B 卡固化）连续第二轮保持——第 31 轮 C 卡核验前复跑 + 收口后复跑均 PASS 72 / WARN 11 / INFO 5 / ERROR 0 退出码 0，与第 30 轮收口基线逐项一致零新漂移，机器检查零回归
- **工程版本号对齐**：Info.plist 0.30/455 → 0.31/456（第 31 轮收口落地，随 v0.31 条目对齐，营销版本号与工程版本号对齐惯例延续）

### v0.31

> 承接第 30 轮：注册表混合架构 decode 迁移试点落地（字典驱动解码注册表 + 迁移契约 7 单测）、锚点巡检脚本收口复跑接入固化（C 卡核验前 + 收口后双点接入），并完成工程版本号对齐（Info.plist 0.30/455）。

#### 工程与稳定性
- **注册表混合架构 decode 迁移试点落地**：TECHDEBT ② 从「维持暂缓」推进为「已落地试点」——`ItemType.registeredTypeDecoders` 字典驱动解码注册表（ItemsParsing.swift），cpu / battery / swipe 三类型从 decode switch 分支逐字节等价迁入（覆盖默认值 / 无参 / 必填抛错三参数形态），switch 分支保留使「新增类型必补分支」穷尽性安全网零损失；ItemTypeDecodeRegistryTests 7 用例迁移契约（注册表键集 / 等价性 / 回退路径 / 抛错降级），247 用例整体实证 0 失败
- **锚点巡检脚本收口复跑接入固化**：scripts/anchor-patrol.py 接入收口检查清单双点——C 卡核验前复跑 + 合并后复跑；第 30 轮 C 卡首跑即机器捕获 StockBarItem +2 行漂移（8 ERROR，第三例「合并后未复查」，处置后复跑 PASS 72 / ERROR 0）——文档锚点漂移正式由逐轮人工抽查转为机器检查
- **工程版本号对齐**：Info.plist 0.29/454 → 0.30/455（第 30 轮收口落地，随 v0.30 条目对齐，营销版本号与工程版本号对齐惯例延续）

### v0.30

> 承接第 28~29 轮：恢复补刷即时性审计与补齐（隐藏→可见恢复侧统一治理，两基类恢复立即补刷 + 跑马灯恢复相位零空窗）、设置窗口闲置 GC 决策可测化（纯策略 + 9 单测）、文档锚点漂移巡检脚本落地，并完成年度维护核验第 22/23 次（含 114 口径锚点 +11 漂移处置）。

#### 改进
- **恢复补刷即时性审计与补齐**：隐藏→可见恢复侧全量接入点审计（grep 实证 25 文件 111 处 gate/timer 引用，24 接入点分类）——修复两基类（TBPollItem / TBMetricPopoverItem）可见期创建后隐藏再恢复需等待完整轮询周期才补刷的缺口：恢复分支一律改为立即周期补刷（首刷延迟上界 0）；跑马灯定时器恢复立即推进一帧（相位空窗 ≤3s → 0 帧），修复前 4 处缺口 → 修复后零残留

#### 工程与稳定性
- **设置窗口闲置 GC 决策可测化**：内存修复遗留④前半句闭环——设置窗口隐藏复用/闲置 GC 的「何时释放」决策逻辑提取为可单测纯策略 SettingsWindowGCStrategy（visible 守卫优先 / 内存压力短路 / 闲置阈值比较 + 调优常量 3600 单一来源），AppDelegate 接线层仅调用，可达状态空间逐字节等价零行为变更，9 单测覆盖全部决策点
- **文档锚点漂移巡检脚本落地**：scripts/anchor-patrol.py 88 项锚点数据驱动巡检清单（114 口径 / 6 注册点 / 金丝雀 / ITER-14 待办 / maintenance-notes / iteration-plan 审查证据表，live 73 + record 15 两级语义）+ 用法文档 docs/anchor-patrol.md——把「锚点漂移」从逐轮人工抽查变为收口可复跑的机器检查
- **年度维护核验第 22/23 次**：2027 段 32 日期断言 + 金丝雀 7/7 + 文档一致性三方交叉核对与遗留逐项盘点；第 22 次发现并处置 114 口径锚点 +11 行号漂移（ITEMS_REFERENCE :1709 同步，第 24/28 轮同族「合并后未复查」先例）

### v0.29

> 承接第 24~27 轮：隐藏期零空转治理收官审计（5 项真遗漏修复 + 后台调度零网络实证收口）、注册表混合架构对账测试与流程文档化、时序敏感测试健壮化、全局隐藏态与失焦定位语义修正，并完成工程版本号首次对齐。

#### 改进
- **隐藏期零空转收官审计（5 项真遗漏修复）**：全库活跃源覆盖审计发现并修复 5 项遗漏——NoiseMeter 麦克风采集链隐藏期零采集（AVAudioEngine tap 随隐藏启停、隐私指示灯熄灭）/ ShellScript、AppleScript 脚本自循环隐藏期停止执行 / 歌词跑马灯 60fps timer 隐藏期零滚动（LyricsTouchBarItem）/ NetworkBarItem netstat 常驻进程隐藏期终止；恢复显示立即补刷，未隐藏时行为逐字节等价
- **后台调度隐藏期零网络实证收口**：4 个后台调度组件（汇率 / 天气 / Yandex / 日历）调度器门控 + 全部旁路入口独立 guard 复查——隐藏期零网络请求、零日历查询成立（第 22 轮挂账关闭）
- **空 bar 不再翻转全局隐藏态**：应用切换等系统事件下，空配置 bar 不再把全局隐藏态永久置位——「空 bar 从未上屏」与「用户隐藏了有内容的 bar」语义分离（有内容路径行为逐字节等价），同时从源头消除测试宿主下的状态污染链
- **失焦在途定位语义修正（区分 close-hide / resignKey）**：设置窗口失焦但窗口仍在屏时，进行中的定位添加操作继续完成（≤6.5s 用户主动有界操作）；真正隐藏（关闭 / 最小化 / Cmd+H）仍立即取消——隐私底线不破

#### 工程与稳定性
- **注册表混合架构对账测试**：新增 RegistryReconciliationTests 6 用例 + `generate_registry_test.py` 规范清单生成脚本——枚举 / 解码 / identifierBase / 工厂 / 预定义注册表 / 控制器注册六处注册链建立代码级对账，新增 widget 漏改任意一处即测试失败；生产最小增量（`CaseIterable` + 注册表键只读快照）零行为变更
- **时序敏感测试健壮化**：修复 flaky 7 用例根因——测试宿主共享单例污染（NSWorkspace 事件 → 空 bar dismiss → 全局隐藏态永久置位 → 后续 widget 全部暂停）；纯测试侧修复（setUp 复位 + 时序断言健壮化），生产零改动，高负载复跑 0 失败
- **注册表对账机制流程文档化**：internal-apis zh/en §2.3 六处注册点 + ITEMS_REFERENCE 开发者指引段 + `generate_registry_test.py` 仓库根自定位（新增 widget 的开发流程落地为权威文档）
- **工程版本号对齐与版本史考古**：Info.plist 0.27/452 → 0.28/453（第 24 轮收口，营销版本号与工程版本号首次对齐）→ 0.29/454（第 28 轮收口，随 v0.29 条目对齐）；考古确认 v0.9~v0.26 从未以 Release / tag / Info.plist 任何形式存在（编号空洞），README 增版本史说明段如实记录

### v0.28

> 承接 v0.27 的隐藏机制主线：第 20~23 轮「隐藏期零空转」治理收官（8 个常驻定时器组件 + 4 个后台调度组件 + 音频采集链 + 定位服务全部纳入暂停），并强化隐藏期隐私保护与稳定性。

#### 改进
- **隐藏机制收官（零空转全覆盖）**：8 个常驻定时器组件（深色模式 / 夜览 / 时钟 / 亮度 / 剪贴板 / 音乐 / 播放进度 / 音频频谱）与 4 个后台调度组件（汇率 / 天气 / Yandex 天气 / 日历）在 Touch Bar 隐藏期间全部暂停——零轮询、零网络请求、零日历查询；恢复显示瞬间立即补刷最新数据
- **隐藏期隐私保护**：音频频谱采集链隐藏期间零采集（麦克风关闭、隐私指示灯熄灭）；天气组件定位服务隐藏期间暂停（GPS 关闭、隐私指示灯熄灭），恢复自动重启定位并补刷
- **全局隐藏态注入**：隐藏期间重建的组件初始即处于暂停态，初始数据请求零发送；恢复显示零延迟补刷
- **剪贴板查看即时对齐**：浮层打开瞬间即收录最新复制内容，消除「打开时最新条目还在轮询路上」的 ≤1s 陈旧窗口
- **天气定位添加城市生命周期治理**：设置中定位添加城市在解析完成 / 超时 / 窗口隐藏三条路径均停止定位，不再持续占用 GPS

#### 性能与稳定性
- **强引用环修复**：CPU 监控 / 天气组件点击动作与汇率 / 天气调度闭包的保留环修复——组件热重载后可正常释放，消除隐藏期泄漏及 GPS 持续活跃的放大器效应

### v0.27

> 自 v0.8（预发布）以来的迭代能力，均已随当前构建 0.27 提供。

#### 新增
- **节假日倒计时 widget（holidayCountdown）**：以 A 股交易日历的法定节假日表（`aShareHolidays`）为唯一数据源，展示距下一个假期首日的天数与假期名；假期窗口内显示「X 第 N 天」
- **应用专属主题（Per-app bar switching）**：为指定 App 绑定独立 Touch Bar 布局，切换应用自动换主题（对应 [issue #40](https://github.com/Tangzishun-Li/LyricsMTMR/issues/40)，用法见[使用指南](#应用专属主题per-app-bar-switching)）
- **货币汇率 widget（currency）**：Coinbase API 恢复启用，网络异常自动重试并降级显示

#### 改进
- **macOS 15.4+ 音乐信息获取**：mediaremote-adapter 子进程桥接方案解决私有框架权限封堵（机制与风险见上文）
- **隐藏机制完善**：组件按前台应用过滤补齐异步路径、matchAppId 正则编译缓存；黑名单 App 隐藏期间自动暂停全部 widget 轮询（零空转）
- **节假日名映射健壮化**：假期窗口按特征判定，跨年元旦 / 中秋国庆重叠窗口不再误判

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
- [x] 剪切板快捷查看（第 15 轮核对：已实现——BarItemFactory.swift:212 case .clipboardHistory 创建 ClipboardHistoryItem + ItemsParsing.swift:358 clipboardHistory 类型，详见验证报告_第15轮_barItemFactory提取.md）

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
