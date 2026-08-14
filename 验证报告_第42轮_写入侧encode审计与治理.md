# 验证报告_第42轮_写入侧encode审计与治理

- 轮次：第 42 轮（功能/优化迭代第 30 轮）/ 子任务 A
- 分支：r42/encode-registry（基于 main@1d3e56e，未 push）
- 任务：注册表写入侧 encode 审计与治理 — 数据与存储维度（decode 迁移系列写侧镜像）
- 执行人：default（实现/优化）

## 一、审计（全仓写入侧路径盘点与分类）

命令：`grep -rn "JSONEncoder\|PropertyListEncoder\|UserDefaults.*\.set\|\.write(to:" LyricsMTMR/MTMR --include="*.swift"` 全量采集 + 逐点核对读侧配对。

### 1.1 JSONEncoder 直接写（9 处 / 8 文件）

| # | 文件:行号 | 写入目标 | 数据类别 | 生命周期 | 读侧配对 | 对称性 |
|---|-----------|---------|---------|---------|---------|--------|
| E-1 | Preferences/SlotManager.swift:74 | slot-index.json | 槽位索引（用户配置） | 持久 | :52-58 JSONDecoder 同型 | ✅ 对称 |
| E-2 | Preferences/KeyBindingModel.swift:316 | keyBindings.json | 键绑定（用户配置） | 持久 | :309-313 JSONDecoder 同型 | ✅ 对称 |
| E-3 | Preferences/KeyBindingModel.swift:347 | keyPresets.json | 键预设（用户配置） | 持久 | :341-344 JSONDecoder 同型 | ✅ 对称 |
| E-4 | LyricsIntegration/LyricsSelectionCache.swift:108 | UserDefaults(Data) | 歌词关联缓存 | 持久 | :113-120 JSONDecoder 同型 | ✅ 对称 |
| E-5 | Widgets/WidgetKit.swift:957 | regexRules.json | 正则规则（用户配置） | 持久 | :950-952 TBStore.load 同型 | ✅ 对称 |
| E-6 | Widgets/Life/ExpenseTracker.swift:106 | 账目文件 | 记账数据 | 持久 | :104 JSONDecoder 同型 | ✅ 对称 |
| E-7 | Widgets/Productivity/ClipboardHistory.swift:129 | clipboardHistory.json | 剪贴板历史 | 持久 | :113 TBStore.load 同型 | ✅ 对称 |
| E-8 | Widgets/Productivity/PaperProgress.swift:44 | paperProgress.json | 阅读进度 | 持久 | :37-38 JSONDecoder 同型 | ✅ 对称 |
| E-9 | Widgets/Productivity/PaperTags.swift:82 | paperTags.json | 论文标签 | 持久 | :74-79 JSONDecoder 同型 | ✅ 对称 |

**结论**：9 处 JSONEncoder 写全部有同型 JSONDecoder 读配对，编码结构（含 KeyBinding 的 Set\<KeyModifier\> CodingKeyRepresentable 自定义编解码、LyricsItemConfig 的 NSKeyedArchiver 颜色归档）读写两端一致 —— 全部对称，无 encode 未迁/不对称风险。

### 1.2 UserDefaults .set 直接写（23 处 / 10 文件）

| 文件 | 处数 | 键前缀 | 读侧配对 | 对称性 |
|------|------|--------|---------|--------|
| Preferences/ToolsTabView.swift | 9 | com.lyricsmtmr.spectrum.\* / apilatency.\* | AudioSpectrumBarItem:47-53 / ApiLatency:32,36 | ✅ 对称 |
| Preferences/UnifiedSettingsWindowController.swift | 3 | settings.sidebar.visible / group.expanded.\* | :1173 / :1507 | ✅ 对称 |
| Widgets/DevOps/OpenCodeGoUsageBarItem.swift | 2 | com.lyricsmtmr.opencodego.discoveredWorkspaceID | :464 | ✅ 对称 |
| Preferences/AITabView.swift | 2 | com.lyricsmtmr.ai.streamOutput / showBalance | :204-205 | ✅ 对称 |
| App/AppSettings.swift | 2 | com.lyricsmtmr.theme.selectedIndex + @UserDefault 封装 | :163 / wrapper getter | ✅ 对称 |
| Widgets/Productivity/PostureReminder.swift | 1 | cycleKey | :28 | ✅ 对称 |
| Support/SecretsManager.swift | 1 | service.defaultsKey | :174 | ✅ 对称 |
| Preferences/SettingsSync.swift | 1 | importProfile 导入键 | exportProfile 导出 | ✅ 对称 |
| Preferences/GeneralTabView.swift | 1 | AppleLanguages（系统键） | 系统读取 | ✅ 对称 |
| App/StatusBarMenuView.swift | 1 | AppleLanguages（系统键） | 系统读取 | ✅ 对称 |

另：LyricsItemConfig.swift 12 处 .set（歌词配置，读写 1:1 同源）+ LyricsSelectionCache.swift 1 处 .set（Data 写入，见 E-4）。

**结论**：全部 .set 键均有同键读侧配对，读写类型一致 —— 全部对称。

### 1.3 items.json 字典写路径（Item 写侧核心）

| 文件:行号 | 写入方式 | 与注册表读侧的关系 |
|-----------|---------|-------------------|
| Preferences/SettingsSync.swift:64-129 | loadItemsRaw() → 字典合并 → saveItems()（JSONSerialization 字典透传） | **写侧不经过 Item encode**：字典透传保留未知键；读侧注册表 decodeIfPresent 容缺键 —— 双向对称成立 |
| Preferences/Editor/DraftManager.swift:283-308 | JSONSerialization 字典直写 | 同上 |
| Preferences/Editor/RibbonEditorView.swift:784-792 | ThemeSupport.write 字典直写 | 同上 |
| Preferences/SlotManager.swift:535-564 | 字典读改写（themeSwitch themes 注入） | 同上 |

**关键结论（任务核心验证项）**：decode 迁移系列把 93/98 类 Item 的**读侧**迁入注册表，但 **items.json 写侧从未经过 Item 的 encode 路径** —— 写侧全部是 `[[String: Any]]` 字典透传（JSONSerialization），不存在「decode 已迁、encode 未迁」的不对称：写侧不依赖 Item 类型知识，读侧注册表对缺键宽容（decodeIfPresent + 默认值），任意已迁类型的既有配置写回后仍可被注册表闭包正确解码。**写-读对称性由架构保证，非逐类型巧合**。

### 1.4 序列化失败静默吞错（try? 模式）审计

9 处 JSONEncoder 写全部 `try? encode` + `try? data.write` 静默失败：编码失败（Codable 结构体基本不可能，含 Double 有限值）与磁盘写失败（权限/空间）被吞。评估：持久化均为用户数据，静默失败会导致「改设置后重启丢失」类问题，但**无编码失败的实际触发路径**（全部为 String/Double/Bool/数组等基础类型，无 NaN/Infinity 注入点），磁盘失败属系统级异常。登记为已知取舍（与既有 TBStore 全仓 try? 风格一致），不属本轮修复范围 —— 不扩大改动面。

### 1.5 写入路径强捕获 self 泄漏（内存主线并报）

- AITabView.swift:211-230 saveDebounced/persistConnection 的 DispatchWorkItem 捕获 self —— **AITab 为 SwiftUI struct（值类型）**，struct 捕获 = 值拷贝零保留（第 40 轮审计已分类豁免 16 处文件含 AITabView:237，同文件同型）；
- RibbonEditorView.swift:777-781 liveSyncWorkItem `[weak self]` 在位；OpenCodeGoUsageBarItem:533/561 异步闭包 `[weak self]` 在位；
- **结论：写入路径无新增强捕获泄漏；本轮改动未引入任何新闭包捕获。**

## 二、发现并修复的真实问题（红→绿双跑实证）

### 2.1 SettingsSync.writeBack 无匹配仍无条件重写 items.json（数据损坏风险）

**根因**：`writeBack(type:settings:)` 与 `writeBack(matcher:settings:)` 在循环结束后**无条件**调用 `saveItems(array)`。即使没有任何 item 匹配（type 不存在 / matcher 不命中），仍以 `loadItemsRaw()`（已 stripComments）的结果整体重写 items.json —— 用户手写注释被清空、格式被规范化（.prettyPrinted + .sortedKeys），纯副作用的数据损坏。

**触发实例**：AITabView.saveDebounced 每次 AI 设置变更都调用 `writeBack(type: "ai", ...)`，而 items.json 中**不存在 type "ai"**（真实类型是 aiSelectedText）→ 每次修改「流式输出/显示余额」开关都触发一次整文件空写重写。

**修复**（SettingsSync.swift）：type/matcher 两个重载各加 `didMatch` 守卫，无匹配直接 return 不落盘；index 重载已有越界守卫保持。

**红→绿实证**：新增 WriteSideContractTests 后先跑修复前代码 → `testWriteBackTypeNoMatchDoesNotRewriteFile` + `testWriteBackMatcherNoMatchDoesNotRewriteFile` **2 failure**（实测文件被重写、注释被清，断言原文比对失败）；应用修复后同用例 **6/6 全绿** —— 断言未放宽（XCTAssertEqual 原文件字节与写后字节）。

### 2.2 AITabView.swift:227 死写路径 writeBack(type: "ai")

**根因**：不存在 type "ai" 的 Item（ItemTypeRaw 无此 case；注册表/EditorSchema/主题示例全部用 aiSelectedText，且其属性仅 model/prompt）；streamOutput/showBalance 是 UserDefaults 专属设置（load() 也只从 UserDefaults 读）。该 writeBack 永不匹配、纯属死写，且在 2.1 修复前每次触发整文件重写。

**修复**（AITabView.swift）：删除该 writeBack 行，保留两处 UserDefaults.set（真正的持久化路径）。行为零变化（读写两端同为 UserDefaults），消除无效写路径。

## 三、落地契约测试（WriteSideContractTests，6 用例）

新文件 `LyricsMTMR/MTMRTests/WriteSideContractTests.swift`（add_files.py 注册，pbxproj 4 条目），沿用 ClipboardHistoryItem.persistHistory 同型测试钩子：`SettingsSync.itemsJSONPathOverride`（生产恒 nil = 真实路径，测试指向临时目录，tearDown 清理）。

| 用例 | 断言契约 |
|------|---------|
| testWriteBackTypeNoMatchDoesNotRewriteFile | 无匹配 type 不重写文件（注释/格式原样） |
| testWriteBackMatcherNoMatchDoesNotRewriteFile | 无匹配 matcher 不重写文件 |
| testWriteBackIndexOutOfRangeDoesNotRewriteFile | 越界 index 不重写文件 |
| testWriteBackTypeMatchMergesOnlyMatchingItem | 匹配时合并设置；非匹配 item 与未知键（customKey）原样保留 —— 写侧不吞键 |
| testWriteBackMatcherMatchMergesSettings | matcher 命中合并 |
| testWriteBackIndexMatchMergesSettings | index 命中合并 |

全部通过临时 items.json 真实读写断言（非 mock），红→绿双跑见 2.1。

## 四、全量回归实证

```
caffeinate -i xcodebuild test -project LyricsMTMR.xcodeproj -scheme MTMR -configuration Debug
  -derivedDataPath /tmp/LyricsMTMR-dd-r42a-test
（先清理旧 /tmp/LyricsMTMR-dd-*：0 残留；独立 derivedDataPath；caffeinate 防显示器休眠）
```

**TEST SUCCEEDED —— Executed 449 tests, with 0 failures (0 unexpected) in 98.6s**

- 基线口径 443（第 41 轮收口）+ 新增 6（WriteSideContractTests）= 449，零偏差 0 失败；
- 金丝雀全绿：StockMarketHoursTests 16 / WidgetLeakTests 30 / RegistryReconciliationTests 6 / ItemTypeDecodeRegistryTests 173；
- 未放宽任何既有断言（唯一新增断言为 6 个新用例自身）。

## 五、文档同步（四处 + 巡检复跑）

| 文档 | 动作 |
|------|------|
| 验证报告_第42轮_写入侧encode审计与治理.md | 本文件（本分支根目录） |
| iteration-log.md | 追加「## 第 42 轮（功能/优化迭代第 30 轮）」+「### 子任务记录」小节头 + 本卡记录（标注「第 42 轮 / 子任务 A」；父任务预建头在父分支本卡基于 main 不可见故自建，收口时父任务重组） |
| file-structure.zh.md | mindmap 第 7~41 轮 → 第 7~42 轮 + 报告行登记（无重复行） |
| scripts/anchor-patrol.py | 零改动（本轮改动文件均无锚点），复跑确认 |

## 六、结论与遗留登记

**审计结论**：写入侧全部对称 —— 9 处 JSONEncoder + 23 处 UserDefaults .set + items.json 字典写路径逐点核对读侧配对成立；**「decode 已迁、encode 未迁」不对称风险在架构上不成立**（items.json 写侧为字典透传，非 Item encode 路径），未放宽断言。同时发现并根因修复真实问题 2 处（无匹配重写 + 死写路径），新增 6 契约用例钉住写侧行为，全量 449 用例 0 失败。

遗留登记：① try? 静默吞错为全仓既有风格（TBStore 同型），无实际编码失败触发路径，暂不扩大改动面；② 测试钩子 itemsJSONPathOverride 保持 @testable 内部可见（与 persistHistory 同型），不进入生产路径；③ 内存修复真机冒烟 3 项挂账延续（第 8/17~42 轮同口径）。
