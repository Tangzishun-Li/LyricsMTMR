# 架构债：Mirror 的"第二套 item 实例"

> 状态：**Phase 1 最小修复已落地**（快照兜底，2026-11-14；对应 GitHub issue #46
> "歌词等复杂小组件在 mirror 镜像中无法显示"）。
> 严重度：P0（Mirror 是项目的差异功能之一，歌词在镜像里不可见等于招牌功能缺一半）。

## 1. 现象

- Mirror 窗口里，按钮/时钟/电池等"无状态或自取数"的组件正常。
- `lyrics`（KaraokeLabel 逐字）、`upnext`（App Scrubber）等**有状态/自带滚动视图**的组件不显示或显示为空。
- 实体 Touch Bar 上同一组件正常。

## 2. 当前实现（事实，带位置）

| 位置 | 事实 |
| --- | --- |
| `Core/TouchBarMirrorWindowController.swift:31` | Mirror 自己 `lazy var factory = BarItemFactory(... usesSharedLyricsConfiguration: false)`——**第二套工厂** |
| 同文件 `update(definitions:)` | 按 definition 的 signature 做差量；每个 ID 新建 `NSTouchBarItem`，identifier 形如 `desktop.<UUID>.<原ID>` |
| 同文件 `DesktopBarItemHost` | 把 `item.view` 掏出来当普通 NSView 用（popover 取 `collapsedRepresentation`），固定高度 30、宽度从约束/intrinsicSize 推 |
| `MTMR/Widgets/.../UpNextScrubberTouchBarItem.swift:13` | item 自带 `NSBackgroundActivityScheduler` + `NSScrollView`，数据从事件源推 |
| `LyricsRendering/LyricsTouchBarItem.swift:44` | item = `NSCustomTouchBarItem + TBPollPausable`，`view = stackView`（卡拉 OK 标签 + 封面），数据订阅 `LyricsEngine.shared`，另有 `marqueePauseGate` 受 `TouchBarVisibilityState.shared.isBarHidden` 初值影响 |

根本问题：**item 同时是"视图容器 + 数据订阅者 + 定时器/调度器持有者"**。Mirror 需要"再来一份视图"，
但这个设计只能通过"再来一个完整 item"实现，于是产生 6 处隐式耦合：

1. 同一份数据被两套调度器各自拉取（轮询类组件在 Mirror 打开时负载翻倍）；
2. 暂停语义分裂——实体栏的 `isBarHidden` 与 Mirror 的 `paused` 是两套状态，
   `TBPauseGate(startPaused:)` 的初值在 Mirror 场景下可能是错的（实体栏隐藏时打开 Mirror）；
3. 部分 item 的 `view` 在 init 后就绑定了自己的约束/尺寸（scrollView、卡拉 OK 标签），
   被 `DesktopBarItemHost` 强行改父视图 + 固定高 30 后，布局可能塌成 0 宽；
4. item 的 identifier 被 Mirror 改写为 `desktop.<UUID>.*`，任何按 identifier 分支的逻辑（主题切换、popover 定位）都会失配；
5. popover 类 item（34 个 `TBPopoverItem` 子类）在 Mirror 里只能拿 `collapsedRepresentation`，展开行为需要另写一套；
6. `usesSharedLyricsConfiguration: false` 说明作者已经踩过"共享配置"的坑，但用"复制一份配置"绕开，
   数据源共享、视图不共享的边界并没有被定义清楚。

## 3. 候选根因（按可能性排序，待实测确认）

| # | 假设 | 证据 | 验证方式 |
| --- | --- | --- | --- |
| A | 歌词 item 在 Mirror 里被"暂停"冻住 | `marqueePauseGate` 初值 = 全局 `isBarHidden`；Mirror 的 `setPaused(false)` 若与 gate 初值一致会被 `guard 状态未变 else return` 短路 | 在 `LyricsTouchBarItem.setPaused` 打日志，对比 Mirror 打开瞬间的 gate 状态 |
| B | `DesktopBarItemHost` 约束把内容压成 0 宽 | host 只给 leading/trailing/centerY/height 四条约束，`LyricsTouchBarItem.view` 是 stackView，内部可能自带固定宽或 hugging 冲突 | 在 host 里打印 `content.frame` / `fittingSize` |
| C | 第二个 `LyricsTouchBarItem` 的 config 是副本，某些渲染开关没被 definition 覆盖 | `BarItemFactory` 对 lyrics 的 `LyricsItemConfig(copying: .shared)` | 打印 Mirror item 的 `config.displayMode/karakeStyle` 与实体栏对比 |
| D | 事件源单例只服务一个消费者（upnext 类） | Scrubber 持有 `NSBackgroundActivityScheduler`，事件源可能注册在单例上 | 看 `IUpNextSource` 注册/去重逻辑 |

> 结论：**不先拆"视图/数据"边界，逐个修只会按下葫芦浮起瓢。**

## 4. 修复方案（分三步，按风险从低到高）

### Phase 0（0.5 天，最小可交付）
给 Mirror 增加"诊断开关"：设置里一键打印每个 host 的 `content.frame`、`fittingSize`、
item 类型、paused 状态到 `~/Library/Logs/LyricsMTMR/mirror-diagnose.log`。
用真机跑一次，确认 §3 的 A/B/C 哪个命中。**没有这一步，后面都是猜。**

### Phase 1（已实现，2026-11-14）—— 快照兜底

落地内容：
- `MTMR/Core/MirrorSnapshotPolicy.swift`
  - `shouldSnapshot(.lyrics/.upnext)`：只对这两类有状态组件启用；
  - `MirrorSnapshotView`：对实体栏同一个 item 的 `view` 做 1Hz 快照，空白/无源时显示占位文案；
  - 第二套实例对这两类组件 `setPaused(true)`，避免 Mirror 打开时重复轮询。
- `TouchBarMirrorWindowController.makeHost`：命中策略且能找到实体栏同 ID item 时，用快照视图替代第二实例视图；
  找不到（如独立预设里没有对应硬件 item）时回退原路径，行为不变。
- `MirrorSnapshotTests` 6 用例：策略映射、宽度钳制、快照非空白、空白检测、零尺寸拒绝、intrinsicSize 可用。

**已知限制**（Phase 2 解决）：1Hz 静态刷新，不是逐字滚动；实体栏未创建过该 item 时无快照可拍，走占位文案。

（原计划如下，供 Phase 2 参考）
对"有状态组件"（lyrics / upnext）在 Mirror 里**只复用一个 view**：
- 不改 item 结构，先在 Mirror 侧对这两类做特殊处理——从实体栏的 `TouchBarController.items`
  里取同 identifier 的 item，用它的 `view` 做 `snapshot`（`bitmapImageRepForCachingDisplay`）
  或直接复用其 view 引用（需先 `removeFromSuperview` 并保证实体栏不可见时）。
- 优点：不动渲染层，能立刻让 Mirror 里"看得见歌词"；
- 缺点：快照不是实时的（可 1s 刷新），且实体栏可见时不能共用 view。
- 验收：Mirror 中歌词随播放滚动（快照模式 ≥1Hz）、upnext 显示当前项、原有 114 组件的
  Mirror 渲染不回归。

### Phase 2（1–2 天，正解）
把"视图"从 item 里拆出来，明确三条边界：
1. **数据层**：`LyricsEngine.shared` 是唯一数据源，提供 `AsyncStream`/Combine publisher（已有）；
2. **视图层**：新增 `LyricsBarView: NSView`（以及 upnext 的 `ScrubberBarView`），只订阅数据、不含调度器；
3. **容器层**：实体栏 item 与 Mirror host 各自持有一个 view 实例，共享数据层、互不共享视图。
   `BarItemFactory` 增加 `makeView(for:)` 与 `makeItem(for:)` 两条路径，item 内部只做 view 包装。
- 迁移顺序：先 lyrics（单一数据源、无滚动）→ 再 upnext（带 NSScrollView）→ 其余 32 个 popover item 暂不迁。
- 验收：Mirror 与实体栏同帧一致（差 ≤1 帧）；无重复轮询（用 `log stream` 数请求）；
  `WidgetLeakTests` / 新增 `MirrorSharedDataSourceTests` 全绿。

### Phase 3（可选，产品面）
Mirror 独立预设与"跟随实体栏"两种模式共用同一渲染路径后，
可考虑让 Mirror 在没有 Touch Bar 的 Mac 上成为主界面（对标已归档的 Touch Bar Simulator）。

## 5. 验收标准（修完必须全部满足）

- [ ] issue #46 关闭：lyrics + upnext 在 Mirror 中可见且随播放更新
- [ ] 打开 Mirror 时，轮询类组件的请求次数不翻倍（`log stream` 实测）
- [ ] 实体栏隐藏/显示、Mirror 显示/隐藏 8 次组合，无卡死、无 empty Mirror
- [ ] 新增 `MirrorDataSourceContractTests` ≥6 用例，覆盖暂停语义与共享数据
- [ ] 本文件 §2 的 6 处耦合在修复后逐条消失或写明"保留原因"

## 6. 关联

- 上一轮体检：`docs/调研_bar-control相似工作与可借鉴点.md`（bar-control 的 `TouchBarPresentationPolicy`
  把"呈现/让位/自愈"拆成纯函数，是 Phase 2 容器层可直接借用的写法）
- issue #46、PR #47（"待硬件验收：实体栏多指手势、所有第三方服务组件"）
