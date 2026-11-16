# 架构债：Mirror 的"第二套 item 实例"

> 状态：**Phase 2 已实现**（共享数据源 + 每栏独立视图，2026-11-16；Phase 1 的
> 1Hz 快照兜底已被替换并从工程中删除。对应 GitHub issue #46
> "歌词等复杂小组件在 mirror 镜像中无法显示"）。
> 严重度：P0（Mirror 是项目的差异功能之一，歌词在镜像里不可见等于招牌功能缺一半）。

## 1. 现象（历史）

- Mirror 窗口里，按钮/时钟/电池等"无状态或自取数"的组件正常。
- `lyrics`（KaraokeLabel 逐字）、`upnext`（App Scrubber）等**有状态/自带滚动视图**的组件不显示或显示为空。
- 实体 Touch Bar 上同一组件正常。

## 2. 当前实现（Phase 2 事实，带位置）

| 位置 | 事实 |
| --- | --- |
| `LyricsRendering/LyricsBarView.swift` | **视图层**：`final class LyricsBarView: NSView, TBPollPausable`。负责 stackView（封面 + 卡拉 OK 标签 + 占位）构建、订阅 `LyricsEngine.shared`、逐字 karaoke、marquee/follow 滚动、`setPaused(_:)`、`applyConfig(_:)`。不持有任何调度器，数据源固定为共享 engine。 |
| `LyricsRendering/LyricsTouchBarItem.swift` | **容器层**：`NSCustomTouchBarItem + TBPollPausable`，`view = barView`；`applyConfig`/`setPaused` 转发给 `LyricsBarView`；保留 `init(identifier:config:)`、`convenience init(identifier:)`、点击手势与 `LyricsClickAction` 切换（原文/翻译/音译）。 |
| `MTMR/Widgets/Media/UpNextFeedStore.swift` | **数据层共享发布**：`UpNextFeedStore.shared` 持有 `[UpNextItem]`（Combine `CurrentValueSubject`），提供 `update(items:)`、`subscribe(_:)`、`subscriberCount`/`updateInvocations`（测试缝）。store 自身不拉数据、不建调度器。 |
| `MTMR/Widgets/Media/ScrubberBarView.swift` | **视图层**：`final class ScrubberBarView: NSView, TBPollPausable`，持有 `NSScrollView` + item `NSStackView`（原 `reloadData`/`updateSize` 逻辑整体迁入），只订阅 `UpNextFeedStore`。 |
| `MTMR/Widgets/Media/UpNextScrubberTouchBarItem.swift` | **容器层 + 唯一数据生产者**：保留 `NSBackgroundActivityScheduler` 与 `IUpNextSource` 事件源；每次拉取完成后 `UpNextFeedStore.shared.update(items:)`。**Mirror 不创建该 item**。 |
| `MTMR/Core/TouchBarMirrorWindowController.swift` | **容器层**：`MirrorRenderPolicy.usesSharedView(for:)` 判定 `.lyrics` / `.upnext` 走共享视图分支；`makeHost` 对 `.lyrics` 直接 new `LyricsBarView(config:)`、对 `.upnext` 直接 new `ScrubberBarView(...)`；这两类不再创建第二个 `NSTouchBarItem`（因此不会产生第二套 scheduler/事件源/engine 订阅）。 |
| `MTMR/Core/BarItemFactory.swift` | `lyricsConfig(from:shared:)` 提供实体栏与 Mirror 共用的 definition→`LyricsItemConfig` 映射（Mirror 传 `shared: false`，只拿副本、不写回 preset）。`BarItemFactory` 构造签名未变。 |

Phase 2 后的三层边界（本次重构的核心结论）：

1. **数据层**：`LyricsEngine.shared`（播放/歌词轮询唯一实例）与 `UpNextFeedStore.shared`（日历数据唯一发布点）。
   轮询/调度只存在于 engine 与实体栏 upnext item，Mirror 侧无任何轮询入口。
2. **视图层**：`LyricsBarView` / `ScrubberBarView` 只做"订阅 + 渲染 + 动画 + 暂停门"，
   实例可任意多份，互不共享视图状态（KaraokeLabel 动画、marquee timer 各自独立）。
3. **容器层**：实体栏 item（`LyricsTouchBarItem` / `UpNextScrubberTouchBarItem`）与 Mirror host
   （`DesktopBarItemHost(item: nil, content: view, ...)`）各自持有一个视图实例；容器只负责生命周期、
   暂停广播与点击手势，不再承担渲染。

于是 §1 的根因（item = 视图 + 数据订阅 + 定时器）被拆掉：Mirror 拿到的是"第二个视图"而不是"第二个 item"。

## 3. 历史候选根因（Phase 1 前的排查记录，保留供追溯）

| # | 假设 | 证据 | 验证方式 |
| --- | --- | --- | --- |
| A | 歌词 item 在 Mirror 里被"暂停"冻住 | `marqueePauseGate` 初值 = 全局 `isBarHidden`；Mirror 的 `setPaused(false)` 若与 gate 初值一致会被 `guard 状态未变 else return` 短路 | 在 `LyricsTouchBarItem.setPaused` 打日志，对比 Mirror 打开瞬间的 gate 状态 |
| B | `DesktopBarItemHost` 约束把内容压成 0 宽 | host 只给 leading/trailing/centerY/height 四条约束，`LyricsTouchBarItem.view` 是 stackView，内部可能自带固定宽或 hugging 冲突 | 在 host 里打印 `content.frame` / `fittingSize` |
| C | 第二个 `LyricsTouchBarItem` 的 config 是副本，某些渲染开关没被 definition 覆盖 | `BarItemFactory` 对 lyrics 的 `LyricsItemConfig(copying: .shared)` | 打印 Mirror item 的 `config.displayMode/karakeStyle` 与实体栏对比 |
| D | 事件源单例只服务一个消费者（upnext 类） | Scrubber 持有 `NSBackgroundActivityScheduler`，事件源可能注册在单例上 | 看 `IUpNextSource` 注册/去重逻辑 |

> 结论：**不先拆"视图/数据"边界，逐个修只会按下葫芦浮起瓢。**（Phase 2 已按此结论落地）

## 4. 修复方案（分步，按风险从低到高）

### Phase 0（0.5 天，最小可交付）
给 Mirror 增加"诊断开关"：设置里一键打印每个 host 的 `content.frame`、`fittingSize`、
item 类型、paused 状态到 `~/Library/Logs/LyricsMTMR/mirror-diagnose.log`。
用真机跑一次，确认 §3 的 A/B/C 哪个命中。**没有这一步，后面都是猜。**
（Phase 1 已用快照兜底绕过；诊断开关未单独落地。）

### Phase 1（已实现 2026-11-14，Phase 2 后移除）—— 快照兜底
- `MTMR/Core/MirrorSnapshotPolicy.swift`：`shouldSnapshot(.lyrics/.upnext)` +
  `MirrorSnapshotView`（实体栏同 ID item 的 view 1Hz 快照，空白/无源显示占位）。
- 第二套实例对这两类 `setPaused(true)`，避免重复轮询。
- `MirrorSnapshotTests` 6 用例。
- **已知限制**：1Hz 静态刷新（不是逐字滚动）；实体栏未创建过该 item 时无快照可拍。
- **Phase 2 处理**：文件与测试已删除、pbxproj 注册已清理；镜像内改为同一数据源驱动的真实动画。

### Phase 2（已实现 2026-11-16）—— 共享数据源 + 每栏独立视图

落地内容：
- 数据层：`UpNextFeedStore.shared` 作为日历数据的唯一发布点；`LyricsEngine.shared` 保持唯一歌词数据源。
- 视图层：`LyricsBarView`、`ScrubberBarView`（只订阅 + 渲染 + 动画，无 scheduler）。
- 容器层：`LyricsTouchBarItem` / `UpNextScrubberTouchBarItem` 退化为薄容器；
  `TouchBarMirrorWindowController.makeHost` 用 `MirrorRenderPolicy` 直接创建视图实例，
  对 lyrics/upnext 不再创建第二套 item。
- 测试：`MTMRTests/MirrorDataSourceContractTests.swift` 9 用例（共享 engine、双实例独立滚动、
  暂停语义、store 扇出/订阅计数/不自行拉取、实体栏 item 唯一生产者、Mirror 路由策略、config 映射）。
- 迁移顺序按原计划：先 lyrics（单数据源）→ 再 upnext（NSScrollView + store），其余 32 个
  popover item 未迁（Phase 3 / 后续）。

验收对照：
- Mirror 中歌词由 `LyricsEngine.shared` 的 0.25s tick 驱动，每个 `LyricsBarView` 自己跑
  KaraokeLabel 30fps 扫描 + marquee timer，逐字滚动是实时的（不再是 1Hz 快照）。
- upnext Mirror 视图在打开时同步拿到 store 快照，之后随实体栏 item 的 60s 拉取更新；
  Mirror 打开不会新增 scheduler/EventKit 查询（`updateInvocations` 只随实体栏拉取 +1）。
- 暂停语义：实体栏隐藏只暂停实体栏视图；Mirror 显隐独立经 `host.pausable?.setPaused(...)` 广播。

**残余风险（Phase 2 已知）**：
1. 实体栏没有 upnext item（或 item 被销毁）时 store 为空：Mirror 显示本地化占位
   `日历无日程 / No events`（`ScrubberBarView(showsEmptyPlaceholder: true)`），不会显示陈旧列表。
2. 日历权限提示项（"点按授权"）在 Mirror 内只读展示——点击 action 绑定在实体栏 item 构建的
   `UpNextItem` 上，Mirror host 把整个视图当无 action 内容处理，点按不会触发授权。后续可给
   Mirror 的 upnext host 绑定 hint 的 singleTap action。
3. 同一 preset 内出现多个硬件 `upnext` item 时，它们仍各自持有一个 scheduler（Phase 2 前既有行为）；
   共享 store 以最后写入者为准。Mirror 本身不增加生产者。
4. 歌词的 marquee 相位/暂停门在两个视图间独立（这是"各自动画"的设计而非缺陷）；
   若要求严格同帧，需要把动画时钟也上移为共享状态（未做）。
5. 若实体栏从未创建 lyrics item（例如纯桌面栏用户），Mirror 的 `LyricsBarView` 依然订阅 engine，
   可正常显示；但 engine 本身的启停策略不在本卡范围。

### Phase 3（可选，产品面）
Mirror 独立预设与"跟随实体栏"两种模式共用同一渲染路径后，
可考虑让 Mirror 在没有 Touch Bar 的 Mac 上成为主界面（对标已归档的 Touch Bar Simulator）。
延伸项：
- 把其余 32 个 popover item 也拆成 view 层（`TBPopoverItem` 目前 Mirror 只取 collapsedRepresentation）；
- Mirror upnext 的授权提示可点按；
- 共享动画时钟（歌词 marquee 严格同帧）。

## 5. 验收标准（Phase 2 对照）

- [x] issue #46 关闭路径：lyrics + upnext 在 Mirror 中可见且随播放更新（同一数据源、独立视图）
- [x] 打开 Mirror 时轮询类组件请求不翻倍（Mirror 对这两类不再创建 item；测试断言 store 单次推送 / 视图零拉取）
- [ ] 实体栏隐藏/显示、Mirror 显示/隐藏 8 次组合，无卡死、无 empty Mirror（仍需真机验收；本卡只有 headless 测试）
- [x] 新增 `MirrorDataSourceContractTests` 9 用例，覆盖共享数据、暂停语义、唯一生产者与重定向策略
- [x] 本文件 §2 的 6 处耦合在修复后逐条消失或写明"保留原因"：
  1. 重复轮询 → 消失（Mirror 不建 item/scheduler，store 只发布）；
  2. 暂停语义分裂 → 收敛为 `host.pausable` 单入口（item 或 view 二选一）；
  3. item.view 被 host 改父视图 → 视图层自带约束（stackView 贴边），不再依赖 item 的隐式尺寸；
  4. identifier 被改写 → 共享视图不走 identifier 分支（无 item）；
  5. popover item → 未迁移（保留原因：Phase 2 范围只含 lyrics/upnext，见 Phase 3）；
  6. `usesSharedLyricsConfiguration` 副本语义 → 保留，但映射收敛到 `BarItemFactory.lyricsConfig`，
     Mirror 恒传 `shared: false`（只读副本）。

## 6. 关联

- 上一轮体检：`docs/调研_bar-control相似工作与可借鉴点.md`（bar-control 的 `TouchBarPresentationPolicy`
  把"呈现/让位/自愈"拆成纯函数，是 Phase 2 容器层可直接借用的写法）
- issue #46、PR #47（"待硬件验收：实体栏多指手势、所有第三方服务组件"）
