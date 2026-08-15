# 验证报告_第39轮_Observer泄漏契约覆盖面扩展

- 轮次：第 39 轮（功能/优化迭代第 27 轮）/ 子任务 A
- 分支：r39/leak-observers（基于 main@4250cfd 同点，未 push）
- 任务：Observer 泄漏契约覆盖面扩展 — 非 timer 资源类防回归网织密（内存修复主线续篇二）
- 执行人：default（实现/优化）

## 一、审计范围与方法（自选）

全仓 grep 实证（addObserver / addObserver(forName:) / addObserverForName / CFNotificationCenterAddObserver / observe( / observeValue / addObserver(_:forKeyPath:) / DispatchSource 非 timer）：

**审计结论：活代码 22 处 NotificationCenter observer 注册点 + 1 处 CFNotificationCenter + 1 处非 timer DispatchSource（AppDelegate fileSystemSource）；KVO 全仓 0 处。** 按对象生命周期分类：

| # | 注册点（文件:行） | 类型 | 对象生命周期 | 契约状态 |
|---|------------------|------|-------------|---------|
| 1 | AppDelegate.swift:54-56（NSWorkspace 3 处 selector） | selector | 单例（app 生命周期） | 无需契约（任务口径） |
| 2 | TouchBarController.swift:373-375（NSWorkspace 3 处 selector） | selector | 单例（app 生命周期） | 无需契约（任务口径） |
| 3 | LyricsEngine.swift:536（.lyricsItemConfigDidChange 1 处 selector） | selector | 单例 + deinit removeObserver(self) | ✅ |
| 4 | MediaRemoteMRBridge.m:352/:363（MR 通知 2 处 block） | block | C 层独立 runloop 线程，闭包零对象捕获（仅 dispatch_after + 全局函数） | 无需契约（无 MTMR 对象被捕获） |
| 5 | ThemeSwitchBarItem.swift:39/:51（themeIndexDidChange + appThemeAutoSwitchDidChange 2 处 block） | block | widget（可销毁） | ✅ weak 闭包 + deinit 移除双 token —— **新增契约测试** |
| 6 | AudioSpectrumBarItem.swift:337（UserDefaults.didChangeNotification 1 处 block） | block | widget（可销毁） | ✅ weak 闭包 + deinit 移除 —— **新增契约测试**（settingsDriven 路径） |
| 7 | UpNextScrubberTouchBarItem.swift:303（EKEventStoreChanged 1 处 block） | block | widget 数据源（可销毁） | ❌→✅ **真实泄漏，本轮修复** —— **新增契约测试** |
| 8 | NetworkBarItem.swift:74（NSFileHandleDataAvailable 1 处 block） | block | widget（可销毁） | ✅ weak 闭包 + stopMonitoringProcess/deinit 移除 |
| 9 | AppScrubberTouchBarItem.swift:34-36（NSWorkspace 3 处 selector） | selector | widget（可销毁） | ✅ deinit/barItemWillDiscard unregister —— **新增契约测试** |
| 10 | UnifiedSettingsWindowController.swift:65-71/:159-165（5 处 block） | block | 窗口级（可销毁） | ✅ weak 闭包 + deinit/removeObservers 全移除 |
| 11 | InputSourceBarItem.swift:79（kTISNotifySelectedKeyboardInputSourceChanged 1 处 CF） | CF 回调 | widget（可销毁） | ✅ unretained + deinit CFNotificationCenterRemoveEveryObserver |
| 12 | AppDelegate.swift:289（fileSystemSource DispatchSourceFileSystemObject） | DispatchSource 非 timer | 单例（app 生命周期） | 无需契约（任务口径） |

archive/duplicate-LyricsRendering/LyricsTouchBarItem.swift:38 为归档死代码（不参与编译，archive 目录），不计入活代码。KVO（observe(_:)/observeValue/addObserver(forKeyPath:)）全仓 0 命中，无审计项。

## 二、真实泄漏发现与修复（红→绿实证）

**发现：UpNextCalenderSource 的 EKEventStoreChanged block observer 强捕获 self（真实泄漏）**

- 根因：UpNextScrubberTouchBarItem.swift:300 原 `storeObserver = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: eventStore, queue: nil, using: handleUpdate)` —— `using:` 参数传实例方法引用 `handleUpdate`，方法引用默认**强捕获 self**：token → block → self 保留环。self 永不可达 → deinit 永不被执行 → `removeObserver(storeObserver)` 永不被调用 → observer 永驻通知中心，源对象 + 其持有的 EKEventStore 进程生命周期泄漏（日历源在 app 全生命周期内只泄漏一次，但每次 widget 重建均新增一份残留）。
- 修复：改为 `{ [weak self] note in self?.handleUpdate(note: note) }` 弱闭包（第 8/38 轮既定模式）；deinit 现可实际执行并移除 token，闭包弱捕获不产生保留环。
- 红绿双跑实证（未放宽任何断言）：
  1. **RED**：保留原代码（using: handleUpdate）+ 仅跑新测试 `testUpNextCalenderSourceDoesNotLeak` → **FAILED**（Executed 1 test, with 1 failure —— XCTAssertNil 捕获存活实例；独立 derivedDataPath /tmp/LyricsMTMR-dd-r39a-red）；
  2. **GREEN**：应用修复 + 4 个新契约测试 → **Executed 4 tests, 0 failures**（独立 derivedDataPath /tmp/LyricsMTMR-dd-r39a-green）。

## 三、用例清单（新增 4 用例）

全部追加于现有文件 MTMRTests/WidgetLeakTests.swift（hosted TEST_HOST 运行，同一文件追加无需 add_files.py 注册），沿用 autoreleasepool + weak var + letRunLoopSpin + XCTAssertNil 模式：

| # | 测试函数 | 构造方式（最小参数 + 无副作用策略） | 钉住的契约 |
|---|---------|----------------------------------|-----------|
| 1 | testUpNextCalenderSourceDoesNotLeak | UpNextCalenderSource()（默认 updateCallback；EKEventStore init + authorizationStatus TCC-safe 零弹窗——round-30 惰性化路径仅显式点按才申请） | **修复点**：observer block 弱捕获 self（红→绿实证） |
| 2 | testThemeSwitchBarItemDoesNotLeak | ThemeSwitchBarItem(identifier:themes: [])（mergedThemes 空配置走磁盘读取，无副作用） | 2 个 block observer 弱捕获 + deinit 移除双 token |
| 3 | testAppScrubberTouchBarItemDoesNotLeak | AppScrubberTouchBarItem(identifier:)（hardReloadItems 读 NSWorkspace + 持久化配置，无副作用） | 3 个 NSWorkspace selector observer deinit/barItemWillDiscard unregister |
| 4 | testAudioSpectrumSettingsDrivenObserverDoesNotLeak | NoCaptureSpectrumItem(identifier:barCount:8, source: "")（source 空 → settingsDriven=true → UserDefaults observer 注册；NoCaptureSpectrumItem 子类空实现避开 SCK/mic 硬件） | settingsDriven 路径的 UserDefaults observer 弱捕获 + deinit 移除（round-38 测试 source:"system" 刻意跳过的注册路径） |

## 四、实证表（440 用例逐套件）

命令：`caffeinate -i xcodebuild test -project LyricsMTMR.xcodeproj -scheme UnitTests -configuration Debug -derivedDataPath /tmp/LyricsMTMR-dd-r39a-test`（先清理旧 /tmp/LyricsMTMR-dd-*；独立 derivedDataPath 防并行构建冲突；caffeinate 防显示器休眠——第 28 轮 CoreDisplay 教训；红/绿双跑另用 -r39a-red / -r39a-green 独立路径）。

| 套件 | 结果 |
|------|------|
| 全量（All tests） | **TEST SUCCEEDED — Executed 440 tests, with 0 failures (0 unexpected)** |
| WidgetLeakTests | Executed 27 tests, 0 failures（23 基线 + 4 新增） |
| 其余套件（436 基线增量） | 0 failures（金丝雀 StockMarketHoursTests 三锚点全绿，RegistryReconciliationTests 6 全绿，ItemTypeDecodeRegistryTests 173 全绿） |

任务预算：436 基线 + 新增 4 = **440**，实测 440 —— **零偏差**。

## 五、文档同步表

| 文件 | 改动 |
|------|------|
| MTMR/Widgets/Media/UpNextScrubberTouchBarItem.swift | 泄漏修复 1 处（storeObserver `using: handleUpdate` 方法引用强捕获 self → 弱闭包） |
| MTMRTests/WidgetLeakTests.swift | +4 用例（23→27）+ round-39 MARK 注释节（含 selector observer 语义订正：macOS 10.11+ 零弱引用不 retain target，但 deinit 仍须 unregister 防陈旧回调） |
| iteration-log.md | 末尾追加本记录（先建「## 第 39 轮（功能/优化迭代第 27 轮）」+「### 子任务记录」小节头——第 33/35 轮教训，父分支预建 0952a53 子卡不可见故自建） |
| file-structure.zh.md | mindmap 第 7~38 轮 → 第 7~39 轮 + 报告行登记（无重复行） |
| scripts/anchor-patrol.py | 零改动（本轮改动文件无锚点：UpNextScrubberTouchBarItem.swift 不在锚点表、测试文件无锚点），复跑确认 |

锚点巡检复跑：**PASS 72 / WARN 11 / INFO 5 / ERROR 0 退出码 0**（连续第十二轮 0 ERROR）。

## 六、结论与遗留登记

- 结论：非 timer 资源类泄漏契约网织密——全仓 22 处 NotificationCenter observer + 1 处 CF 通知 + 1 处非 timer DispatchSource 逐一审计（widget/窗口级 6 处全部钉住契约，单例/无对象捕获 6 处按任务口径豁免）；发现并根因修复真实泄漏 1 处（UpNextCalenderSource EKEventStoreChanged observer 强捕获保留环），红→绿双跑实证未放宽断言；新增契约测试 4 用例（23→27），440 用例 0 失败。
- 遗留登记：
  1. NetworkBarItem / UnifiedSettingsWindowController / DockVisibilityManager / InputSourceBarItem / LyricsEngine 契约经代码审计确认（weak 闭包或 unregister 在位），未逐一新增独立测试——block observer 模式与 ThemeSwitchBarItem/AudioSpectrumBarItem 同构（weak + deinit remove），selector 模式与 AppScrubberTouchBarItem 同构；低风险项不重复铺测试。
  2. UpNextCalenderSource 修复后 observer 在 deinit 移除；若 EKEventStore 变更通知在对象销毁后到达，因 token 已移除零回调（无陈旧回调窗口）。
  3. 内存修复真机冒烟 3 项挂账延续（第 8/17~39 轮同口径）。
  4. 本轮零新增生产观察项；未 push（父任务收口统一推送）；未开新分支/新子任务/无 parents 依赖；未建 cron/自触发；未改 Info.plist 版本号（B 卡建议、父任务收口落地）。
- 完成自查：git status 干净（仅预期改动）+ commit 已提交（第 14 轮 B 卡漏提交教训）。
