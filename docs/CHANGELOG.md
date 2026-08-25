# LyricsMTMR 更新日志

> 完整工程变更日志。**用户可感知**的更新见根目录 [README.md](../README.md)；本文件包含**面向维护者**的工程流水（轮次 / 卡片 / 锚点巡检 / 全量回归 / 版本号对齐等）。
>
> 关于版本号：见下方「[版本史考古](#版本史考古-2026-08-13-第-25-轮)」——v0.27~v0.63 是工程内迭代号，**GitHub Release 仅发过 v1.0.0 与 v0.8 两枚**。

---

## 📌 当前状态（2026-08-26）

- **最新 GitHub Release**：[v0.8（预发布）](https://github.com/Tangzishun-Li/LyricsMTMR/releases/tag/v0.8)（2026-08-09）
- **首个正式 Release**：[v1.0.0](https://github.com/Tangzishun-Li/LyricsMTMR/releases/tag/v1.0.0)（2026-07-29）
- **当前 main 分支 HEAD**：`01008ec`（第 63 轮收口，Info.plist `0.63/488`）
- **全量回归**：685 用例 0 失败，TEST SUCCEEDED（104.37s）
- **锚点巡检**：连续 44 轮 0 ERROR
- **下一步**：第 64 轮方向待定（候选见 `docs/轮次速查.md`）

---

## 📦 GitHub Release 摘要

### v0.8（预发布 · 2026-08-09）

完整发布说明：[v0.8](https://github.com/Tangzishun-Li/LyricsMTMR/releases/tag/v0.8)

**新增**
- 记账 BeeCount 同步（PAT 鉴权 + 连通性测试）
- AI 助手改为自带模型（API Key / 服务地址 / 模型名自由填写）
- 天气改用国内数据源（中国天气网，免 Key）+ 多城市切换
- 浏览器视频字幕接入（YouTube / Bilibili）
- OpenCode Go 用量 widget + theme4 预设 + 工具 Tab
- 歌词搜索候选数量可配置，酷狗 accesskey 容错
- 长设置页目录跳转，快速定位设置项

**改进**
- 设置界面全部接上真实持久化（消除"改了白改"）
- Dock 设置真实生效（主题作用域 + 数量不限 + 图标大小）
- 股票 Tab 重构（按主题统计与增删改）
- 编辑器操作逻辑重构（拖拽 / 防误删 / 未保存提醒 / 实时预览防抖）
- widget 增强（sparkline 布局修复 + 新增可配置项）
- 构建警告清零（68 → 0）

**性能与稳定性**
- 修复卡拉 OK 跳字重影与逐字歌词显示异常
- 修复 `AppScrubberTouchBarItem` observer 泄漏
- 修复 widget timer/observer 泄漏，空闲 CPU 降低
- 重复定时器加 tolerance，封面缓存降采样
- 退出时清理 LyricsEngine 孤儿进程
- 显式重载 preset 后不再冻结未构建的 Touch Bar

**工程与文档**
- 源码目录分层重构（App / Core / Support、Preferences / Editor、Widgets 按领域分组）
- CI 修复 + entitlements 统一 + `make build/test/archive`
- Sparkle.framework 入库
- 新增用户/开发者两册中英双语 API 文档与文件存放说明

### v1.0.0（首个正式发行版 · 2026-07-29）

完整发布说明：[v1.0.0](https://github.com/Tangzishun-Li/LyricsMTMR/releases/tag/v1.0.0)

- 歌词渲染引擎优化（KaraokeLabel 逐字高亮 / LyricsTouchBarItem 滚动）
- 设置窗口全面重构：14+ Tab / 全局搜索 / 导入导出 / 一键重置
- 56+ Touch Bar item 全面升级，10 个新测试主题（theme6–15）
- 8 个新 widget：ApiTester / BilibiliFeed / CitationGen / FinderTags / LatexSymbols / PaperProgress / PaperTags / QRCode
- 快捷键绑定 / RSS 订阅 / Touch Bar 模拟器 / AppleScript 代码生成器 / 草稿管理器 / 异常捕获器
- `ITEMS_REFERENCE.md` 完整 widget 类型参考

---

## 🔬 v0.27 起的 60+ 轮内迭代（仅在 main 分支，无对应 GitHub Release）

> v0.27 之后是密集的内迭代阶段。从 R30 开始按"每轮一卡"节奏推进，重点在**质量与稳定性**（隐藏期零空转、内存泄漏、设置架构、安全合规、构建性能），同时持续累积**用户可感知**的新功能（桌面歌词窗口、应用专属主题、组件 schema 化等）。

### 第 63 轮（R63 · 当前 main HEAD）

- **EditorTabView 死代码簇删除**（r63-a，commit `f2561a9`）：`EditorTabView.swift` / `ElementPaletteView.swift` / `TouchBarPreviewView.swift` / `PropertiesInspectorView.swift` 共 -1683 行；`project.pbxproj` 摘除 16 行注册（PBXBuildFile×4 / PBXFileReference×4 / group children×4 / Sources phase×4）
- **EditorSchema 类型检查治理 P1 首刀**（r63-b，commit `7d917c9`）：items 单巨表达式按 21 个 palette 分区拆为 `partXxx()` 显式类型分段构造，297 条数据行类型序/key 序/字面零漂移
- **EditorSchema 注册完整性测试**（r63-b）：`EditorSchemaRegistryIntegrityTests` 4 用例（97 类型不重不漏 / palette 引用集与注册集全等 / 注册完整性 / std 65 类型 width+align 显示分区）
- **全量回归**：685 用例 0 失败，TEST SUCCEEDED（104.37s 一次通过，681 基线 + r63-b 新增 4）
- **Info.plist**：`0.62/487` → `0.63/488`

### 第 62 轮（R62）

- **启动三档化与内存压力守卫**（r62-a，commit `9bb61ec`）：`applicationDidFinishLaunching` 按 S4.1 契约收进新增 `Core/StartupSequence.swift`——`MAIN_IMMEDIATE` 四步（AX 权限检查 → 控制条 presence → `reloadStandardConfig` → `statusItem/popover`）原序不动；`MAIN_NEXT_TICK`（歌词引擎启动 / slots 目录 / 桌面歌词条件恢复）挪下个 runloop tick；`BACKGROUND`（HapticFeedback 全量设备扫描）转后台队列。`StartupSequenceTests` 6 用例金标准。`DISPATCH_SOURCE_TYPE_MEMORYPRESSURE` CRITICAL 监听 + `applicationDidMemoryWarning` 共用 `performCacheReclamation` 清理链
- **全机串行构建锁脚本**（r62-b，commit `dd0a2c3`）：`scripts/build-with-lock.sh` ——一切 `xcodebuild` 必须经锁脚本排队过闸（macOS 无 `flock(1)`，采用 perl holder 进程方案全机互斥），自动注入 `-jobs ${MTMR_BUILD_JOBS:-4}` 与 `COMPILER_INDEX_STORE_ENABLE=NO`
- **构建内存优化调研**（r62-d，commit `4c8ebb0`）：实测矩阵 7 组（clean j2/j4/j8 + noindex + 增量 / no-op 地板）——峰值随 `-jobs` 单调涨（j2 1273MB / j4 ≈ 1820MB / j8 1955MB，且 j8 双输最慢 57.9s）；swiftc 驱动自带 `-c -j8` 恒定不受 `-jobs` 约束为结构性下限
- **P0 根因定案**："一开就卡死"=多 worker 并发 `xcodebuild test` 挤爆 8GB 内存→换页风暴拖垮前台 app，非 R57~R60 减脂回归；修复=并行的是开发、串行的是构建
- **全量回归（用户点名里程碑）**：UnitTests scheme **681 用例 0 失败 TEST SUCCEEDED**（104s 一次通过；675 基线 + r62-a 新增 6）
- **Info.plist**：`0.61/486` → `0.62/487`

### 第 61 轮（R61）

- **智能家居/快递/健康三域 schema 化渲染**（r61-a，commit `5ee81e1`）：`SettingsSchema.domainFields` 追加 homekit(2 toggle) / package(3 toggle，notifyOnUpdate「默认关闭」副标题随迁) / wellness(readingGoal 5...100 步1 页每天 + standupMinutes 5...90 步1 分) 三域七键；Homekit/Package/Wellness 三 Tab 改造为 NotificationTab 同款结构
- **日历提醒展示态复核定案**（r61-b，commit `74092f0`）：`remindEnabled` / `remindMinutes` 固化为「维持内存暂存展示态，勿再重开复核」——`UpNextScrubberTouchBarItem.swift` 全文无消费；新增 `CalendarReminderDisplayStateTests` 三锚点
- **INTEG 测试接线修正**（commit `f0ef8ce`）：`domainFields` 为 `static let`，`localized()` 文案进程内首触烤死——修正为语言无关文案存在性校验
- **全量回归**：675 用例 0 失败 TEST SUCCEEDED
- **Info.plist**：`0.60/485` → `0.61/486`

### 第 60 轮（R60）

- **启动 TCC 弹窗防线**（r60-a，commit `ee70b1a`）：`AppleScriptTCCGuard` 守卫——引用外部应用的脚本首次自动执行前显示占位「▶」，点按放行后恢复自循环；`defaultPreset.json` 清理 Spotify/Music/iTunes 三组 `tell application` 示例块
- **设置热更新与需刷新提示**（r60-c，commit `8cd69ae`）：`SettingsRefreshAdvisor` 统一入口——能安全热更新的域（含 ≥0.5s 去抖合窗防闪屏）直接触发 `reloadStandardConfig`，不能的返回 false 由 `Deck.RefreshBanner` 横幅提示并提供「立即刷新」；Pomodoro/Stock/SystemMonitor/Calendar/General 五域接线
- **死控件移除与 schema 注册推广**（r60-b，commit `294912c`）：移除零读者零写者死控件 5 处；`domainFields` 补注册 `notification(3 toggle)` / `weather(5 键)` 两域
- **设置项对照表交付**：`docs/设置项对照表_R60.md`——22 tab × 87 设置项逐条 文件:行号 级运行时证据
- **Info.plist**：`0.59/484` → `0.60/485`

### 第 59 轮（R59）

- **契约分歧裁决落 UI**（r59-a，commit `06d700b`）：Wellness 阅读目标滑杆「分/天」→「页/天」、范围 10...180→5...100（步长 10→1）、旧落盘值 >100 水合钳制；站起提醒滑杆 5...30→5...90 分钟；Package `notifyOnUpdate` 开关加「默认关闭」副标题
- **桌面歌词窗口位置守护**（r59-c，commit `d08451a`）：歌词设置页桌面歌词区新增「重置窗口位置」行；`DesktopLyricsFrameGuard` 矩形相交判定（部分越界保留 / 完全在外回退 R51 默认位）；`DesktopLyricsFrameGuardTests` 8 用例
- **SchemaBridge Phase2 推广两域**（r59-b，commit `b529797`）：`domainFields` 增 `systemMonitor` / `calendar` 各 6 字段；`SystemMonitorTabView` / `CalendarTabView` 显示段改 schema 驱动渲染
- **全量回归**：641 用例 0 断言失败（金丝雀 `testTimerImmediateFireOnResume` 偶发超时，单套件重跑全绿复验）
- **Info.plist**：`0.58/483` → `0.59/484`

### 第 58 轮（R58）

- **UI 态持久化 G1~G5**（r58-a/b）：`AppSettings` 新增 12 个 `@UserDefault` 键（UI State 两个 MARK 区段）；Homekit/Package/Wellness/Lifestyle/AI 五页 12 键落盘闭环
- **记账 widget 消费闭环 G6/G7**（r58-c，commit `ce1e1cd`）：`SavingsGoalItem` 消费 `savings.json` 四键（monthlyBudget / savingsGoal / currency / overspendAlert）；`BeeCount` 凭据可达时副行追加今日收支摘要（GET `/api/read/day` Bearer PAT，8s 超时），凭据缺失/网络失败一律静默回退；`ExpenseBudgetContractTests` 5 用例
- **SchemaBridge Phase2 stock 域试点**（r58-d，commit `555373a`）：`SettingsSchemaBridge` 注册 `domainFields["stock"]` 6 字段；`StockTabView` 显示段改 schema 驱动渲染
- **Info.plist**：`0.57/482` → `0.58/483`

### 第 57 轮（R57）

- **死设置审计与接线**（r57-a，commit `de2ca35`）：全量 grep 审计 `AppSettings` 全部 38 个 `@UserDefault` 键 × 21 个 TabView 读写闭环——`notificationsSound` 按规则1 接线；`notificationsPackage` / `DDL` / `Birthday` 无生产者走规则2 隐藏；`DeadSettingContractTests` 5 用例 + `scripts/audit_ud_keys.py`
- **SettingsSchemaBridge 共享层**（r57-b，commit `82d0af8`）：新建 `Preferences/Components/SettingsSchemaBridge.swift`——`PomodoroTabView` 改 schema 驱动渲染；5 个零运行时读者死装饰控件移除
- **设置⇄编辑器双向跳转**（r57-d，commit `550b5cf`）：设置→编辑器「在编辑器中打开…」菜单 + 编辑器→设置 inspector 头部「域设置…」按钮
- **TimeTouchBarItem 模板精度分档**（r57-e，commit `c0528cd`）：`refreshInterval(for:)`——模板含 S/ss→1s 否则 30s
- **TBPopoverItem overlayDidDismiss 生命周期钩子**（r57-f，commit `7636b08`）：`BreathingGuideItem` / `StandupTimerItem` / `ReadTimerItem` 三循环 timer 离屏停转
- **桌面歌词动画定时器可见性守卫**（r57-g，commit `6b8cc6b`）：`KaraokeLabel.setProgressAnimation` 入口可见性守卫
- **侧栏信息架构重排**（r57-c，commit `9354463`）：22 平铺 tab 收敛为常用(6) / 数据(5) / 更多设置(10) 3 组
- **Info.plist**：`0.56/481` → `0.57/482`

### 第 56 轮（R56）

- **桌面歌词独立配色开关**（UI 维度，R51 A 卡遗留候选）：`AppSettings` 新增 3 键（`useIndependentColors` / `textColor` hex / `progressColor` hex）+ `NSColor`↔`#RRGGBB` 编解码；`DesktopLyricsWindowController` 新增 `resolveDesktopTextColor` / `resolveDesktopProgressColor` + `applyColors()`；`LyricsTabView` `desktopLyricsSection` 新增独立配色 ToggleRow + 两个 Deck.Swatches；`DesktopLyricsColorContractTests` 8 用例
- **Info.plist**：`0.54/479` → `0.55/480`

### 第 55 轮（R55）

- **桌面歌词独立配色开关**（继续 R51 A 卡遗留候选，UI 维度，R48 后隔 7 轮）——见 R56
- **构建性能分析与编译优化**（代码质量维度，commit `81f255c`）：clean build 48s / incremental 7.6~22.4s / SwiftUI 类型检查 56.3s（54,080 表达式）瓶颈定位；Top 5 慢文件：KeyBindingTabView 3.4s / RibbonEditorView 3.2s / EditorSchema 2.9s / UnifiedSettingsWindowController 1.9s / StatusBarMenuView 1.3s；编译选项已最优；archive/ 死代码 1,246 行可清理
- **Info.plist**：`0.53/478` → `0.54/479`

### 第 54 轮（R54）

- **R47 观察项双项治理**（数据存储维度）：① `lyricsSelectionCache` 随 reset 清空隔离（`SettingsSync` 新增 `runtimeCacheKeys` 排除列表）② `selectedThemeIndex` 缺键默认 0 契约化（新增 3 契约单测 6→9 用例）
- **Info.plist**：`0.53/478` → `0.54/479`

### 第 53 轮（R53）

- **桌面歌词窗口长行 marquee**（前端体验/UI 维度续面）：新增 `MTMR/Core/DesktopLyricsWindowController.swift` 纯逻辑枚举 `DesktopLyricsMarquee` 5 纯函数；有 timetag 卡拉 OK 行 follow 跟随（正在演唱字保持可视区 65%，NSAnimationContext 动画，不建 timer）；无 timetag 长行循环 marquee 30fps timer（OPT-5 ② 同行复用守卫）；`AppSettings` 新增 `com.lyricsmtmr.desktopLyrics.marqueeEnabled` 默认 true；`DesktopLyricsMarqueeTests` 13 用例
- **Info.plist**：`0.51/476` → `0.52/477`

### 第 52 轮（R52）

- **桌面歌词窗口 MVP**（歌词产品空白面补全，前端体验/UI 维度）：新增 `MTMR/Core/DesktopLyricsWindowController.swift`——NSPanel（`.nonactivatingPanel` 非激活悬浮窗，透明+深色圆角底）；三行竖排（前/后 1 行上下文 + 当前行 KaraokeLabel 卡拉 OK 逐字高亮）；占位三态（无曲目「♪ 等待播放…」/ 已暂停 / 播放无歌词「♪ 加载歌词…」）；位置记忆；`AppSettings` 新增 3 键（带 `com.lyricsmtmr.desktopLyrics.` 前缀）；`DesktopLyricsWindowTests` 20 用例
- **Info.plist**：`0.50/475` → `0.51/476`

### 第 51 轮（R51）

- **隐私清单补建与敏感数据面审计治理**（安全与合规维度）：补建缺失的 `PrivacyInfo.xcprivacy`——必申 3 项（UserDefaults→CA92.1 / FileTimestamp→C617.1 / ActiveKeyboard→3B52.1）；SystemBootTime/DiskSpace 全仓 0 命中不声明；收集面诚实声明 2 项（Location / OtherUserContent，均 Linked=false / Tracking=false）；`PrivacyManifestContractTests` 13 用例
- **Info.plist**：`0.49/474` → `0.50/475`

### 第 50 轮（R50）

- **编译警告复检清零与工程规范治理**（代码质量与工程规范维度）：新警告 1 条根因修复（`NetworkRobustnessContractTests.swift:324` `??` 左侧非可选 String 死代码）；R41 修复面 10 条代码警告零复发；500 用例实证 0 失败
- **Info.plist**：`0.48/473` → `0.49/474`

### 第 49 轮（R49）

- **主题系统状态机一致性审计与治理**（UI 迭代维度）：全仓主题状态机 17 项盘点分类——合规不动 13 项 + 决策链抽取纯函数 2 处 + 真实问题 3 项根因修复；`ThemeStateMachineContractTests` 19 用例
- **Info.plist**：`0.47/472` → `0.48/473`

### 第 48 轮（R48）

- **UserDefaults 持久化层审计与治理**（数据与存储维度）：全仓盘点 17 键组/15 文件（grep 实证 74 处命中，生产读写点约 50 处），逐键分类定案——合规不动 13 组 + 真实问题 5 项根因修复（`TBSpectrumSettings.releaseKey` 历史遗留死常量删除 / `AITabView` 键字面量 ×4 收敛 UDKey 注册表 / `selectedThemeIndex` 字面量 ×2 收敛 + 删 `synchronize` / `synchronize()` 过时调用 5 处全删 / `UserDefaultsStore.override` 测试注入钩子落地）；`UserDefaultsContractTests` 6 用例
- **Info.plist**：`0.46/471` → `0.47/472`

### 第 47 轮（R47）

- **轮询链同步网络调用异步化评估与治理**（后端服务维度）：全仓盘点 20 处 / 13 消费文件（8 个轮询 widget 同步调用 13 处 + 6 个用户触发工具 7 处）；评估结论「不值得全量异步化」；落地代表性试点——`RssUnread` direct 并行扇出（`DispatchGroup` 并发，N×11s 串行叠加 → ≤11s）；`NetworkRobustnessContractTests` 4 用例
- **Info.plist**：`0.45/470` → `0.46/471`

### 第 46 轮（R46）

- **网络 widget 失败面统一治理（第二批）**（前端体验维度）：盘点分类（已合规对照 SlackUnread / 明确标注 mock 合规类 8 项不改 / 误导语义混淆类 4+1 治理）；发现并根因修复真实问题 5 处——`WeatherOutfit` 废除 mock 22° 伪装 / `BilibiliFeed` 失败不再显示误导性 0 / `CiPipeline` 拆「请求失败」/「无结果」两语义 / `DailyQuote` 失败显式反馈 / `WordLookup` 同类两态分离；`NetworkRobustnessContractTests` 5 用例
- **Info.plist**：`0.44/469` → `0.45/470`

### 第 45 轮（R45）

- **网络请求健壮性审计与治理**（后端服务维度）：`TBNet.syncFetch` 统一硬化（等待超时 `task.cancel()` 释放孤儿 `dataTask` + 合成 `NSURLErrorTimedOut` + 成功才读）；RSS 失败面（四后端 + direct counter 改 `Int?`）；7 处默认 60s 站点补显式 `timeoutInterval=15` + `StockBarItem` 单飞守卫；`NetworkRobustnessContractTests` 4 用例
- **Info.plist**：`0.43/468` → `0.44/469`

### 第 44 轮（R44）

- **SecretsManager 密钥存储审计与治理**（安全与合规维度）：全仓 20 个 APIService 密钥生命周期盘点；Keychain 切换机制完整实施但默认保持 false 不翻转（Debug 77R6HZNK93 vs Release D6D8BR2QNB 双 DEVELOPMENT_TEAM 跨配置 ACL 风险）；发现并根因修复真实问题 7 处（clear 双后端全清 / 迁移删明文副本 / 回退反向迁移 / 单一权威 / 写失败降级 / 硬编码检测 12 形态键+值掩码 / `AppSettings` 10 处死代码旁路删除）；`SecretsManagerContractTests` 13 用例
- **Info.plist**：`0.42/467` → `0.43/468`

### 第 43 轮（R43）

- **注册表写入侧 encode 审计与治理**（数据与存储维度——decode 迁移系列写侧镜像）：全仓写入侧盘点分类——9 处 JSONEncoder 全部同型 JSONDecoder 读配对 + 23 处 UserDefaults `.set` + `LyricsItemConfig` 12 处全部同键读侧配对；发现并根因修复真实问题 2 处（`SettingsSync.writeBack` 无匹配仍无条件 `saveItems` 重写 items.json → 加 `didMatch` 守卫 / `AITabView.swift:227` 死写路径 `writeBack(type:"ai")` → 删除）；`WriteSideContractTests` 6 用例
- **Info.plist**：`0.41/466` → `0.42/467`

### 第 42 轮（R42）

- **编译告警清零与工程规范治理**（代码质量与工程规范维度）：`xcodebuild` 全量采集 12 条 warning 逐条分类（10 条代码警告 + 2 条 `appintentsmetadataprocessor` 工具提示豁免）；发现并根因修复真实显示 bug 1 类 8 处同源（commit `917983f7` 双反斜杠插值退化字面文本）；其余 7 条行为等价修复；治理后代码警告 10→0
- **Info.plist**：`0.40/465` → `0.41/466`

### 第 41 轮（R41）

- **异步闭包捕获链泄漏契约覆盖面扩展**（非 timer/observer 的 block 捕获防回归网续织三）：泄漏契约测试 27→30 用例；发现并根因修复真实永久泄漏 1 处——`VolumeViewController` CoreAudio `property-listener block` 方法引用强捕获 `self` + deinit 永不移除（bar 每次重建累积）→ 弱闭包 + block 恒等存储 + deinit 成对移除
- **Info.plist**：`0.39/464` → `0.40/465`

### 第 40 轮（R40）

- **Observer 泄漏契约覆盖面扩展**（非 timer 资源类防回归网续织二）：泄漏契约测试 23→27 用例；发现并根因修复真实泄漏 1 处——`UpNextScrubberTouchBarItem.swift:300` `UpNextCalenderSource` `storeObserver` 强捕获 `self` 保留环 → 弱闭包
- **Info.plist**：`0.38/463` → `0.39/464`

### 第 39 轮（R39）

- **WidgetLeakTests 泄漏契约覆盖面扩展**（timer 类 widget 防回归网络密，内存修复主线续篇）：8→23 类全覆盖，新增 15 用例；发现并根因修复真实泄漏 1 处——`PomodoroBarItem.swift:87` `setEventHandler` 强捕获 `self` 保留环 → 弱闭包
- **Info.plist**：`0.37/462` → `0.38/463`

### 第 38 轮（R38）

- **保留 5 类非注册分支 switch 路径契约测试补齐**（穷尽性兜底运行时断言化）：`staticButton` / `group` / `expandable` / `themeSwitch` 4 类 8 用例；契约测试 165→173、键集 93 键零改动
- **Info.plist**：`0.36/461` → `0.37/462`

### 第 37 轮（R37）

- **注册表混合架构 decode 迁移系列最终收官**（base64Tool 换锚补迁）：`base64Tool` 迁入注册表（形态 A「全 decodeIfPresent + 默认值」）；新锚点选型 `audioSpectrum`；注册表键集 92→93，契约测试 163→165 用例
- **Info.plist**：`0.36/461`（本轮未变动）

### 第 36 轮（R36）

- **注册表混合架构 decode 迁移第六批·收官批**：可迁未迁剩余 10 分支除回退锚点外全部迁移 9 类型（`pixelPet` / `homekitScene` / `aiSelectedText` / `rssUnread` / `citationGen` / `paperProgress` / `paperTags` / `bilibiliFeed` / `apiTester`）；注册表键集 83→92，契约测试 145→163 用例
- **PR #42 CI locale 修复并入**：钉定中文语言环境
- **Info.plist**：`0.34/459` → `0.35/460`

### 第 35 轮（R35）

- **注册表混合架构 decode 迁移第五批**：可迁未迁剩余 30 分支按常用度再迁 20 类型（`breathingGuide` / `postureReminder` / `travelCountdown` / `birthdayCountdown` / `holidayCountdown` / `classCountdown` / `ddlList` / `readingProgress` / `noteCapture` / `quickScreenshot` / `savingsGoal` / `taxEstimate` / `creditCardDue` / `ciPipeline` / `systemTemp` / `diskIO` / `billSplit` / `screenPicker` / `latexSymbols` / `finderTags`）；注册表键集 63→83，契约测试 109→145 用例
- **Info.plist**：`0.33/458` → `0.34/459`

### 第 34 轮（R34）

- **注册表混合架构 decode 迁移第四批**：再迁 20 类型（`noiseMeter` / `expenseTracker` / `subscriptionCountdown` / `dailyQuote` / `emailBadge` / `meetingCountdown` / `slackUnread` / `printerStatus` / `standupTimer` / `clipboardHistory` / `wordLookup` / `dockerStatus` / `serverMonitor` / `opencodeGoUsage` / `regexTester` / `colorConvert` / `regexReference` / `screenLock` / `bluetoothToggle` / `shortcutHints`）；注册表键集 43→63，契约测试 75→109 用例
- **Info.plist**：`0.32/457` → `0.33/458`

### 第 33 轮（R33）

- **注册表混合架构 decode 迁移第三批**：再迁 20 类型（`dock` / `weather` / `yandexWeather` / `currency` / `playbackProgress` / `quickReply` / `gitStatus` / `apiLatency` / `sshStatus` / `portChecker` / `hashCalc` / `packageTracker` / `foodDelivery` / `weatherOutfit` / `dnd` / `jsonFormatter` / `timestampConvert` / `httpCodes` / `qrCode` / `readTimer`）；注册表键集 23→43，契约测试 41→75 用例
- **Info.plist**：`0.31/456` → `0.32/457`

### 第 32 轮（R32）

- **注册表混合架构 decode 迁移扩大化**：适配性分类全量 98 分支，迁入注册表 23 键（试点 3 + 本轮 20）；契约测试 7→41 用例
- **权限弹窗零自动申请治理**（用户问题卡 t_aeb0b769 合并入 main）：根因三连——构建产物 ad-hoc 签名致每轮重建 cdhash 变化 / TCC 视作全新应用授权回到 `notDetermined` / 组件「init 即自动申请」不符合最小权限 UX；修复为权限惰性化（init 零自动 TCC，显式点按才申请）：天气 / Yandex 天气定位 / 音频频谱麦克风 / 录屏 / 噪音计 / 出行 / 会议倒计时 / UpNext 播放源；`IUpNextSource` 协议新增 `requestAccessIfNeeded`
- **Info.plist**：`0.30/455` → `0.31/456`

### 第 31 轮（R31）

- **注册表混合架构 decode 迁移试点落地**：`ItemType.registeredTypeDecoders` 字典驱动解码注册表；`cpu` / `battery` / `swipe` 三类型从 decode switch 分支逐字节等价迁入；`ItemTypeDecodeRegistryTests` 7 用例
- **锚点巡检脚本收口复跑接入固化**：`scripts/anchor-patrol.py` 接入收口检查清单双点（C 卡核验前 + 合并后）
- **Info.plist**：`0.29/454` → `0.30/455`

### 第 30 轮（R30）

- **恢复补刷即时性审计与补齐**：隐藏→可见恢复侧全量接入点审计（grep 实证 25 文件 111 处 gate/timer 引用，24 接入点分类）——修复 `TBPollItem` / `TBMetricPopoverItem` 两基类恢复补刷；跑马灯定时器恢复立即推进一帧（相位空窗 ≤3s → 0 帧）
- **设置窗口闲置 GC 决策可测化**：`SettingsWindowGCStrategy` 纯策略（visible 守卫 / 内存压力短路 / 闲置阈值 3600s）；9 单测
- **文档锚点漂移巡检脚本落地**：`scripts/anchor-patrol.py` 88 项锚点数据驱动巡检清单
- **Info.plist**：`0.27/452` → `0.28/453`（首次对齐营销版本号与工程版本号）

### 第 28~29 轮（R28~R29）

- **隐藏期零空转收官审计**（5 项真遗漏修复）：`NoiseMeter` 麦克风采集链隐藏期零采集 / `ShellScript` / `AppleScript` 自循环隐藏期停止执行 / 歌词跑马灯 60fps timer 隐藏期零滚动 / `NetworkBarItem` `netstat` 常驻进程隐藏期终止
- **后台调度隐藏期零网络实证收口**：4 个后台调度组件（汇率 / 天气 / Yandex / 日历）调度器门控
- **空 bar 不再翻转全局隐藏态**：应用切换等系统事件下，空配置 bar 不再把全局隐藏态永久置位
- **失焦在途定位语义修正**（区分 close-hide / resignKey）：设置窗口失焦但窗口仍在屏时进行中的定位添加操作继续完成
- **注册表混合架构对账测试**：`RegistryReconciliationTests` 6 用例 + `generate_registry_test.py`
- **时序敏感测试健壮化**：修复 flaky 7 用例根因（测试宿主共享单例污染）
- **Info.plist**：`0.28/453` → `0.29/454`

### 第 24~27 轮（R24~R27）

- **隐藏机制收官（零空转全覆盖）**：8 个常驻定时器组件（深色模式 / 夜览 / 时钟 / 亮度 / 剪贴板 / 音乐 / 播放进度 / 音频频谱）与 4 个后台调度组件（汇率 / 天气 / Yandex 天气 / 日历）在 Touch Bar 隐藏期间全部暂停
- **隐藏期隐私保护**：音频频谱采集链隐藏期间零采集（麦克风关闭、隐私指示灯熄灭）；天气组件定位服务隐藏期间暂停（GPS 关闭、隐私指示灯熄灭）
- **全局隐藏态注入**：隐藏期间重建的组件初始即处于暂停态
- **剪贴板查看即时对齐**：浮层打开瞬间即收录最新复制内容
- **天气定位添加城市生命周期治理**：设置中定位添加城市在解析完成 / 超时 / 窗口隐藏三条路径均停止定位
- **强引用环修复**：CPU 监控 / 天气组件点击动作与汇率 / 天气调度闭包的保留环修复
- **Info.plist**：`0.27/452`（继承自上游 MTMR `v0.27.0` 的工程版本号）

### 第 20~23 轮（R20~R23）

- **隐藏机制主线（前置）**：第 20~23 轮「隐藏期零空转」治理收官（8 个常驻定时器组件 + 4 个后台调度组件 + 音频采集链 + 定位服务全部纳入暂停）
- **Info.plist**：`0.27/452`（本区间未变动）

### 第 13~18 轮（R13~R18）

- 各项功能 widget / 设置 / 编辑器增量改进
- v0.8 预发布版本的内容准备阶段
- **Info.plist**：`0.27/452`（本区间未变动）

### v0.27（首条工程迭代号）

- **节假日倒计时 widget（holidayCountdown）**：以 A 股交易日历的法定节假日表为唯一数据源
- **应用专属主题（Per-app bar switching）**：为指定 App 绑定独立 Touch Bar 布局（[issue #40](https://github.com/Tangzishun-Li/LyricsMTMR/issues/40)）
- **货币汇率 widget（currency）**：Coinbase API 恢复启用
- **macOS 15.4+ 音乐信息获取**：mediaremote-adapter 子进程桥接方案
- **隐藏机制完善**：组件按前台应用过滤补齐异步路径；黑名单 App 隐藏期间自动暂停全部 widget 轮询
- **节假日名映射健壮化**：跨年元旦 / 中秋国庆重叠窗口不再误判

---

## 📚 版本史考古（2026-08-13 · 第 25 轮）

> 本节是对"版本号"的真相记录。**GitHub Release 仅发过 2 枚**——v1.0.0（2026-07-29）与 v0.8（2026-08-09 预发布）。`Info.plist` 自 fork 上游 MTMR（最高版本 v0.27.0）时继承的工程版本号为 `0.27/452`，v1.0.0 / v0.8 两 tag 指向的提交中均为 `0.27/452`（**营销版本号与工程版本号长期脱节**），至第 24 轮收口（2026-08-13）方升为 `0.28/453`。

**结论**：

- v0.9 ~ v0.26 从未以 Release / tag / Info.plist 版本号任何形式存在——该区间是更新日志编号序列中的**空洞**
- 更新日志自 v0.27 起按迭代轮次补记（v0.27=R13~18 / v0.28=R20~23 / v0.29=R24~27 / v0.30=R28~29 / v0.31=R30 / v0.32=R31 / v0.33=R32 / v0.34=R33 / v0.35=R34 / v0.36=R35 / v0.37=R36 / v0.38=R37 / v0.39=R38 / v0.40=R39 / v0.41=R40 / v0.42=R41 / v0.43=R42 / v0.44=R43 / v0.45=R44 / v0.46=R45 / v0.47=R46 / v0.48=R47 / v0.49=R48 / v0.50=R49 / v0.51=R50 / v0.52=R51 / v0.53=R52 / v0.54=R53 / v0.55=R54 / v0.56=R55 / v0.57=R56 / v0.58=R57 / v0.59=R58 / v0.60=R59 / v0.61=R60 / v0.62=R61 / v0.63=R62 / v0.64=R63），此前条目为发布时实况
- git tag 另有 1 枚内部快照：`pre-opt-20260812-0114`（非版本发布）

---

## 🛠 关键工程里程碑速查

| 轮次 | 主题 | 关键产出 |
|------|------|----------|
| R8 | 内存修复主线 | CoreSVG 缓存 / zone 碎片 / 压力释放 / 关窗隐藏复用 + 闲置 GC（PR #41） |
| R29 | 注册表混合架构对账 | `RegistryReconciliationTests` 6 用例 + `generate_registry_test.py` |
| R30 | 注册表迁移试点 | `ItemType.registeredTypeDecoders` + `ItemTypeDecodeRegistryTests` 7 用例 |
| R32~R37 | 注册表迁移六批 | 93/98 类 Item 迁入注册表（保留 5 类非注册分支为穷尽性兜底） |
| R41~R44 | 安全合规治理 | `SecretsManager` 密钥治理 + 隐私清单 + 网络健壮性 |
| R51~R53 | 桌面歌词窗口 | NSPanel 悬浮 + 卡拉 OK + 长行 marquee + 位置守护 |
| R57 | 设置架构重排 | 22 tab → 3 组折叠 + 全局搜索 |
| R62 | 启动三档化 + 构建护栏 | `StartupSequence` + `build-with-lock.sh` |

---

## 🔗 关联文档

- [根目录 README](../README.md) — 用户可感知的新增
- [GitHub Releases](https://github.com/Tangzishun-Li/LyricsMTMR/releases) — 正式 release 与预发布
- [`docs/轮次速查.md`](../docs/轮次速查.md) — 当前 R 候选登记
- [`LyricsMTMR/docs/file-structure.zh.md`](../LyricsMTMR/docs/file-structure.zh.md) — 目录职责
- [`LyricsMTMR/docs/ITEMS_REFERENCE.md`](../LyricsMTMR/docs/ITEMS_REFERENCE.md) — 全部 114 种 widget 配置参考
- [`logs/`](../logs/) — 历次收口报告归档
