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

> **考古结论（2026-08-13 第 25 轮实证，详见《考古报告_第25轮_版本体系考古.md》】**：本项目正式发布记录仅 2 枚——v1.0.0（首个正式发行版，2026-07-29 发布）与 v0.8（预发布，2026-08-09 发布）；git tag 另有 1 枚内部快照（pre-opt-20260812-0114，非版本发布）。**v0.9 ~ v0.26 从未以 Release / tag / Info.plist 版本号任何形式存在过**——该区间是更新日志编号序列中的空洞：Info.plist 的 0.27/452 为 fork 自上游 MTMR（最高版本 v0.27.0）时继承的工程版本号，v1.0.0 / v0.8 两 tag 指向的提交中均为 0.27/452（营销版本号与工程版本号长期脱节），至第 24 轮收口（2026-08-13）方升为 0.28/453。更新日志自 v0.27 起按迭代轮次补记（v0.27=第 13~18 轮快照，v0.28=第 20~23 轮，v0.29=第 24~27 轮，v0.30=第 28~29 轮，v0.31=第 30 轮，v0.32=第 31 轮，v0.33=第 32 轮，v0.34=第 33 轮，v0.35=第 34 轮，v0.36=第 35 轮，v0.37=第 36 轮，v0.38=第 37 轮，v0.39=第 38 轮，v0.40=第 39 轮，v0.41=第 40 轮，v0.42=第 41 轮，v0.43=第 42 轮，v0.44=第 43 轮，v0.45=第 44 轮，v0.46=第 45 轮，v0.47=第 46 轮，v0.48=第 47 轮，v0.49=第 48 轮，v0.50=第 49 轮，v0.51=第 50 轮，v0.52=第 51 轮，v0.53=第 52 轮，v0.54=第 53 轮，v0.55=第 54 轮，v0.56=第 55 轮，v0.57=第 57 轮，v0.58=第 58 轮，v0.59=第 59 轮，v0.60=第 60 轮，v0.61=第 61 轮，v0.62=第 62 轮），此前条目为发布时实况。

### v0.62（当前开发版本）

> 承接第 62 轮：启动韧性与构建资源护栏 P0 应急轮（a 卡启动三档化+内存压力守卫、b 卡全机串行构建锁、d 卡构建内存优化调研）；金标准 6/6、全量回归 681 用例 0 失败、锚点巡检连续第四十三轮 0 ERROR。第 63 轮方向待定（候选见 docs/轮次速查.md）。

#### 新增

- **启动三档化与内存压力守卫（r62-a，commit 9bb61ec）**：applicationDidFinishLaunching 按 §4.1 契约收进新增 Core/StartupSequence.swift——MAIN_IMMEDIATE 四步（AX 权限检查→控制条 presence→reloadStandardConfig→statusItem/popover）原序不动保证 Touch Bar 与状态栏首帧就绪；MAIN_NEXT_TICK（歌词引擎启动/slots 目录/桌面歌词条件恢复）挪下个 runloop tick；BACKGROUND（HapticFeedback 全量设备扫描）转后台队列；调度器协议注入可离线单测，StartupSequenceTests 6 用例金标准（三档分区/相对顺序/BACKGROUND 无 UI 步骤）；新增 DISPATCH_SOURCE_TYPE_MEMORYPRESSURE CRITICAL 监听与 applicationDidMemoryWarning 共用抽出的 performCacheReclamation 清理链+os_log 一行，行为对外等价
- **全机串行构建锁脚本（r62-b，commit dd0a2c3）**：scripts/build-with-lock.sh + docs/构建资源护栏.md——一切 xcodebuild 必须经锁脚本排队过闸（macOS 无 flock(1) 采用 perl holder 进程方案全机互斥），等锁每 30s 提示，自动注入 -jobs ${MTMR_BUILD_JOBS:-4} 与 COMPILER_INDEX_STORE_ENABLE=NO（已含不重复加），退出码透传，bash 3.2 兼容；两进程并发实测互斥（总时长≈两者之和）
- **构建内存优化调研报告（r62-d，commit 4c8ebb0）**：docs/调研_R62_构建内存优化.md——实测矩阵 7 组（clean j2/j4/j8+noindex+增量/no-op 地板）：峰值随 -jobs 单调涨（j2 1273MB/j4≈1820MB/j8 1955MB 且 j8 双输最慢 57.9s）；swiftc 驱动自带 -c -j8 恒定不受 -jobs 约束为结构性下限（串行铁律必须坚持）；第三方缓存 sccache/XCRemoteCache 均不可用、Xcode 26 官方 CAS 为升级后首选前瞻；落地排序 P0 零成本三项（已在 b 卡落地）→P1 慢文件逐文件小卡→P2 DerivedData 卫生（19 份约 3.8GB）→P3 target 拆分/Xcode 26；附可复现测量脚本 scripts/measure_r62d.sh

#### 工程与稳定性

- **P0 根因定案与结构性修复**：轨道 §1 七条取证链实证「一开就卡死」＝多 worker 并发 xcodebuild test 挤爆 8GB 内存→换页风暴拖垮前台 app，非 R57–R60 减脂回归；修复＝并行的是开发、串行的是构建（§7 铁律），INTEG 自身三次构建+全量回归全程经锁脚本首战自证
- **全量回归用户点名里程碑触发**：UnitTests scheme 全量 **681 用例 0 失败 TEST SUCCEEDED**（104s 一次通过；675 基线+r62-a 新增 6 例；经锁脚本 -jobs 4 实证）
- **工程版本号对齐**：Info.plist 0.61/486 → 0.62/487（第 62 轮收口落地，INTEG 版本统一动作延续）

### v0.61

> 承接第 61 轮：SchemaBridge Phase2 三域收编（a 卡）+ 日历提醒展示态复核定案（b 卡）；受影响套件 35 用例 0 失败、全量回归到轮触发 675 用例 0 失败、锚点巡检连续第四十二轮 0 ERROR。第 62 轮方向待定（候选见 docs/轮次速查.md）。

#### 新增

- **智能家居/快递/健康三域 schema 化渲染（r61-a，commit 5ee81e1）**：SettingsSchema.domainFields 尾部追加 homekit(2 toggle)/package(3 toggle，notifyOnUpdate「默认关闭」副标题随迁)/wellness(readingGoal 5...100 步1 页每天 + standupMinutes 5...90 步1 分) 三域七键；Homekit/Package/Wellness 三 Tab 改造为 NotificationTab 同款结构（手写保留段+schema 渲染段），UD 读写走 SettingsFieldStore 闭包（wellness Int×Double 取整存取+水合钳制语义随迁）；落盘接线 SettingsRefreshAdvisor.notifyChange(domain:)，Advisor 零改动
- **SchemaDomainMigrationContractTests 契约锚点（r61-a）**：8 用例钉住三新键字段集合、EditorSchema 计数不变（运行时口径 278）、wellness 滑杆 range/step、三域 AppSettings 键名往返保真

#### 改进

- **日历提醒展示态复核定案（r61-b，commit 74092f0）**：remindEnabled/remindMinutes 「待 §5 审计复核」固化为「R61-b 复核定案：无落盘链路无 widget 行为（UpNextScrubberTouchBarItem.swift 全文无消费），维持内存暂存展示态，勿再重开复核」——bridge calendar 注册段与 CalendarTabView 内存暂存段同义互指注释；新增 CalendarReminderDisplayStateTests 三锚点（仍注册/缺省不变 true·15.0/storageKey nil 不落盘契约），纯固化零运行时行为变更

#### 工程与稳定性

- **INTEG 测试接线修正（commit f0ef8ce）**：domainFields 为 static let，localized() 文案进程内首触烤死——两新增套件单跑各自绿、合跑顺序下副标题断言必炸；修正为语言无关文案存在性校验（契约本质不受影响）
- **全量回归本轮触发（隔代规则：R59 触发→R60 跳过→R61 到轮）**：675 用例 0 失败 TEST SUCCEEDED
- **工程版本号对齐**：Info.plist 0.60/485 → 0.61/486（第 61 轮收口落地，INTEG 版本统一动作延续）

### v0.60

#### 新增

- **启动 TCC 弹窗防线（r60-a，commit ee70b1a）**：AppleScriptTCCGuard 守卫——引用外部应用（启发式 tell application 匹配且非本进程）的脚本在首次自动执行前显示占位「▶」，点按放行后恢复自循环；defaultPreset.json 清理 Spotify/Music/iTunes 三组 tell application 示例块；MusicSourceRow 对未安装应用显示灰字「未安装」徽标（预装后即生效，不禁用）
- **设置热更新与需刷新提示（r60-c，commit 8cd69ae）**：SettingsRefreshAdvisor 统一入口——能安全热更新的域（含 ≥0.5s 去抖合窗防闪屏）直接触发 reloadStandardConfig，不能的返回 false 由 Deck.RefreshBanner 横幅提示并提供「立即刷新」；Pomodoro/Stock/SystemMonitor/Calendar/General 五域接线
- **设置项对照表交付（r60-b，commit 294912c）**：docs/设置项对照表_R60.md——22 tab × 87 设置项逐条 文件:行号 级运行时证据，0 待核

#### 改进

- **死控件移除与 schema 注册推广（r60-b，commit 294912c）**：移除零读者零写者死控件 5 处（WeatherTab 预报小时数、ToolsTab 历史条数/默认哈希/默认布局/快捷回复）；domainFields 补注册 notification(3 toggle)/weather(5 键) 两域并 schema 化渲染（§4.4 试点，读者证据 PomodoroBarItem.swift:126,132 / WeatherBarItem.swift:71-92）；EditorSchema 152 条零触碰
- **General 黑名单缓存同步修复（r60-c 随带）**：blacklistAppIdentifiers 缓存不同步缺口——StatusBarMenuView.toggleBlacklist 三步骤链路复刻同步

#### 工程与稳定性

- **前序运行时缺陷修复（r60-a 随带）**：Range.map(String.init) 误将描述串当应用名返回、守卫放行时误清用户 actions 两处根因修复
- **锚点巡检收口复跑保持**：第 60 轮收口复跑 PASS 60 / WARN 23 / INFO 5 / ERROR 0 退出码 0（REGISTRY 197 行，新增本报告登记行）
- **工程版本号对齐**：Info.plist 0.59/484 → 0.60/485（第 60 轮收口落地，INTEG 版本统一动作延续）

### v0.59

#### 新增

- **契约分歧裁决落 UI（r59-a，commit 06d700b）**：Wellness 阅读目标滑杆单位「分/天」→「页/天」、范围 10...180→5...100（步长 10→1）、旧落盘值 >100 水合钳制防超程；站起提醒滑杆 5...30→5...90 分钟使契约缺省 45 可达；Package notifyOnUpdate 开关加「默认关闭」副标题——三处与轨道文本 R58 §5 契约逐字一致
- **桌面歌词窗口位置守护（r59-c，commit d08451a）**：歌词设置页桌面歌词区新增「重置窗口位置」行（清 frame 键+运行中窗口立即回主屏默认位）；DesktopLyricsFrameGuard 矩形相交判定（部分越界保留/完全在外或垃圾串回退 R51 默认位），启动恢复与屏幕变化通知共用同一判定；新增 DesktopLyricsFrameGuardTests 8 用例

#### 改进

- **SchemaBridge Phase2 推广两域（r59-b，commit b529797）**：domainFields 增 systemMonitor/calendar 各 6 字段；SystemMonitorTabView/CalendarTabView 显示段改 schema 驱动渲染——手写 @State+section 收敛为注册表驱动，防抖落盘/三值映射/日历 TOC 锚点跳转语义逐字保留；remindEnabled/remindMinutes 无运行时读者暂保留内存态注册待 §5 复核；EditorSchema 零改动

#### 工程与稳定性

- **全量回归触发（隔代规则）**：UnitTests scheme 全量 641 用例 0 断言失败；testTimerImmediateFireOnResume 计时敏感用例全量负载下偶发超时一次，单套件重跑 44/44 全绿复验（R26 健壮化遗产，非代码回归）
- **锚点巡检收口复跑保持**：第 59 轮收口复跑 PASS 60 / WARN 23 / INFO 5 / ERROR 0 退出码 0（REGISTRY 196 行，新增本报告登记行）
- **工程版本号对齐**：Info.plist 0.58/483 → 0.59/484（第 59 轮收口落地，INTEG 版本统一动作延续）

### v0.58

> 承接第 58 轮：UI 态持久化收尾（R57 审计遗留 G1~G5——Homekit/Package/Wellness/Lifestyle/AI 五页 12 键落盘）+ 记账 widget 消费闭环（G6 savings.json 四键消费 / G7 BeeCount 今日收支摘要）+ SchemaBridge Phase2 stock 域试点；受影响套件 16 用例 0 失败、锚点巡检连续第三十九轮 0 ERROR。第 59 轮方向待定（候选见 docs/轮次速查.md）。

#### 新增

- **UI 态持久化 G1~G5（r58-a commit 3f90a62 / r58-b commit 32f14d7）**：AppSettings 新增「UI State」两个 MARK 区段共 12 个 @UserDefault 键（键名契约冻结于轨道文本 §5）；Homekit/Package/Wellness 三 TabView init 水合+onChange 即时写回，LifestyleTabView 四开关+城市输入 saveDebounced 落盘，AITabView promptTemplates 选 [String] 整存整取接入防抖；缺键冷启动水合=契约默认值、plist 注入非默认值杀进程重启逐项保留双验证通过
- **记账 widget 消费闭环 G6/G7（r58-c，commit ce1e1cd）**：SavingsGoalItem 消费 savings.json 四键（monthlyBudget/savingsGoal/currency/overspendAlert）——进度条 savingsGoal 键优先、缺省回退既有 saved/goal 子树，月预算超支 ⚠ 前缀（overspendAlert=false 关闭），currency 后缀渲染（CNY→¥/USD→$/MOP 原样，缺省 ¥）；BeeCount 凭据可达时副行追加今日收支摘要（GET /api/read/day Bearer PAT，8s 超时），凭据缺失/网络失败一律静默回退原显示不拖垮记账；新增 ExpenseBudgetContractTests 5 用例
- **SchemaBridge Phase2 stock 域试点（r58-d，commit 555373a）**：SettingsSchemaBridge 注册 domainFields["stock"] 6 字段（与 StockBarItem 消费链键名一致），bridge 规则③首批控件扩展 .slider/.segmented + Store 可选 string 通道；StockTabView 显示段改 schema 驱动渲染（防抖写盘/切主题重水合/add 默认值语义保持），EditorSchema 零改动（97 类型/152 属性不变）

#### 工程与稳定性

- **锚点巡检收口复跑保持**：第 58 轮收口复跑 PASS 60 / WARN 23 / INFO 5 / ERROR 0 退出码 0（REGISTRY 195 行）；W3 补链带出 record 级位移 7 处按惯例修正登记（h 卡重写 TBMWC 致 IP-149a/b·IP-169·IP-202a/b 移位、j 卡摘 archive 段致 IP-327/IP-375 行号 -1）
- **工程版本号对齐**：Info.plist 0.57/482 → 0.58/483（第 58 轮收口落地，INTEG 版本统一动作延续）

### v0.57

> 承接第 57 轮：设置体系统一治理（双波 INTEG——第一波设置 UX 4 卡：A 死设置审计接线/B SettingsSchemaBridge 共享层+C 侧栏信息架构重排/D 设置⇄编辑器双向跳转；第二波性能减脂 3 卡：E 时钟精度分档/F popover 停表/G 歌词动画可见性守卫；受影响套件 184 用例 0 失败、锚点巡检连续第三十八轮 0 ERROR）。第 58 轮方向待定。

#### 新增

- **死设置审计与接线（r57-a，commit de2ca35）**：全量 grep 审计 AppSettings 全部 38 个 @UserDefault 键 × 21 个 TabView 的读写闭环——notificationsSound 按 §5 规则1 接线（PomodoroBarItem.sendNotification 补读，content.sound 由开关控制）；notificationsPackage/DDL/Birthday 无生产者走规则2（NotificationTabView 隐藏三开关 + AppSettings 标 deprecated 注释保留键）；rssRSSHubBase 复核降级 F2 误报（resolvedURL(base:) 消费链实证活键）；产出 logs/第57轮/R57_死设置审计清单.md（38 键处置表+各 tab 非 UD 通道审计）+ DeadSettingContractTests 5 用例 + scripts/audit_ud_keys.py
- **SettingsSchemaBridge 共享层与 pomodoro schema 驱动试点（r57-b，commit 82d0af8）**：新建 Preferences/Components/SettingsSchemaBridge.swift（§6 冻结三签名转发 EditorSchema + SettingsField/Store/Model/SectionCard 扩展层，头注释含 Phase2 批量迁移路径）；PomodoroTabView 改 schema 驱动渲染（时长防抖写盘三连行为不变）；5 个零运行时读者死装饰控件移除（longRestMinutes/longRestInterval/autoNext/soundEnabled/dailyGoal）；notificationsPomodoro 补 live 字段（消费者 PomodoroBarItem.swift:126）
- **设置⇄编辑器双向跳转（r57-d，commit 550b5cf）**：设置→编辑器「在编辑器中打开…」菜单（枚举 items.json 顶层 item，type/index 经冻结通知定位选中，三层时序兜底）；编辑器→设置 inspector 头部「域设置…」按钮（14 个域 tab 映射）；契约 Notification.Name 与 userInfo 字段级符合 §6（settingsNavigateToItem / editorRequestOpenSettings）
- **TimeTouchBarItem 模板精度分档（r57-e，commit c0528cd）**：新增 refreshInterval(for:)（模板含 S/ss→1s 否则 30s），init 接线分档 cadence 与 tolerance（1s 档 0.1 / 30s 档 5），分钟格式时钟刷新开销 1s→30s；新增 TimeTouchBarItemPrecisionTests 7 用例
- **TBPopoverItem overlayDidDismiss 生命周期钩子（r57-f，commit 7636b08）**：TBPopoverItem 新增空默认 dismissOverlay 钩子，浮层关闭即停表——BreathingGuideItem(20Hz)/StandupTimerItem(0.5s)/ReadTimerItem(1s) 三循环 timer 子类 override 离屏停转置 nil，离屏空转泄漏清零；reloadPreset 异常未重建不再泄漏会话；新增 PopoverLifecycleTests 7 用例
- **桌面歌词动画定时器可见性守卫（r57-g，commit 6b8cc6b）**：KaraokeLabel.setProgressAnimation 入口可见性守卫（window 不可见记 pending 不启动，flushPendingProgressIfNeeded 补启动）+ marquee Timer 创建前 isVisible 竞态复查 + show/hide 接 windowVisibilityDidChange 冻结/续播；新增 KaraokeVisibilityTests 7 用例

#### 改进

- **侧栏信息架构重排（r57-c，commit 9354463）**：SettingsGroup 5 组 22 平铺收敛为常用(6)/数据(5)/更多设置(10, 默认折叠) 3 组 + About 组外一级；searchKeywords 取消 default 盲区 22 tab 全覆盖；折叠组选中自动展开保可达；纯导航重排 22 个 *TabView 文件级零改动

#### 工程与稳定性

- **锚点巡检收口复跑接入保持**：scripts/anchor-patrol.py 收口复跑接入（第 29 轮 B 卡固化）连续第三十八轮保持——第 57 轮收口后复跑 PASS 67 / WARN 16 / INFO 5 / ERROR 0 退出码 0（REGISTRY 194 行；IP-151 examples/presets/items.json 路径随 presets 目录迁移同步 LyricsMTMR/MTMR/presets/items.json），机器检查零回归
- **工程版本号对齐**：Info.plist 0.56/481 → 0.57/482（第 57 轮收口落地，INTEG 版本统一动作，营销版本号与工程版本号对齐惯例延续）

### v0.56

> 承接第 55 轮：桌面歌词独立配色开关·UI维度（R51 遗留候选——AppSettings 新增 3 键 + hex 编解码 + resolveDesktopTextColor/ProgressColor + applyColors() + Toggle + Swatches + 8 用例 contract tests；561 用例 0 失败实证、锚点巡检连续第三十六轮 0 ERROR）。第 56 轮 A 卡方向待定。

#### 新增

- **桌面歌词独立配色开关（UI 维度，R51 A 卡遗留候选）**：AppSettings 新增 3 键（`com.lyricsmtmr.desktopLyrics.useIndependentColors` 默认 false / `textColor` hex 默认 "" / `progressColor` hex 默认 ""）+ NSColor<->"#"RRGGBB" hex 编解码辅助；DesktopLyricsWindowController 新增 resolveDesktopTextColor / resolveDesktopProgressColor（独立配色开启时从 AppSettings hex 读取，否则 fallback LyricsItemConfig.shared）+ applyColors()（设置页切换/颜色变化时调用，含卡拉 OK 动画颜色同步）；LyricsTabView desktopLyricsSection 新增独立配色 ToggleRow + 两个 Deck.Swatches 颜色选择器（各 6 色预设）+ 收起/展开动画；新增 DesktopLyricsColorContractTests.swift 8 用例（toggle / fallback / persistence / hex roundtrip / 边界），UserDefaultsStore.override 注入内存 suite 隔离；编译 build-for-testing BUILD SUCCEEDED 零代码警告

#### 工程与稳定性

- **锚点巡检收口复跑接入保持**：scripts/anchor-patrol.py 收口复跑接入（第 29 轮 B 卡固化）连续第三十六轮保持——第 55 轮收口后复跑 PASS 67 / WARN 16 / INFO 5 / ERROR 0 退出码 0（REGISTRY 190 行），机器检查零回归
- **工程版本号对齐**：Info.plist 0.54/479 → 0.55/480（第 55 轮收口落地，B 卡版本决策建议收口采纳、README v0.55 条目对齐，营销版本号与工程版本号对齐惯例延续）

### v0.55

> 承接第 54 轮：构建性能分析与编译优化·代码质量维度（自主选题——clean build 48s / incremental 7.6~22.4s / SwiftUI 类型检查 56.3s 瓶颈定位 / 编译选项已最优 / archive/ 死代码 1,246 行可清理；561 用例 0 失败实证、锚点巡检连续第三十五轮 0 ERROR）。第 55 轮 A 卡「桌面歌词独立配色开关」进行中（UI 维度——R48 后隔 7 轮，R51 A 卡遗留候选；基线 561 用例，预计新增契约单测 +3 用例，细节以 A 卡收口记录为准）。

#### 工程与稳定性

- **构建性能分析与编译优化（代码质量维度，自主选题）**：构建时间分析——clean build 48s（arm64 Debug）、incremental 叶文件 7.6s、incremental 核心文件 22.4s；SwiftUI 类型检查总耗时 56.3s（54,080 表达式），并行化后墙钟约 42s；Top 5 慢文件（类型检查）：KeyBindingTabView 3.4s / RibbonEditorView 3.2s / EditorSchema 2.9s / UnifiedSettingsWindowController 1.9s / StatusBarMenuView 1.3s；最慢单表达式：BindingInspectorPanel._ body getter 1394ms / EditorSchema.items static let 1308+1287ms；编译选项检查——Debug `-Onone`+incremental+ENABLE_TESTABILITY=YES、Release `-O`+wholemodule、DEAD_CODE_STRIPPING=YES——全部已最优无需修改；增量构建效率评估——行为正确，不存在不必要的全量重编；Dead Code 评估——archive/ 目录存在 11 文件 1,246 行死代码（dead-functions 5 + duplicate-LyricsRendering 6），不在 pbxproj 中不参与编译可安全清理；561 用例实证 0 失败；项目构建配置已处于最优状态，主要耗时在 SwiftUI 类型检查（框架固有特性）
- **锚点巡检收口复跑接入保持**：scripts/anchor-patrol.py 收口复跑接入（第 29 轮 B 卡固化）连续第三十五轮保持——第 54 轮收口后复跑 PASS 67 / WARN 16 / INFO 5 / ERROR 0 退出码 0（REGISTRY 186 行），机器检查零回归
- **工程版本号对齐**：Info.plist 0.53/478 → 0.54/479（第 54 轮收口落地，B 卡版本决策建议收口采纳、README v0.54 条目对齐，营销版本号与工程版本号对齐惯例延续）

### v0.54

> 承接第 53 轮：R47 观察项双项治理——数据存储维度（数据与存储维度，接 R47 A 卡登记 3 项中 2 项：lyricsSelectionCache 随 reset 清空隔离——SettingsSync 新增 runtimeCacheKeys 排除列表 resetAllToDefaults/exportProfile 跳过运行时缓存键，大契约不变；selectedThemeIndex 缺键默认 0 既有语义契约化——新增 3 契约单测 6→9 用例正/反断言钉住缺键=0 语义）、549 用例 0 失败实证、锚点巡检连续第三十三轮 0 ERROR，并完成工程版本号对齐（Info.plist 0.53/478 → 0.54/479）。第 54 轮 A 卡方向待定。

#### 工程与稳定性

- **R47 观察项双项治理（数据存储维度）**：承接 R47 A 卡登记 3 项延续中 2 项——①lyricsSelectionCache 随 reset 清空隔离（SettingsSync.swift 新增 runtimeCacheKeys 排除列表 + resetAllToDefaults/exportProfile 过滤条件 + UDKey 新增 lyricsSelectionCache 键 + LyricsSelectionCache.swift 字面量→UDKey 引用）+ ③selectedThemeIndex 缺键默认 0 契约化（UserDefaultsContractTests.swift 新增 testSelectedThemeIndexMissingKeyDefaultsToZero 正/反断言 + testResetAllToDefaultsKeepsLyricsSelectionCache + testExportProfileExcludesLyricsSelectionCache 共 3 用例，6→9）；受影响套件+金丝雀 118 用例 0 失败；全量 549 用例实证 0 失败（533 基线+13 R52 marquee+3 新增零偏差，101.2s）
- **锚点巡检收口复跑接入保持**：scripts/anchor-patrol.py 收口复跑接入（第 29 轮 B 卡固化）连续第三十三轮保持——第 53 轮收口后复跑 PASS 67 / WARN 16 / INFO 5 / ERROR 0 退出码 0（REGISTRY 184 行），机器检查零回归
- **工程版本号对齐**：Info.plist 0.53/478 → 0.54/479（第 53 轮收口落地，B 卡版本决策建议收口采纳、README v0.54 条目对齐，营销版本号与工程版本号对齐惯例延续）

### v0.53

> 承接第 52 轮：桌面歌词窗口长行 marquee（前端体验/UI 维度续面——R51 A 卡遗留 4 项第 1 项「桌面长行截断无 marquee」候选闭环，接 R51 收口基线 533=513+20：长行检测 + 横向滚动——有 timetag 卡拉 OK 行 follow 跟随（正在演唱字保持可视区 65%，NSAnimationContext 动画，不建 timer）+ 无 timetag 长行循环 marquee 30fps timer（OPT-5 ② 同行复用守卫）+ 纯逻辑抽 DesktopLyricsMarquee 枚举 5 纯函数（needsMarquee/overflowWidth/nextLineTimeBudget/marqueeOffset/followOffset）+ 新增长行滚动开关 com.lyricsmtmr.desktopLyrics.marqueeEnabled（默认 true）+ DesktopLyricsMarqueeTests 13 用例红→绿双跑 + 受影响套件+金丝雀 109 用例 0 失败——详见《验证报告_第52轮_桌面歌词窗口长行marquee.md》）、锚点巡检收口复跑接入保持（连续第三十二轮 0 ERROR），并完成工程版本号对齐（Info.plist 0.51/476 → 0.52/477）。第 53 轮 A 卡「R47 观察项双项治理」进行中（数据与存储维度——R47 后隔 5 轮，接 R47 观察项 2 项：lyricsSelectionCache 随 reset 清空隔离 + selectedThemeIndex 缺键默认 0 既有语义契约化，细节以 A 卡收口记录为准）。

#### 新增

- **桌面歌词窗口长行 marquee（前端体验/UI 维度续面，R51 A 卡遗留第 1 项闭环）**：新增 MTMR/Core/DesktopLyricsWindowController.swift 纯逻辑枚举 `DesktopLyricsMarquee` 5 纯函数——needsMarquee（长行判定：textWidth > availableWidth）/overflowWidth（行程 = textWidth − availableWidth + padding，下限 0）/nextLineTimeBudget（预算 = 下一行位置 − 当前播放时刻，无下一行默认 4s 下限 1s）/marqueeOffset（(elapsed mod budget)/budget × overflow，预算到点回绕）/followOffset（target = charX − clipWidth×0.65，夹在 [0, overflowWidth]）；滚动驱动按行决策——有 timetag 卡拉 OK 行 → **follow 跟随**（正在演唱的字保持可视区 65% 位置，NSAnimationContext 动画 0.2s easeOut，不建 timer——D11 遗留「滚动与逐字高亮共用当前行标签」评估结论：bounds.origin.x 平移使卡拉 OK 高亮 clip 随文本同移不脱位）；无 timetag 长行 → **循环 marquee**（0→overflowWidth 线性推进，达预算回绕，30fps timer，OPT-5 ② 同行复用守卫：同一行仅刷新行程/预算不重建 timer）；生命周期接线（行切换 bounds.origin.x=0 归位从头渲染/隐藏/占位/开关关闭 resetMarquee 即停即归位/shutdown 清理）；bg.layer.masksToBounds=true 卡内裁剪（Touch Bar stackView.masksToBounds 同款职责）；AppSettings 新增 `com.lyricsmtmr.desktopLyrics.marqueeEnabled` 默认 true（R47 前缀结论）；设置页歌词 Tab 桌面歌词区新增「长行滚动」ToggleRow（不新增 SettingsTab case，开关即停即启）；30fps timer 仅「无 timetag 长行 + 窗口可见 + 开关开」条件性运行（R51 遗留评估结论）；新增 DesktopLyricsMarqueeTests 13 用例红→绿双跑（红态改公式 +1 偏移：13 tests 5 failures 精确失败线性×3+回绕×2 → 恢复 13/13 全绿，1 处边界断言修正非放宽：预算恰到期 truncatingRemainder 回绕是固有语义），受影响套件+金丝雀 109 用例 0 失败（Marquee 13/Window 20/PausableTimer 44/UserDefaults 6/PrivacyManifest 13/SecretsManager 13；全量回归 533 由第 52 轮承担）

#### 工程与稳定性

- **锚点巡检收口复跑接入保持**：scripts/anchor-patrol.py 收口复跑接入（第 29 轮 B 卡固化）连续第三十二轮保持——第 52 轮收口后复跑 PASS 67 / WARN 16 / INFO 5 / ERROR 0 退出码 0（REGISTRY 178 行=第 52 轮收口归档后实测口径），机器检查零回归
- **工程版本号对齐**：Info.plist 0.51/476 → 0.52/477（第 52 轮收口落地，B 卡版本决策建议收口采纳、README v0.52 条目对齐，营销版本号与工程版本号对齐惯例延续）

### v0.52

> 承接第 51 轮：桌面歌词窗口 MVP（歌词产品空白面补全——前端体验/UI 维度，R45 后隔 5 轮：NSPanel 非激活悬浮窗（透明+深色圆角底、可拖拽+单击隐藏）+ 三行竖排（前/后 1 行上下文 + 当前行 KaraokeLabel 卡拉 OK 逐字高亮）+ 占位三态（等待播放/已暂停/加载歌词）+ 位置记忆 + 设置歌词 Tab「桌面歌词」区（开关+字号滑块）+ 纯逻辑抽 3 组（LyricsKaraokeMapper 共享纯函数防公式漂移 / DesktopLyricsLayout / DesktopLyricsVisibility）+ 新增键全部带 com.lyricsmtmr.desktopLyrics. 前缀 + 新增 DesktopLyricsWindowTests 20 用例红→绿双跑 + 受影响套件+金丝雀 81 用例 0 失败——详见《验证报告_第51轮_桌面歌词窗口MVP.md》）、锚点巡检收口复跑接入保持（连续第三十一轮 0 ERROR），并完成工程版本号对齐（Info.plist 0.50/475 → 0.51/476）。第 52 轮 A 卡「桌面歌词窗口长行 marquee」进行中（前端体验/UI 维度续面——R51 遗留候选闭环，接 R51 收口基线 533=513+20 + DesktopLyricsWindowTests 20，细节以 A 卡收口记录为准）。

#### 新增

- **桌面歌词窗口 MVP（歌词产品空白面补全，前端体验/UI 维度）**：新增 MTMR/Core/DesktopLyricsWindowController.swift——NSPanel（.nonactivatingPanel 非激活悬浮窗，透明+深色圆角底，isMovableByWindowBackground 拖拽 + 单击隐藏）；三行竖排=前/后 1 行上下文 NSTextField（透明度 0.55）+ 当前行 KaraokeLabel 卡拉 OK 逐字高亮；占位三态（无曲目「♪ 等待播放…」/暂停「♪ 已暂停」/播放无歌词「♪ 加载歌词…」）；行切换守卫 lastAnimatedLineIndex/ClickAction/LyricsId 每行仅重建 keyframes 一次，播放/暂停状态迁移冻结/解冻扫描；位置记忆=用户拖拽落盘 com.lyricsmtmr.desktopLyrics.frame（程序化 setFrame 不覆盖，屏幕变化回主屏底部居中默认位）；纯逻辑抽 3 组——LyricsKaraokeMapper（卡拉 OK 进度映射共享纯函数，LyricsEngine.updateKaraokeProgress 改调同一公式防两侧漂移）/DesktopLyricsLayout（三行上下文+占位决策）/DesktopLyricsVisibility（可见性状态机）；AppSettings 新增 3 键全部带 com.lyricsmtmr.desktopLyrics. 前缀（R47 结论）；设置页歌词 Tab 新增「桌面歌词」区（开关 ToggleRow + 字号滑块 12~40 实时 applyFontSize），字体族/文字色/进度色复用 LyricsItemConfig 同源；AppDelegate 接线（启动恢复显示 + applicationWillTerminate shutdown）；新增 DesktopLyricsWindowTests 20 用例红→绿双跑（红 7 failures→绿 20/20 断言零放宽），受影响套件+金丝雀 81 用例 0 失败（全量回归 533 由第 52 轮承担）

#### 工程与稳定性

- **锚点巡检收口复跑接入保持**：scripts/anchor-patrol.py 收口复跑接入（第 29 轮 B 卡固化）连续第三十一轮保持——第 51 轮收口后复跑 PASS 67 / WARN 16 / INFO 5 / ERROR 0 退出码 0（REGISTRY 176 行=第 51 轮收口归档后实测口径），机器检查零回归
- **工程版本号对齐**：Info.plist 0.50/475 → 0.51/476（第 51 轮收口落地，B 卡版本决策建议收口采纳、README v0.51 条目对齐，营销版本号与工程版本号对齐惯例延续）

### v0.51

> 承接第 50 轮：隐私清单补建与敏感数据面审计治理（安全与合规维度——R43 后隔 6 轮：全仓隐私 API 使用面盘点分类 6 类（UserDefaults 17 文件 / 剪贴板 6 / 定位 3 / 麦克风 2 / Keychain 2 / 网络 8+）；必申 3 项（UserDefaults→CA92.1 / FileTimestamp→C617.1 / ActiveKeyboard→3B52.1），SystemBootTime/DiskSpace 全仓 0 命中不声明（3 项疑似面逐一排除实证）；收集面诚实声明 2 项（Location / OtherUserContent，均 Linked=false/Tracking=false/AppFunctionality）；NSPrivacyTracking=false；PrivacyInfo.xcprivacy 补建 + pbxproj 四条目注册；敏感日志复检 29 处零泄漏（R43 结论保持）；PrivacyManifestContractTests 13 用例（红 1 失败→绿 13/13 断言零放宽）；513 用例实证 0 失败（101.0s））、锚点巡检收口复跑接入保持（连续第二十九轮 0 ERROR），并完成工程版本号对齐（Info.plist 0.49/474 → 0.50/475）。第 51 轮 A 卡「桌面歌词窗口 MVP」进行中（前端体验/UI 维度——歌词产品空白面补全，接 R50 收口基线 513，细节以 A 卡收口记录为准）。

#### 工程与稳定性

- **隐私清单补建与敏感数据面审计治理（安全与合规维度）**：承接 R43 SecretsManager（密钥存储治理）后隔 6 轮，补建项目缺失的 PrivacyInfo.xcprivacy 隐私清单（macOS 14+/Xcode 15 起合规面）——全仓隐私 API 使用面盘点分类 6 类（grep 实证：UserDefaults 17 文件 / 剪贴板 NSPasteboard 6 文件 / 定位 CLLocationManager 3 文件 / 麦克风 2 文件 / Keychain 2 文件 / 网络 URLSession 8+ 文件），对照 NSPrivacyAccessedAPITypes 必申项——**UserDefaults→CA92.1**（17 文件偏好读写）、**FileTimestamp→C617.1**（GitStatus.swift:402 attributesOfItem + ExpenseTracker.swift:72 modificationDate）、**ActiveKeyboard→3B52.1**（KeyBindingTabView.swift:1229 addLocalMonitorForEvents(.keyDown) 键绑定录制 + VirtualKeyboardView.swift:214 按键监视）；**SystemBootTime/DiskSpace 全仓 0 命中不声明**（KeyPress.swift CGEvent post 为合成输出非读取、RibbonEditor uptimeNanoseconds 为 ContinuousClock 单调钟、ServerMonitor uptime 为 SSH 远端字符串——三项疑似面逐一排除实证）；剪贴板/定位/麦克风/Keychain/网络非 required-reason API 不声明 API 类别；**收集面诚实声明 2 项**（NSPrivacyCollectedDataTypes，均 Linked=false/Tracking=false/AppFunctionality）：Location（天气定位坐标随请求出设备）、OtherUserContent（ClipboardHistory 本地持久化剪贴板内容）；麦克风仅内存实时处理不存储不传输故 AudioData 不声明；NSPrivacyTracking=false + NSPrivacyTrackingDomains=[]（无广告追踪 SDK）；PrivacyInfo.xcprivacy 补建落地（LyricsMTMR/MTMR/PrivacyInfo.xcprivacy，与 Info.plist 同组，pbxproj 四条目注册——PBXBuildFile/PBXFileReference/group child/Resources phase，add_files.py 同款确定性 sha1 UUID 方案）；敏感数据面复检（R43 续面）：全仓 print/NSLog 29 处逐一复检零密钥/token/密码/cookie 输出（R43 结论保持），风险点 YandexWeatherBarItem.swift:180 print(getWeatherUrl()) 仅坐标无密钥（R43 曾核 :177，行号后移 3 行内容不变），detectHardcodedKeys snippet 掩码在位；**新增契约测试 PrivacyManifestContractTests.swift 13 用例**（存在性 2 / 必申 API 3 精确 reason code / 收集面追踪 3 字段级 / 注册 1 四条目+防误入 Sources / 声明↔代码双向 3 防过度声明 / 反向锚定 1 SystemBootTime·DiskSpace 不得声明，#filePath 解析仓库相对路径直读 manifest/pbxproj/源码不触碰真实数据；红→绿双跑：红态临时移除 ActiveKeyboard 声明块 → 13 tests 1 failure（testActiveKeyboardCategoryDeclaredWith3B52 精确失败，其余 12 全绿）→ 恢复后 13/13 全绿，同一断言未放宽）；**513 用例实证（500 基线 + 新增 13 零偏差，101.0s）0 失败**（TEST SUCCEEDED，金丝雀 SecretsManagerContractTests 13/UserDefaultsContractTests 6/NetworkRobustnessContractTests 13/ThemeStateMachineContractTests 19/WriteSideContractTests 6 等随全量 0 失败）
- **锚点巡检收口复跑接入保持**：scripts/anchor-patrol.py 收口复跑接入（第 29 轮 B 卡固化）连续第二十九轮保持——第 50 轮收口后复跑 PASS 67 / WARN 16 / INFO 5 / ERROR 0 退出码 0（REGISTRY 172 行=报告归档 logs/ 按轮次分类后全量口径），机器检查零回归
- **工程版本号对齐**：Info.plist 0.49/474 → 0.50/475（第 50 轮收口落地，B 卡版本决策建议收口采纳、README v0.50 条目对齐，营销版本号与工程版本号对齐惯例延续）

### v0.50

> 承接第 49 轮：编译警告复检清零与工程规范治理（代码质量与工程规范维度——R41 后 8 轮累积复检：全量 build-for-testing 采集 3 条 warning: 行（1 代码警告 + 2 工具提示）与 R41 基线（10 代码警告 + 2 工具提示）逐条对比——新警告 1 条根因修复（NetworkRobustnessContractTests.swift:324 `??` 左侧非可选 String 死代码，TBMetricView.value 为非可选 String（WidgetKit.swift:121），去 ?? 行为等价断言未放宽；:326 疑似同型实测排除——subValue 为 String? 保持不动）+ R41 修复面 10 条代码警告零复发 + appintentsmetadataprocessor ×2 豁免复认；工程规范复检零新增（Swift 6 前瞻 Sendable 边界/deprecated API/测试断言卫生）；红→绿双跑 13/13 断言零放宽；500 用例实证 0 失败（R48 基线零偏差，101.5s））、锚点巡检收口复跑接入保持（连续第二十八轮 0 ERROR），并完成工程版本号对齐（Info.plist 0.48/473 → 0.49/474）。第 50 轮 A 卡「隐私清单补建与敏感数据面审计治理」进行中（安全与合规维度，R43 后隔 6 轮，基线 500+ 用例，预计新增契约单测 +1~5 用例，细节以 A 卡收口记录为准）。

#### 工程与稳定性

- **编译警告复检清零与工程规范治理（代码质量与工程规范维度）**：承接 R41 编译警告清零基线，R41 后 8 轮累积复检——全量 build-for-testing（caffeinate -i xcodebuild build-for-testing，先清旧 /tmp/LyricsMTMR-dd-* 防磁盘写满——第 22 轮教训）**TEST BUILD SUCCEEDED**，采集 3 条 `warning:` 行（1 代码警告 + 2 工具提示）与 R41 基线（10 代码警告 + 2 工具提示）逐条对比：**新警告 1 条** W-49-1（NetworkRobustnessContractTests.swift:324 `??` 左侧非可选 String——item.metric.value 为非可选 String（WidgetKit.swift:121 `var value: String = ""`），`?? ""` 右侧恒不可达死代码，第 45 轮断言同型化引入）**根因修复**：`(item.metric.value ?? "").contains("°")` → `item.metric.value.contains("°")`——非可选 String ?? 求值恒等于原值行为完全等价、断言未放宽（失败态主值仍不得含「°」）；:326 疑似同型实测排除（TBMetricView.subValue 为 String?（WidgetKit.swift:123），`?? ""` 有效兜底保持不动）；全仓 `?? ""` 扫描 100+ 处其余左侧均真可选（as? String/string(forKey:)/.first/.stringValue/字典下标）无一死代码，编译器全量零警告佐证；**R41 修复面 10 条代码警告零复发**（WeatherBarItem 插值 W-1~3/CoverCache Sendable 盒 W-4~5/onChange 迁移 W-6~8/authorized 死代码 W-9/defer 规范 W-10 全部在位）+ appintentsmetadataprocessor ×2 + xcodebuild destination ×1 按 R41 口径登记豁免复认；**工程规范复检零新增**（Swift 6 前瞻 Sendable 边界零新增（R41 CoverArtwork 盒后 8 轮零跨隔离发送非 Sendable 面）、deprecated API 零新增（R41 onChange/authorized 迁移后零弃用面）、测试断言卫生 1 处死代码清除）；**红→绿双跑**（红侧修复前 -only-testing NetworkRobustnessContractTests **13 tests 0 failures** 死代码在位原断言语义基线 → 绿侧修复后同命令 **13 tests 0 failures**，同一 `XCTAssertFalse(...contains("°"))` 断言保持仅去除恒不可达 ?? 分支，用例数 13 不变）断言零放宽；**500 用例实证（R48 基线零偏差，101.5s）0 失败**（TEST SUCCEEDED，全量日志 warning: 行仅 2 条均豁免提示、代码警告 0，金丝雀套件随全量 0 失败）
- **锚点巡检收口复跑接入保持**：scripts/anchor-patrol.py 收口复跑接入（第 29 轮 B 卡固化）连续第二十八轮保持——第 49 轮收口后复跑 PASS 67 / WARN 16 / INFO 5 / ERROR 0 退出码 0（改动文件 NetworkRobustnessContractTests.swift 非锚点文件无行号修正），机器检查零回归
- **工程版本号对齐**：Info.plist 0.48/473 → 0.49/474（第 49 轮收口落地，B 卡版本决策建议收口采纳、README v0.49 条目对齐，营销版本号与工程版本号对齐惯例延续）

### v0.49

> 承接第 48 轮：主题系统状态机一致性审计与治理（UI 迭代维度——承接 R47 A 卡登记遗留 selectedThemeIndex 语义观察项续面：全仓主题状态机 17 项盘点分类——合规不动 13 项（resolveAppThemeMode 纯函数既有覆盖 / setAutoSwitched 通知键对称 / revertAutoSwitch isAutoSwitched 守卫 / reloadPresetAsync 防抖被取代时序闭环 / 规则优先于冻结（分支序论证）/ ThemeSwitchBarItem 手动切换先标记再切换正确路径 / 观察者 deinit 移除 / selectedThemeIndex 缺键默认 0 复认——越界全部有守卫、cycleTheme 取模安全 / @UserDefault 存储 R47 已治理 / GeneralTabView 设置窗规则改动「下一次激活生效」论证 / 菜单规则路径立即 updateActiveApp / themeN 槽位索引约定 ThemeSupport 唯一真相源 / 缺文件自愈分支行为等价）+ 决策链抽取纯函数 2 处（resolveAppThemeTransition / resolveAppThemeSwitchDecision，行为零变化）+ 真实问题 3 项根因修复（手动覆盖守卫扩域 / reloadPreset 漏斗标记覆盖 / 覆盖后清 preAutoSwitchPresetPath 状态卫生））；新增 ThemeStateMachineContractTests 19 用例（transition 9 + decision 7 + ThemeSupport 索引约定 3，红→中间态 1 失败→绿 19/19 双跑实证未放宽断言）；500 用例实证 0 失败（481 基线 + 新增 19 零偏差，103.8s））、锚点巡检收口复跑接入保持（连续第二十七轮 0 ERROR），并完成工程版本号对齐（Info.plist 0.47/472 → 0.48/473）。第 49 轮 A 卡「编译警告复检清零与工程规范治理」进行中（代码质量与工程规范维度，接 R41 后 8 轮累积复检，细节以 A 卡收口记录为准）。

#### 工程与稳定性

- **主题系统状态机一致性审计与治理（UI 迭代维度）**：承接 R47 A 卡登记遗留（selectedThemeIndex 缺键默认 0 既有语义 + 无前缀键 3 处行为自洽 + lyricsSelectionCache 观察项）续面——全仓主题状态机 17 项盘点分类定案：**合规不动 13 项**（① resolveAppThemeMode 纯函数 6 用例既有覆盖；② setAutoSwitched 通知键对称；③ revertAutoSwitch isAutoSwitched 守卫；④ reloadPresetAsync 防抖被取代时序闭环；⑤ 规则优先于冻结（分支序论证）；⑥ ThemeSwitchBarItem 手动切换先标记再切换正确路径；⑦ 观察者 deinit 移除；⑧ selectedThemeIndex 缺键默认 0 复认——越界全部有守卫、cycleTheme 取模安全；⑨ @UserDefault 存储 R47 已治理；⑩ GeneralTabView 设置窗规则改动「下一次激活生效」论证——设置窗前台=本应用 bundleId 规则天然空转，与菜单路径立即生效同为场景自洽；⑪ 菜单规则路径立即 updateActiveApp；⑫ themeN 槽位索引约定 ThemeSupport 唯一真相源；⑬ 缺文件自愈分支行为等价）；**决策链抽取纯函数 2 处**（updateActiveApp 分支序 → resolveAppThemeTransition / handleAppThemeSwitch 内部决策 → resolveAppThemeSwitchDecision，行为零变化）；**真实问题根因修复 3 项**（① 手动覆盖守卫仅认 .onActivation——.always 应用下 themeSwitch 手动覆盖被同应用内任何重评估即时打回，守卫扩为 mode != .disabled && !appDidChange && userOverrode（.disabled 经 resolve 过滤不可达，判式保 totality）；② 手动重载不标记用户覆盖——reloadPreset 漏斗入口首行 markUserOverrideAppTheme()（本漏斗=用户/初始化触发，自动切换走 reloadPresetAsync 不受影响）；③ markUserOverrideAppTheme 遗留陈旧 preAutoSwitchPresetPath——覆盖分支追加置 nil，不变量「revert 目标仅在 isAutoSwitched 时有效」显式化）；新增契约测试 ThemeStateMachineContractTests.swift 19 用例（transition 9：黑名单优先/规则命中/disabled 回落/规则胜冻结/冻结 built 不重建/同应用快速路径零重建/应用切换重建/未 built 重建/nil 前台应用不走黑名单规则；decision 7：缺文件删规则/onActivation 覆盖尊重（既有）/.always 覆盖尊重（修复①红→绿）/应用切换覆盖过期/alreadyShowing 短路/新应用切换/disabled 全函数性回落；ThemeSupport 索引约定 3：themeN→N-1 换算/numericThemeSort/标签回退，红→中间态旧守卫 1 失败→绿 19/19 双跑断言零放宽，14 用例守卫既有行为 + 5 用例锚定治理产物）；**500 用例实证（481 基线 + 新增 19 零偏差，103.8s）0 失败**（TEST SUCCEEDED，金丝雀 AppThemeRulesTests 11/NetworkRobustnessContractTests/SecretsManagerContractTests 13/WriteSideContractTests 6/UserDefaultsContractTests 6 等随全量 0 失败）
- **锚点巡检收口复跑接入保持**：scripts/anchor-patrol.py 收口复跑接入（第 29 轮 B 卡固化）连续第二十七轮保持——第 48 轮收口后复跑 PASS 67 / WARN 16 / INFO 5 / ERROR 0 退出码 0（A 卡首跑 3 ERROR 系 TouchBarController 插入 ~100 行致 114 口径锚点与注册点行号漂移，按注册表机制更新登记后复跑退出码 0，内容在位语义零漂移）
- **工程版本号对齐**：Info.plist 0.47/472 → 0.48/473（第 48 轮收口落地，B 卡版本决策建议收口采纳、README v0.48 条目对齐，营销版本号与工程版本号对齐惯例延续）

### v0.48

> 承接第 47 轮：UserDefaults 持久化层审计与治理（数据与存储维度——接 R42/R43 技术债续面：全仓盘点 17 键组/15 文件（grep 实证 UserDefaults 命中 74 处，生产读写点约 50 处），逐键分类——合规不动 13 组（Apple 系统键 2：AppleInterfaceStyle/AppleLanguages 命名必须精确；无前缀键 3：postureReminderCycleStart/settings.sidebar.visible/group.expanded.* 行为自洽——逃逸 export/reset 属预期语义，改前缀引入重置清 UI 状态/导出夹带噪音回归，论证后不动；SecretsManager R43 决策门 useKeychain=false 双 DEVELOPMENT_TEAM ACL 风险保持；读写对称合规 7 组：@UserDefault 全量/StorageKey 12 键逐项对称/LyricsSelectionCache/ApiLatency/OpenCodeGo/TBSpectrumSettings/SettingsSync 命名空间过滤）；真实问题 5 项根因修复（TBSpectrumSettings.releaseKey 历史遗留死常量删除/AITabView 键字面量 ×4 收敛 UDKey 注册表/selectedThemeIndex 字面量 ×2 收敛 + 删 synchronize/synchronize() 过时调用 5 处全删/UserDefaultsStore.override 测试注入钩子落地——@UserDefault/SettingsSync export·import·reset/AITabView/selectedThemeIndex 统一路由，生产恒 nil 行为零变化）；新增 UserDefaultsContractTests 6 用例（红 10 errors 编译红→绿 6/6 双跑实证未放宽断言）；481 用例实证 0 失败（475 基线 + 新增 6 零偏差，101.9s））、锚点巡检收口复跑接入保持（连续第二十六轮 0 ERROR），并完成工程版本号对齐（Info.plist 0.46/471 → 0.47/472）。第 48 轮 A 卡「主题系统状态机一致性审计与治理」进行中（UI 迭代维度，接 R47 A卡 selectedThemeIndex 语义观察项，细节以 A 卡收口记录为准）。

#### 工程与稳定性

- **UserDefaults 持久化层审计与治理（数据与存储维度）**：承接 R42 注册表写入侧 encode / R43 SecretsManager 技术债续面——全仓盘点 17 键组/15 文件（grep 实证 UserDefaults 命中 74 处，生产读写点约 50 处），逐键分类定案：**合规不动 13 组**（① Apple 系统键 2：AppleInterfaceStyle/AppleLanguages 命名必须精确；② 无前缀键 3：postureReminderCycleStart/settings.sidebar.visible/group.expanded.* 行为自洽论证——逃逸 export/reset 属预期语义，改前缀引入重置清 UI 状态/导出夹带噪音回归，论证后不动；③ SecretsManager R43 决策门：useKeychain=false 双 DEVELOPMENT_TEAM 跨配置 ACL 风险保持；④ 读写对称合规 7 组：@UserDefault 全量/StorageKey 12 键逐项对称/LyricsSelectionCache/ApiLatency/OpenCodeGo/TBSpectrumSettings/SettingsSync 命名空间过滤）；**真实问题修复 5 项**：① TBSpectrumSettings.releaseKey 历史遗留死常量（全仓 0 读写，git log -S 实证自引入仅定义）删除；② AITabView 键字面量 ×4 散落收敛 UDKey 注册表（aiStreamOutput/aiShowBalance/themeSelectedIndex，防读写漂移）；③ selectedThemeIndex 字面量 ×2 收敛 UDKey + 删 synchronize；④ synchronize() 过时调用 5 处全删（AppSettings/SettingsSync×2/StatusBarMenuView/GeneralTabView——Apple 文档明示 unnecessary + wrapper 注释既有共识 + 语言切换重启由用户手动触发无时序依赖）；⑤ 新增 UserDefaultsStore.override 测试注入钩子（泛型 wrapper 不支持 static stored property 经非泛型容器中转，与 SecretsManager.defaultsOverride 同型），@UserDefault wrapper/SettingsSync export·import·reset/AITabView/selectedThemeIndex 统一路由 UserDefaultsStore.current——生产恒 nil 行为零变化；新增契约测试 UserDefaultsContractTests.swift 6 用例（命名空间导出排除无前缀键/重置清前缀保留无前缀/导入类型保真 Bool·Double·String/默认值语义 true·false·24·String/读写对称三型往返/UDKey 键稳定性锚定历史字面量，红 10 errors 编译红→绿 6/6 双跑实证未放宽断言）；**481 用例实证（475 基线 + 新增 6 零偏差，101.9s）0 失败**（TEST SUCCEEDED，金丝雀 NetworkRobustnessContractTests 13/SecretsManagerContractTests 13/WriteSideContractTests 6 等随全量 0 失败）
- **锚点巡检收口复跑接入保持**：scripts/anchor-patrol.py 收口复跑接入（第 29 轮 B 卡固化）连续第二十六轮保持——第 47 轮收口后复跑 PASS 67 / WARN 16 / INFO 5 / ERROR 0 退出码 0，与第 46 轮收口基线逐项一致零新漂移（改动文件 UserDefaultsContractTests.swift / AppSettings.swift 等均非锚点文件，锚点行号零漂移），机器检查零回归
- **工程版本号对齐**：Info.plist 0.46/471 → 0.47/472（第 47 轮收口落地，B 卡版本决策建议收口采纳、README v0.47 条目对齐，营销版本号与工程版本号对齐惯例延续）

### v0.47

> 承接第 46 轮：轮询链同步网络调用异步化评估与治理（后端服务维度——全仓盘点 20 处 / 13 消费文件（8 个轮询 widget compute() 同步调用 13 处 + 6 个用户触发工具 7 处）；评估结论「不值得全量异步化」（阻塞已由 R44 硬化全局有界、无主线程/跨 widget 冻结、基类轮询循环重写改动面大收益边际）；落地代表性试点——RssUnread direct 并行扇出（DispatchGroup 并发，N×11s 串行叠加 → ≤11s，失败面/求和语义零变化）；新增 NetworkRobustnessContractTests 4 用例（红 3 failures→绿 13/13 双跑实证未放宽断言）；475 用例实证 0 失败（471 基线 + 新增 4 零偏差））、锚点巡检收口复跑接入保持（连续第二十五轮 0 ERROR），并完成工程版本号对齐（Info.plist 0.45/470 → 0.46/471）。第 47 轮 A 卡「UserDefaults 持久化层审计与治理」进行中（接 R42/R43 技术债延续面：全仓 UserDefaults 使用 48 处/约 15 个文件，盘点分类 → 根因修复真实问题 → 契约测试 → 全量回归实证，细节以 A 卡收口记录为准）。

#### 工程与稳定性

- **轮询链同步网络调用异步化评估与治理（后端服务维度）**：承接 R44/R45 登记遗留「轮询链同步网络调用彻底异步化评估」——全仓盘点（grep 取证 20 处 / 13 消费文件）：8 个轮询 widget compute() 同步调用 13 处（RssUnread 5：direct 模式 N feed 循环 TBNet.get(10s) + provider 模式 feedly/inoreader/miniflux/googleReader 各 1 默认 8s；ApiLatency 2：get(5s)+directGet syncFetch(5s)；WeatherOutfit/DailyQuote/SlackUnread/BilibiliFeed/CiPipeline/PackageTracker 各 1）+ 6 个用户触发工具 7 处（WordLookup 2 / HomekitScene 2 / ApiTester 1 / AiSelectedText 1 / CitationGen 1，均先派发 global 队列再同步等待，UI 无冻结）；**影响面结构事实**（每 widget 独立串行队列，同步调用只拉长自身轮询节奏并冻结自身显示，不阻塞其他 widget 也不阻塞主线程；R44 硬化后每调用有 timeout+1s 上界；唯一线性放大面 = RssUnread direct 模式 N feed 串行叠加 N×11s）；**评估结论：不值得全量异步化**（① 阻塞已全局有界（R44 硬化，无无限停摆路径）；② 无全局/主线程阻塞，实际放大面仅 RssUnread direct N feed 串行叠加；③ 全量 async/await 需重写 TBPollItem 基类轮询循环（~40 子类共享）+ 迁移 20 调用点 + MTMRTryOrError ObjC 异常保护无法包 async + Swift 并发严格性，改动面/风险大而收益边际（单发等待 ≤11s vs 轮询间隔 60s+ 感知微弱）；④ 为改而改违背本轮原则）；**落地代表性试点：RssUnread direct 并行扇出**（RssUnread.swift:59-99）——串行 for 循环 → DispatchGroup + DispatchQueue.global().async 每 feed 一并发任务 + NSLock 保护 total/anyFailed 收集 + group.wait(30s) 仅作防御性安全网（每 feed 自身 TBNet 10s 硬化上界保证 ≤11s 完成），**N×11s 串行叠加 → ≤11s**；**语义保持**：任一 feed 失败 → fetchFailed=true + unread=0（「—」+coral 失败面契约不变），全成功 → Σcount；TBNet sync API 零改动、RssUnreadItem 对外接口零改动、调用点零迁移；新增契约测试 NetworkRobustnessContractTests 同文件扩展 +4 用例（ParallelFeedURLProtocol 桩按 URL 路由成功 payload/即时失败 + 统计同时在途峰值 maxConcurrent，零真实网络经 TBNet.sessionOverride 注入——testRssDirectParallelFetchesOverlap（maxConcurrent ≥2 + 合计 3）/ testRssDirectParallelWallTimeBoundedBySingleFeed（整轮 <1.2s 由单 feed 0.5s 界定，串行 ≥1.5s 必红）/ testRssDirectParallelAnyFailureShowsFailureState（任一失败→「—」+coral）/ testRssDirectParallelSumsAllFeeds（1+2+1=4 + iconTint gold）；**红→绿双跑**：先跑 13 用例（9 既有 + 4 新增）3 failures（并行两契约红 + 求和用例颜色断言笔误修正为真实契约 iconTint=gold），实现并行扇出后复跑 13/13 全绿断言零放宽）；**475 用例实证（471 基线 + 新增 4 零偏差）0 失败**（TEST SUCCEEDED，金丝雀 NetworkRobustnessContractTests 13/13 全绿）
- **锚点巡检收口复跑接入保持**：scripts/anchor-patrol.py 收口复跑接入（第 29 轮 B 卡固化）连续第二十五轮保持——第 46 轮收口后复跑 PASS 67 / WARN 16 / INFO 5 / ERROR 0 退出码 0，与第 45 轮收口基线逐项一致零新漂移（改动文件 RssUnread.swift / NetworkRobustnessContractTests.swift 均非锚点文件，锚点行号零漂移），机器检查零回归
- **工程版本号对齐**：Info.plist 0.45/470 → 0.46/471（第 46 轮收口落地，B 卡版本决策建议收口采纳、README v0.46 条目对齐，营销版本号与工程版本号对齐惯例延续）

### v0.46

> 承接第 45 轮：网络 widget 失败面统一治理（第二批——前端体验维度：盘点分类（已合规对照 SlackUnread 不动作 + 明确标注 mock 合规类 8 项不改 + 误导/语义混淆类 4+1 治理）；发现并根因修复真实问题 5 处——WeatherOutfit 废除 mock 22° 伪装、BilibiliFeed 失败不再显示误导性 0、CiPipeline 拆「请求失败」/「无结果」两语义、DailyQuote 失败显式反馈、WordLookup 同类两态分离；新增 NetworkRobustnessContractTests 5 用例（红 9 用例 11 failures→绿 9/9 双跑实证未放宽断言）；471 用例实证 0 失败（466 基线 + 新增 5 零偏差，102.96s））、锚点巡检收口复跑接入保持（连续第二十三轮 0 ERROR），并完成工程版本号对齐（Info.plist 0.44/469 → 0.45/470）。第 46 轮 A 卡「轮询链同步网络调用异步化评估与治理」进行中（接 R44/R45 登记候选：TBNet sync API 保持、调用点 15+，异步化重构评估与治理，细节以 A 卡收口记录为准）。

#### 工程与稳定性

- **网络 widget 失败面统一治理（第二批，前端体验维度）**：承接第 44 轮失败面范式（RSS 四后端 + direct counter 改 Int?，RssUnreadItem fetchFailed 失败态「—」+coral）的第二批治理——盘点分类（grep 取证）：① 已合规对照（SlackUnread「请求失败」+coral 不动作作为对照基准、ApiLatency「超时」+coral、CitationGen「查询失败」+coral）；② 明确标注 mock 合规类不改（SystemTemp/ServerMonitor/DockerStatus/PrinterStatus/PackageTracker/FoodDelivery/HomekitScene/RssUnread，副值均带「mock」字样诚实标注）；③ 误导/语义混淆类 4+1 治理——WeatherOutfit（离线 mock 22° 伪装成真实温度，与成功态同构用户无法区分）、BilibiliFeed（失败 unreadCount=0 误导性数字）、CiPipeline（「无结果」混网络失败与确实无 workflow run 两语义）、DailyQuote（离线前缀无失败色/图标 + 浮层「换一句」失败静默保留旧值）、WordLookup（同类新发现：网络失败与「未找到释义」同文案语义混淆）；**发现并根因修复真实问题 5 处**（统一 fetchFailed 标记 + 「—」主值 + coral tint 范式）：① WeatherOutfitItem——compute 失败置 fetchFailed、apply 失败态优先显示「—」+「获取失败/offline」+ valueColor/iconTint 双 coral，**废除 mock 22° 伪装**，成功路径逻辑零改动；② BilibiliFeedItem——compute 每周期复位 fetchFailed，失败态「—」+「加载失败」+ 双 coral，不再显示误导性 0，未配置路径保持 textTertiary；③ CiPipelineItem——拆两种失败语义：网络请求失败（json 非字典/nil）→「请求失败」+coral，请求成功但 workflow_runs 空 →「无结果」textTertiary；④ DailyQuoteItem——compute/fetchQuote 失败置 fetchFailed，valueColor 与浮层 label 切 coral，浮层「换一句」失败显示「获取失败，点击重试」+coral+按钮恢复，禁止静默保留旧值；⑤ WordLookupItem——json nil（网络失败）→「请求失败」，API 到达但无释义 →「未找到释义」，两态分离；新增契约测试 NetworkRobustnessContractTests.swift 5 用例（同文件追加，WeatherOutfit 失败态（「—」+获取失败+双 coral+主/副值不得含「°」×2 断言）/ BilibiliFeed 失败态（「—」+加载失败+双 coral）/ CiPipeline 网络失败（请求失败+coral）/ CiPipeline 无 runs（JSONStubURLProtocol 桩 {\"workflow_runs\":[]} → 无结果+textTertiary）/ DailyQuote 失败态（valueColor coral + 离线前缀文案保留），沿用 FailingURLProtocol 桩 + TBNet.sessionOverride 注入 + setUp 钉 .chinese）；**471 用例实证（466 基线 + 新增 5 零偏差，102.96s）0 失败**（NetworkRobustnessContractTests 9/9 全绿）
- **锚点巡检收口复跑接入保持**：scripts/anchor-patrol.py 收口复跑接入（第 29 轮 B 卡固化）连续第二十三轮保持——第 45 轮收口后复跑 PASS 67 / WARN 16 / INFO 5 / ERROR 0 退出码 0，与第 44 轮收口基线逐项一致零新漂移，机器检查零回归
- **工程版本号对齐**：Info.plist 0.44/469 → 0.45/470（第 45 轮收口落地，B 卡版本决策建议收口采纳、README v0.45 条目对齐，营销版本号与工程版本号对齐惯例延续）

### v0.45

> 承接第 44 轮：网络请求健壮性审计与治理（后端服务维度——全仓网络调用盘点分类（6 处信号量同步调用有界等待 + 7 处默认 60s 无显式超时站点 + 25 处合规站点 + 错误面盘点）；发现并根因修复真实问题 3 类——TBNet.syncFetch 统一硬化（等待超时 task.cancel() 释放孤儿 dataTask + 合成 NSURLErrorTimedOut + 成功才读结构性消除数据竞争，ApiLatency/PackageTracker/ApiTester 4 处调用点复用并顺带修正 ApiTester 12s/10s 错配）、RSS 失败面（四后端 + direct counter 改 Int?，RssUnreadItem fetchFailed 失败态「—」+coral 替代误导性 0）、7 处默认 60s 站点补显式 timeoutInterval=15 + StockBarItem 单飞守卫防堆积；新增 NetworkRobustnessContractTests 4 用例（URLProtocol 桩零真实网络，红 5 failures→绿 4/4 双跑实证未放宽断言）；466 用例实证 0 失败（462 基线 + 新增 4 零偏差，102.8s））、锚点巡检收口复跑接入保持（连续第二十二轮 0 ERROR），并完成工程版本号对齐（Info.plist 0.43/468 → 0.44/469）。第 45 轮 A 卡「网络 widget 失败面统一治理（第二批）」进行中（WeatherOutfit mock 22° 废除 + BilibiliFeed 失败 0 改「—」+ CiPipeline 失败语义区分 + DailyQuote 失败视觉/反馈 + 失败面契约测试 N 用例 + 全量 466+N 用例 0 失败实证，以收口记录为准）。

#### 工程与稳定性

- **网络请求健壮性审计与治理（后端服务维度）**：全仓网络调用盘点分类——6 处信号量同步调用有界等待（TBNet.syncFetch 统一入口）+ 7 处默认 60s 无显式超时站点 + 25 处合规站点 + 错误面盘点（失败静默保留旧值 5 widget 登记第 45 轮第二批治理候选）；**发现并根因修复真实问题 3 类**：① TBNet.syncFetch 统一硬化——等待超时 task.cancel() 释放孤儿 dataTask（防资源泄漏）+ 合成 NSURLErrorTimedOut（调用方语义一致）+ 成功才读（结构性消除 data 竞争），ApiLatency/PackageTracker/ApiTester 4 处调用点复用并顺带修正 ApiTester 12s/10s 超时错配；② RSS 失败面——四后端 + direct counter 改 Int?，RssUnreadItem fetchFailed 失败态「—」+coral 替代误导性 0（0 未读与加载失败不可区分）；③ 7 处默认 60s 站点补显式 timeoutInterval=15（天气/汇率/日历/快递/股票等）+ StockBarItem 单飞守卫防堆积；新增契约测试 NetworkRobustnessContractTests.swift 4 用例（URLProtocol 桩零真实网络，红 5 failures→绿 4/4 双跑实证未放宽断言）；**466 用例实证（462 基线 + 新增 4 零偏差，102.8s）0 失败**（金丝雀 StockMarketHoursTests 16 / WidgetLeakTests 30 / RegistryReconciliationTests 6 / ItemTypeDecodeRegistryTests 173 / WriteSideContractTests 6 / SecretsManagerContractTests 13 全绿）
- **锚点巡检收口复跑接入保持**：scripts/anchor-patrol.py 收口复跑接入（第 29 轮 B 卡固化）连续第二十二轮保持——第 44 轮收口后复跑 PASS 67 / WARN 16 / INFO 5 / ERROR 0 退出码 0，与第 43 轮收口基线逐项一致零新漂移（StockBarItem +16 行触发 8 处锚点行号修正闭环），机器检查零回归
- **工程版本号对齐**：Info.plist 0.43/468 → 0.44/469（第 44 轮收口落地，B 卡版本决策建议收口采纳、README v0.44 条目对齐，营销版本号与工程版本号对齐惯例延续）

### v0.44

> 承接第 43 轮：SecretsManager 密钥存储审计与治理（安全与合规维度——全仓 20 个 APIService 密钥生命周期盘点分类（存储介质/传输方式/泄漏面/ATS 例外域 6 个逐项）；Keychain 切换机制完整实施（读穿回退+存量迁移+回退迁移+SecItem 状态检查+测试钩子）但默认保持 false 不翻转（Debug 77R6HZNK93 vs Release D6D8BR2QNB 双 DEVELOPMENT_TEAM 跨配置 ACL 风险论证，翻转决策门登记）；发现并根因修复真实问题 7 处（clear 双后端全清/迁移删明文副本/回退反向迁移/单一权威/写失败降级/硬编码检测 12 形态键+值掩码/AppSettings 10 处死代码旁路删除）；新增 SecretsManagerContractTests 13 用例（读写对称×2+迁移×3+回退×2+清除×2+检测×4，红 14 failures→绿 13/13 双跑实证未放宽断言）；462 用例实证 0 失败（449 基线 + 新增 13 零偏差，95.8s））、锚点巡检收口复跑接入保持（连续第二十一轮 0 ERROR），并完成工程版本号对齐（Info.plist 0.42/467 → 0.43/468）。

#### 工程与稳定性

- **SecretsManager 密钥存储审计与治理（安全与合规维度）**：文件头自述缺口「Keys stored in UserDefaults are NOT encrypted at rest on disk; for production, switch to Keychain by setting useKeychain = true」——全仓密钥生命周期盘点分类：存储介质（20 个 APIService 全经 SecretsManager 单一入口（deepseek/openWeather/kuaidi100/slack/github/rss/mijia/homeAssistant/ssh/bilibili/opencodeGo/beecount 等），默认 UserDefaults 明文落盘；Keychain 代码完整但默认关闭且原实现 SecItemAdd 返回值被忽略=静默失败；AppSettings 10 处同键 @UserDefault 平行定义=死代码旁路（全仓零引用）；items.json 内嵌 api_key/apiKey 为 weather/deepseekBalance/usage 设计内配置）；泄漏面（日志/打印输出密钥全仓 0 命中；detectHardcodedKeys 原实现 0 调用点死代码且覆盖窄（仅 "api 前缀）+snippet 直接截取原行 60 字符含明文值=泄漏面→覆盖扩展 12 种 secret 形态键（apiKey/api_key/APIKey/apikey/token/secret/password/cookie/pat/authorization/x-api-key/credential 大小写不敏感）+snippet 值掩码 \*\*\*+精确行号；异常上报 detail 为服务端响应体不含请求密钥；SettingsSync 不导出服务密钥）；传输方式（DeepSeek/Slack/GitHub/RSS/HA/BeeCount 全部 Authorization Bearer header ✅；Bilibili/OpenCodeGo Cookie header ✅；OpenWeather appid query string 与快递100 key/sign POST body 为 vendor API 强制契约登记不改）；ATS 例外域 6 个（163.com 歌词搜索 HTTP 无鉴权/gtimg.cn 腾讯 CDN/qq.com/localhost RSS 开发服务器/sinajs.cn 历史遗留零引用/weather.com.cn 中国天气 HTTP）全部无鉴权公开端点，密钥请求全走 HTTPS/header，配置合理无需改动；**Keychain 治理评估**：切换机制可行且已完整实施（读穿回退+迁移+回退迁移+SecItem 状态检查+测试钩子），但默认值保持 false 不翻转——① Debug（77R6HZNK93）与 Release（D6D8BR2QNB）不同 DEVELOPMENT_TEAM，Keychain 条目 ACL 绑定签名 designated requirement，跨配置存在「另一配置读不到本配置写入条目」风险；② hosted 单测共享真实钥匙串+CI CODE_SIGNING_ALLOWED=NO，翻转默认会污染/无法访问；③ 翻转前需先统一签名身份（决策门登记），`useKeychain = true` 一行可开；**发现并根因修复真实问题 7 处**：① clear() 只清活动后端（Keychain 模式清不掉 UserDefaults 明文副本，回退后密钥复活）→ 双后端全清；② useKeychain=true 无存量迁移（现有用户密钥不可见）→ retrieve 读穿 UserDefaults 旧值+迁移+删明文副本；③ useKeychain=false 无回退读穿（曾切 Keychain 用户切回丢密钥）→ retrieve 反向迁移 Keychain 存量；④ store() 写活动后端不删另一后端（双写副本/陈旧值复活）→ 单一权威（写 Keychain 删 Defaults 副本/写 Defaults 删 Keychain 副本）；⑤ keychainStore 忽略 SecItemAdd 状态（写失败静默丢密钥）→ 状态检查+失败降级 UserDefaults+AppLog.warn+空串双后端清；⑥ detectHardcodedKeys 死代码+覆盖窄+snippet 含明文值 → 覆盖扩展 12 种形态键+值掩码 \*\*\*+精确行号；⑦ AppSettings 10 处同键 @UserDefault 死代码旁路（绕过单一入口）→ 删除（仅保留有引用的 deepseekModel/rssProvider）；新增契约测试 SecretsManagerContractTests.swift 13 用例（读写对称×2（双后端往返）+ 迁移×3（存量迁移删副本/写失败降级不丢/Keychain 写删 Defaults 副本）+ 回退×2（回退读穿反向迁移/Defaults 写删 Keychain 副本）+ 清除×2（双后端全清/空串清双后端）+ 检测×4（12 种形态键命中/空值非 secret 不误报/snippet 掩码脱敏/精确行号），沿用 SettingsSync.itemsJSONPathOverride 同型测试钩子 SecretsManager.defaultsOverride/keychainOverride（生产恒 nil 走真实后端，setUp/tearDown 复位不触碰真实存储），红（14 failures：迁移/回退/清除/单一权威/检测覆盖/掩码全红）→ 绿（13/13）双跑实证未放宽断言）；**462 用例实证（449 基线 + 新增 13 零偏差，95.8s）0 失败**（金丝雀 StockMarketHoursTests 16 / WidgetLeakTests 30 / RegistryReconciliationTests 6 / ItemTypeDecodeRegistryTests 173 / WriteSideContractTests 6 / SecretsManagerContractTests 13 全绿）
- **锚点巡检收口复跑接入保持**：scripts/anchor-patrol.py 收口复跑接入（第 29 轮 B 卡固化）连续第二十一轮保持——第 43 轮收口后复跑 PASS 72 / WARN 11 / INFO 5 / ERROR 0 退出码 0，与第 42 轮收口基线逐项一致零新漂移，机器检查零回归
- **工程版本号对齐**：Info.plist 0.42/467 → 0.43/468（第 43 轮收口落地，B 卡版本决策建议收口采纳、README v0.43 条目对齐，营销版本号与工程版本号对齐惯例延续）

### v0.43

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
