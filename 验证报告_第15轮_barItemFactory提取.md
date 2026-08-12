# 验证报告_第15轮_barItemFactory提取

- 轮次：第 15 轮（功能/优化迭代第 3 轮）· 子任务 B（代码质量与工程规范维度）
- 任务卡：t_ade25e65（分支 r15/refactor，工作区 `.worktrees/round15-B`，基于 main@1f4b1ca）
- 落地目标：TECHNICAL_DEBT.md 置顶 TODO 第 4 条「extract bar items creating from TouchBarController to separate class, cover with tests」
- 日期：2026-08-12

---

## 一、提取前后结构对比

### 提取前（TouchBarController.swift，1394 行）

| 职责 | 位置 |
|------|------|
| `createItemInternal` — 113 case 的 type→widget switch + 动作/参数后处理 | :828-1090 |
| `createItemSafely` — Swift 错误 + ObjC 异常双层隔离 | :790-825 |
| `createErrorItem` — ⚠︎ 错误指示 item | :1093-1105 |
| 控制器生命周期（preset 加载/主题切换/窗口管理/touchBar 组装） | 其余 |

创建逻辑与控制器生命周期耦合：widget 构造路径无法脱离 `TouchBarController.shared` 单例独立测试。

### 提取后

| 文件 | 行数 | 职责 |
|------|------|------|
| `LyricsMTMR/MTMR/Core/BarItemFactory.swift`（新增） | 371 | `createItem`（原 switch 语义拷贝，113 case 全部迁移，含 post-processing）、`createItemSafely`（双层隔离，含 AppLog 记录与 ObjC 异常包装）、`createErrorItem`（⚠︎ 指示 item）；三个控制器能力以闭包注入 |
| `LyricsMTMR/MTMR/Core/TouchBarController.swift` | 1394 → 1092 | 控制器职责收窄：`createItemSafely` 一行委托 `itemFactory`；新增 `private lazy var itemFactory`（注入 `action(forItem:)` / `longAction(forItem:)` / `closure(for:)` 三个弱引用闭包） |
| `LyricsMTMR/MTMRTests/BarItemFactoryTests.swift`（新增） | 19 个用例 | 见第三节 |

`createItem` 保持 `throws -> NSTouchBarItem?` 签名（与原 `createItemInternal` 一致），类非 final、方法可覆写，测试通过子类注入抛错路径验证错误隔离。

## 二、依赖处理说明（解耦方式）

工厂不持有控制器引用，控制器私有能力全部通过构造注入解决：

| 原控制器私有能力 | 注入形式 | 说明 |
|------|------|------|
| `action(forItem:)`（legacy action → 单点闭包） | `actionResolver: (BarItemDefinition) -> (() -> Void)?` | 控制器传 `{ [weak self] in self?.action(forItem: $0) }`，弱引用不延长生命周期 |
| `longAction(forItem:)`（legacy longAction → 长按闭包） | `longActionResolver` 同上 | 同上 |
| `closure(for:)`（Action → 崩溃隔离闭包） | `closureResolver: (Action) -> (() -> Void)?` | 内部 `rawClosure` + `MTMRTryOrError` 包装逻辑仍留在控制器，工厂只拿到最终闭包 |
| `createErrorItem` | 整体迁入工厂 | 纯 AppKit 构造、无控制器状态依赖，迁入后控制器删除该方法 |
| `MTMRTryOrError` / `AppLog` | 全局函数直接使用 | 本就与控制器无关 |

未解耦项（保留在控制器，合理）：preset 解析/加载（`loadItemDefinitions`/`reloadPreset`/`reloadPresetAsync`）、touchBar 组装与呈现（`prepareTouchBar`/`presentTouchBarWithCurrentItems`）、主题切换状态机、失败 item 跟踪（`failedItemIds`）。

## 三、单测覆盖（BarItemFactoryTests.swift，18 用例）

| 分组 | 用例 | 断言要点 |
|------|------|------|
| 八大类代表创建（8） | 系统控制 `darkMode` → DarkModeBarItem；媒体 `playbackProgress` → PlaybackProgressBarItem；信息展示 `timeButton` → TimeTouchBarItem；布局 `group` → GroupBarItem；计时 `pomodoro` → PomodoroBarItem；网络开发 `gitStatus` → GitStatusItem；生活 `billSplit` → BillSplitItem；工具 `uuidGen` → UuidGenItem | 类型正确 + identifier 原样保留 |
| 未知类型安全降级（2） | ① 预置 JSON 含未知 type → `barItemDefinitions()` 不整体失败、降级 `.staticButton(title:"unknown")`、工厂可安全创建；② `dock` filter 非法正则 → 工厂内建降级 "Bad regex" 按钮 | 不抛错、不崩溃 |
| 错误隔离路径（2） | ① 子类覆写 `createItem` 抛错 → `createItemSafely` 返回 ⚠︎ 错误指示 item（identifier 保留、isBordered=false）；② `createErrorItem` 直接构造断言 | 构造抛错 → 错误指示 item |
| identifier 映射一致性（1） | `identifierBase` 抽检 7 个代表类型（battery/timeButton/music/groupBar/darkMode/clipboardHistory/staticButton），覆盖八大类 + 本轮 README TODO 关联的 clipboardHistory | 映射字符串与源码一致 |
| 动作/参数应用（6） | legacyAction 解析 1 次并挂 singleTap；legacyLongAction 解析 1 次并挂 longTap；actions 数组经 closureResolver 逐个解析；`bordered=false` 应用；`title` 应用到 GroupBarItem 折叠标签 | 行为与原 createItemInternal 后处理一致 |

## 四、等价性论证

1. **switch 主体**：113 个 case 与 post-processing 逐行迁移（git diff 可核验：BarItemFactory.swift 与旧 TouchBarController.swift 对应段仅 3 处替换——`self.action(forItem:)`→`actionResolver(...)`、`self.longAction(forItem:)`→`longActionResolver(...)`、`self.closure(for:)`→`closureResolver(...)`，均为注入闭包等价调用）。
2. **配置解析**：`ItemsParsing.swift` 零改动；`BarItemDefinition` 解码、`ItemType` 枚举、`identifierBase` 映射零改动。
3. **identifier 映射**：`ItemType.identifierBase` 原样保留在 TouchBarController.swift（未迁移），`loadItemDefinitions`/`reloadPresetAsync` 的 identifier 生成逻辑未触碰。
4. **调用链**：控制器 `createItemSafely` 现为一行委托，出入参类型与原先完全一致（`(Identifier, BarItemDefinition) -> NSTouchBarItem?`）；`createItems()`、`reloadPresetAsync` 的主线程构造、`failedItemIds` 记录、慢创建告警全部不变。
5. **行为不变项**：错误隔离双层结构（Swift catch + ObjC `MTMRTryOrError`）逐行迁移；`createErrorItem` 的 ⚠︎ 标题/alert 文案/identifier 保留逻辑逐行迁移。
6. **金丝雀**：现有 84 用例基线（含金丝雀锚点）全绿（见第五节），无回归。

## 五、构建与测试实证

- 构建：`xcodebuild build -scheme MTMR -configuration Debug -derivedDataPath /tmp/LyricsMTMR-dd-r15b-build CODE_SIGNING_ALLOWED=NO` → **BUILD SUCCEEDED**
- 测试：`xcodebuild test -scheme UnitTests -configuration Debug -derivedDataPath /tmp/LyricsMTMR-dd-r15b-test` → **TEST SUCCEEDED（84 基线 + 18 新增 = 102 用例 0 失败）**
- 金丝雀锚点：全绿（testGoldenAnchors2026/2027/Makeup2026）
- 独立 derivedDataPath 与并行构建隔离（/tmp 前缀，互不干扰）

## 六、README TODO 核对修正（顺带项）

README.md TODO 区共 6 条，逐条按源码实测：

| 条目 | 实测依据 | 修正 |
|------|------|------|
| 完成歌词和封面的显示 | 歌词渲染引擎 + 封面展示在位（LyricsTouchBarItem） | 维持 [x] |
| 逐字歌词（卡拉 OK 式跳字高亮） | KaraokeLabel 逐字高亮在位 | 维持 [x] |
| 每个软件自定义类别 | appTheme 规则 + issue #40 按软件切换（第 13 轮验证） | 维持 [x] |
| 加入股市的 api，包括 A 股并加入分时图 | StockBarItem（分时图 chartMode）在位 | 维持 [x] |
| 剪切板快捷查看 | **已实现但未勾选**：`ItemsParsing.swift:350` `case clipboardHistory` 解码 + `BarItemFactory.swift:210` `case .clipboardHistory` 创建 `ClipboardHistoryItem`（提取前 TouchBarController.swift:986） | **[ ] → [x]**（本轮修正，报告注明依据） |
| …… | 占位符，无对应实现 | 维持 [ ] |

## 七、风险点

1. **语义等价依赖逐行迁移**：switch 迁移是机械拷贝，已通过 103 用例 + 金丝雀全绿实证；若未来新增 widget 类型，需同时改 `ItemTypeRaw`/`ItemType`/`identifierBase`/`BarItemFactory.createItem` 四处（提取后新增第 4 处，已在工厂文件头注释说明）。
2. **注入闭包生命周期**：`itemFactory` 为控制器私有 lazy 属性，闭包弱引用控制器；工厂随控制器存活，无循环引用（与既有 `closure(for:)` 弱引用模式一致）。
3. **`createItem` 可覆写性**：为测试抛错路径保留的可覆写点，无生产代码覆写，不影响等价性。
4. **测试依赖 AppKit**：widget 构造需主线程 + 测试宿主（TEST_HOST），与既有 WidgetLeakTests 同模式；定时器类 widget 构造后即释放，无泄漏断言冲突。
5. **行号漂移**：README TODO 注释中的代码定位行号（BarItemFactory.swift:210 / ItemsParsing.swift:350）随后续改动可能漂移，注释仅作核对依据。

## 八、交付物清单

- 生产代码：`LyricsMTMR/MTMR/Core/BarItemFactory.swift`（新增）、`LyricsMTMR/MTMR/Core/TouchBarController.swift`（收窄）
- 测试：`LyricsMTMR/MTMRTests/BarItemFactoryTests.swift`（新增，19 用例）
- 工程：`LyricsMTMR.xcodeproj/project.pbxproj`（两文件各 4 处注册）
- 文档：`LyricsMTMR/TECHNICAL_DEBT.md`（第 4 条勾选）、`README.md`（剪切板快捷查看勾选）、`LyricsMTMR/docs/file-structure.zh.md`（mindmap 第 7~15 轮 + 本报告登记）、`iteration-log.md`（第 15 轮子任务 B 记录）
- 本报告：仓库根 `验证报告_第15轮_barItemFactory提取.md`
