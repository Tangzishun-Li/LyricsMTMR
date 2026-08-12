# 评估报告：第8轮 · ITER-15 镜像窗事件驱动刷新可行性

- 任务：t_f5def9e7（第 8 轮 / 子任务 D，research-agents）
- 分支：r8/iter15（基于 main=9cac48d）
- 性质：只读调研，未改动任何源码；交付本报告 + iteration-log 记录
- 结论速览：**有条件值得实现**——采用「事件驱动即时刷新 + 低频轮询兜底」的叠加方案，
  最小方案约 6 处订阅 + 1 处轮询降频；但收益仅在用户实际开启镜像窗时体现，
  是否实施以使用场景确认为第一决策门（与第 6 轮搁置原因一致）。

---

## 一、镜像窗当前实现与刷新机制（代码定位）

镜像窗 = `TouchBarMirrorWindowController`（LyricsMTMR/MTMR/Core/TouchBarMirrorWindowController.swift），
一个底部居中的 NSPanel（高 34pt，level=.floating），用 NSStackView 复刻 Touch Bar 当前布局的全部 item 视图。

### 1.1 刷新主链路：10Hz 定时轮询（唯一常驻驱动）

| 环节 | 位置 | 说明 |
|---|---|---|
| syncTimer | TouchBarMirrorWindowController.swift:109-114 | `Timer.scheduledTimer(0.1s, repeats: true)` → 每 tick 调 `syncFromTouchBar()`；仅 `show()` 启动（:48/:95），`hide()` invalidate（:99-100） |
| syncFromTouchBar | :128-210 | 每 tick 做三件事：① 布局结构对齐（item \| separator 序列 diff）；② 指纹比对（未变视图原地保留）；③ 快照类 item 按节流点重建 |
| syncTick 计数 | :17/:132 | 快照节流的相位计数器；ITER-11 起 `show()` 时归零（:44），使每次显示后的节流节奏可预期 |

### 1.2 三层历史优化叠加（当前形态 = OPT-17 + ITER-3 + ITER-9 + ITER-11 + FIX-1）

- **OPT-17 增量同步**（996fc5b，第 1 轮）：`ItemFingerprint` 指纹缓存（:11/:226-245），
  指纹未变的 item 视图原地保留，取代 OPT 前「每 0.1s 全量清空 stackView 重建全部 NSView」。
  指纹覆盖三类：按钮（imageRef+attributedTitle+width）、歌词（文本+width）、GroupBar（标签）。
  有单测：MTMRTests/MirrorFingerprintTests.swift（ITER-6 补）。
- **ITER-3 快照节流**（86a207e，第 2 轮）：无低成本指纹的快照类 item
  （AppScrubber / 音量 / 亮度 / 自定义视图，`fingerprint(of:)` 返回 nil，:288-303）禁止每 tick 重截位图，
  只在节流点重建。
- **ITER-9 自适应节流**（316cce6，第 3 轮）：节流间隔随快照类 item 数量自适应——
  0-1 个 → 5 tick（0.5s）；2 个 → 7 tick（0.7s）；≥3 个 → 10 tick（1s）（:22-28，:141-144）。
- **FIX-1 语义底线**（15b8512 / PR #19）：快照类**绝不永久冻结**——只在节流点重建，
  同时修复指纹变化分支的双重重建（改用 `makeView(for:)` 带 identifier）。
- **ITER-11**（316cce6）：syncTick 显示归零（见 1.1）。

### 1.3 已有的事件驱动部分（现状并非纯轮询）

`syncFromTouchBar()` 已有两个事件驱动调用点，覆盖「布局增删/换序」：

- TouchBarController.swift:438-441 —— `prepareTouchBar()`（配置重载 / 主题切换 / 槽位切换等布局重建后）异步触发；
- TouchBarController.swift:749-752 —— `presentTouchBarWithCurrentItems()`（切应用快速路径）异步触发。

代码注释（TouchBarMirrorWindowController.swift:127）明确写着
「布局增删/换序时 TouchBarController 已事件驱动调用本方法，无需依赖高频轮询」——
即结构对齐已由事件覆盖，**轮询目前的实质工作是：内容级变化检测（歌词行/按钮文本）+ 快照类重建**。

---

## 二、候选事件源清单（信号在代码中是否已存在）

镜像窗内容级变化可分三类：歌词/按钮等可指纹内容、快照类内容、以及它们的配置变化。
逐一核对现有信号：

| # | 事件 | 现有信号（代码位置） | 可挂接性 |
|---|---|---|---|
| E1 | 歌词行变化（含歌词对象/翻译/罗马音/点击模式切换） | `LyricsEngine.$currentLineIndex / $currentLyrics / $translationLyrics / $romajiLyrics / $clickAction`（LyricsEngine.swift:443 等，Combine @Published）；`scheduleLineCheck()` 已事件驱动行切换（:1066-1096） | ✅ 现成。LyricsTouchBarItem 已用同一 Combine 链驱动渲染（LyricsRendering/LyricsTouchBarItem.swift:139-187），镜像窗照抄订阅即可 |
| E2 | 播放状态变化（播放/暂停/停止） | MediaRemote 回调 → `mrAdapter.onPlaybackStateReceived`（LyricsEngine.swift:570-581）→ `handlePlaybackState` → 写入 `trackInfo.playbackState`（@Published） | ✅ 现成（经 $trackInfo） |
| E3 | 播放进度变化 | `playbackTimer` 0.25s 更新 `trackInfo.playbackTime`（LyricsEngine.swift:711-726，仅播放中运行） | ⚠️ 现成但**不需要**——镜像窗歌词显示的是行文本（`KaraokeLabel.attributedStringValue.string`，MirrorWindowController.swift:387-399），无 karaoke 扫光/进度动画；进度变化不影响任何指纹。若直接订阅 $trackInfo 全量反而引入 4Hz 无意义唤醒，必须过滤 |
| E4 | 窗口显隐 | `show()/hide()` 本身即事件（StatusBarMenuView.swift:74 toggle；GeneralTabView.swift:63-65；isVisible didSet → AppSettings.showMirrorWindow :30-32） | ✅ 已事件驱动：show() 立即 `syncFromTouchBar()` + syncTick 归零（:94），不依赖轮询 |
| E5 | Touch Bar 布局/配置变化 | `prepareTouchBar()` / `presentTouchBarWithCurrentItems()` 已调 sync（TouchBarController.swift:438-441/:749-752）；另有一批现成通知：`.lyricsItemConfigDidChange`（LyricsItemConfig.swift:85）、`.themeIndexDidChange` / `.appThemeAutoSwitchDidChange`（AppSettings.swift:4-5/:167、TouchBarController.swift:575）、`.settingsProfileImported`（SettingsSync.swift:185）、`didSwitchSlotNotification` / `didChangeSlotsNotification`（SlotManager.swift:185/:452） | ✅ 布局已挂；内容级配置通知现成，镜像窗尚未订阅（UserDefault wrapper 无 KVO，AppSettings.swift:241-254，只能靠这些显式通知） |
| E6 | 前台 App 变化（AppScrubber / Dock 内容） | AppScrubberTouchBarItem 已订阅 `NSWorkspace.shared.notificationCenter`：didLaunchApplication / didTerminateApplication / didActivateApplication（Widgets/System/AppScrubberTouchBarItem.swift:34-36） | ✅ 现成（iteration-plan.md:238 的 ITER-15 原案即指此）。事件在 item 内部，镜像窗可自行再订阅同一通知 |
| E7 | 音量变化 | VolumeViewController 用 CoreAudio 事件：`AudioObjectAddPropertyListenerBlock`（默认输出设备 / 音量变化，Widgets/System/VolumeViewController.swift:21-40 附近） | ✅ 现成（item 内部），需转发或镜像窗自建 listener |
| E8 | 亮度变化 | **无系统事件源**——BrightnessViewController 自带 `Timer`（refreshInterval 轮询，Widgets/System/BrightnessViewController.swift:26-31） | ❌ 无事件可挂，只能靠轮询兜底 |
| E9 | 日历事件（UpNext item） | `EKEventStoreChanged` 通知（UpNextScrubberTouchBarItem.swift:226） | ✅ 现成（item 内部） |
| E10 | 其他自定义视图（脚本按钮 TBPollItem / 时钟等持续变化视图） | 无统一信号；item 各自内部 timer 更新 | ❌ 无事件可挂（镜像窗显示其位图快照），只能靠轮询兜底 |

**小结**：歌词（E1）、播放状态（E2）、布局（E5）、前台 App（E6）、音量（E7）均有现成信号可挂；
进度（E3）不需要挂；亮度（E8）与自定义视图（E10）无事件源，必须保留轮询兜底。

---

## 三、与现有轮询+自适应的关系：替代 / 叠加 / 补充？

### 3.1 三种候选形态

- **A 纯事件驱动（替代轮询）**：不可行。E8/E10 无事件源，且未来新增 item 类型若漏挂事件
  → 镜像永久陈旧（正是 FIX-1 反对的语义）；事件遗漏风险不可完全枚举。
- **B 事件触发 + 轮询兜底（叠加）**：事件到达立即 sync 一次（快照类可跳过节流立即重建），
  轮询降频至 1Hz（1s）作兜底，覆盖无事件源 item 与潜在事件遗漏。✅ **推荐**。
- **C 仅补充（保持 10Hz + 事件再加一次）**：收益只有延迟 0.1s→即时，CPU 不减反可能微增，不划算。

### 3.2 收益分析（相对现状 10Hz 轮询）

| 维度 | 现状 | 方案 B 后 | 说明 |
|---|---|---|---|
| 歌词行变化延迟 | ≤100ms（轮询周期） | ~即时（Combine 链同帧，<16ms） | 歌词是镜像窗最高频内容；跟唱场景有感知 |
| sync 调用频率 | 10Hz 恒定（常驻唤醒） | 播放中 ~0.3-1Hz（行切换+状态变化+布局）；空闲 0 次事件 + 1Hz 兜底 | 事件驱动后主线程周期唤醒减少 ~80-90% |
| CPU（镜像窗开启时） | 每 tick 全量指纹比对 + 结构对齐（轻量，估计 <0.5ms/tick → ~5ms/s） | 事件驱动为主 + 1Hz 兜底 | 省的是周期唤醒与比对次数，非单次成本 |
| 电量 | 0.1s runloop 周期唤醒 | 空闲近零唤醒 | 镜像窗默认关闭（AppSettings.swift:156-157 `defaultValue: false`），收益仅在开启时存在 |
| 快照类 item 实时性 | 节流 0.5-1s | 有事件源（E6/E7）时即时，无事件源维持节流 | AppScrubber 切换 App 后 Dock 立即更新（当前最坏等 1s） |

### 3.3 成本分析

| 成本 | 评估 |
|---|---|
| 复杂度 | 中。约 6 处订阅：E1 Combine 链（需过滤 $trackInfo 的进度-only 变化，只取 playbackState/title/artwork 变化）、E5 三个通知、E6 NSWorkspace、E7 CoreAudio（或复用 item 内部回调转发）；外加 1 处轮询降频 10Hz→1Hz；去抖合并（见 3.4）。全部复用现有 `syncFromTouchBar()` 单入口，不重写对齐逻辑 |
| 事件遗漏风险 | 中低。E8/E10 无事件源 → 兜底 1Hz 覆盖；新增 item 类型漏挂 → 兜底同样覆盖（最多 1s 陈旧，优于现 0.5-1s 节流的同量级）。相比纯轮询的唯一新增风险是「本可即时的事件延迟到兜底 tick」，可接受 |
| 状态同步竞态 | 低。所有事件源均落在主线程（Combine `receive(on: .main)`、NotificationCenter 默认 main、NSWorkspace/CoreAudio 回调已 hop main，Timer main runloop）→ `syncFromTouchBar()` 天然串行，无跨线程竞态 |
| 双重刷新 | 低。事件触发与兜底 tick 可能同帧重复 sync → 指纹比对幂等（第二次发现未变即跳过），仅多一次轻量比对 |
| 测试 | 指纹语义已有单测（MirrorFingerprintTests）；事件订阅为集成行为，可补「事件→sync 触发」的轻量单测或依赖现有 60 用例回归 |

### 3.4 去抖（防事件风暴）设计要点

- 音量拖动（E7）可能连续触发 → 100ms 合并（Timer/DispatchWorkItem 防抖，只保留最后一次）。
- 播放状态/歌词行切换低频（行切换 ~1 行/3-5s），无需防抖，但可共用同一「合并到下一帧」入口。
- 关键约束：**不要订阅 $trackInfo 全量**（4Hz 进度更新会白送唤醒）；只对
  playbackState / title / artwork 变化触发。

---

## 四、风险清单

1. **事件遗漏 → 镜像陈旧**：亮度（E8）、自定义视图（E10）无事件源；未来新 item 漏挂事件。
   缓解：1Hz 兜底轮询（陈旧上限 1s）+ 保留 ITER-3/9 快照节流语义（兜底 tick 仍按节流重建）；
   在代码注释与维护文档登记「新 item 类型必须评估镜像窗事件源」约定。
2. **事件风暴**：音量/进度类连续事件。缓解：100ms 防抖 + 只订阅必要信号（3.4）。
3. **线程/主线程抖动**：快照重建（位图 cacheDisplay/render，MirrorWindowController.swift:412-442）
   在主线程执行，事件触发「跳过节流立即重建」若在短时间内多次发生（如连续切 App），
   单次 ~ms 级、可接受；但建议事件触发时仍只重建「有事件源的对应 item」，快照类维持节流上限
   （与 ITER-15 原案「事件触发跳过节流」稍有差异——原案针对 AppScrubber 单一 item，
   展开到全镜像窗后应限制重建范围，避免把节流的保护作用全部取消）。
4. **回归风险**：轮询从 10Hz 降 1Hz 后，若事件订阅遗漏某条路径，旧态由兜底覆盖；
   需回归验证「播放中歌词滚动」「切 App Dock 变化」「音量/亮度拖动」「配置热重载」
   四条主路径在镜像窗开启时的表现。60 用例单测不受影响（指纹逻辑未动）。

---

## 五、结论建议

### 5.1 是否值得实现：有条件值得

- 镜像窗**默认关闭**（AppSettings.swift:156-157），全部收益只在用户开启时存在——
  这正是第 6 轮搁置（「需使用场景确认」）的原因，本评估维持该判断。
- 若确认使用场景（见 5.3），方案 B（事件驱动 + 1Hz 兜底）收益明确：
  歌词延迟 0.1s→即时、镜像窗开启期间的 sync 唤醒减少 ~80-90%、
  AppScrubber/音量从最坏 1s 陈旧变为即时；成本集中在 6 处订阅 + 防抖，复用现有
  `syncFromTouchBar()` 单入口，不触碰指纹/节流/增量同步的既有语义（单测可保）。
- 若确认用户极少使用镜像窗 → 维持现状（10Hz 轮询只在开启时消耗，关闭时零成本），
  不值得为低频路径引入复杂度。两种结论都成立，取决于 5.3 的问题。

### 5.2 建议的实施范围（最小方案，若实施）

1. 镜像窗订阅 E1：`engine.$currentLineIndex` + `$currentLyrics` + `$translationLyrics` +
   `$romajiLyrics` + `$clickAction`（沿用 LyricsTouchBarItem.swift:159-186 同款 Combine 链）→ 触发 `syncFromTouchBar()`；
2. 镜像窗订阅 `$trackInfo`，但仅当 `playbackState` / `title` / `artwork` 变化时触发（过滤进度-only 变化，防 4Hz 空唤醒）；
3. 订阅 `.lyricsItemConfigDidChange` / `.themeIndexDidChange` / `.appThemeAutoSwitchDidChange` /
   `.settingsProfileImported` / 槽位切换通知（E5）→ 触发；
4. 订阅 `NSWorkspace` 三个前台 App 通知（E6）→ 触发，且 AppScrubber 快照可立即重建（原 ITER-15 案）；
5. 音量事件（E7）：优先复用 VolumeViewController 现有 CoreAudio listener 转发（避免双 listener）；
6. 事件入口统一加 100ms 防抖合并；
7. 轮询 10Hz → 1Hz 兜底（保留 ITER-3/9 节流语义：兜底 tick 才按数量自适应重建快照类；
   事件触发的 sync 中，快照类仅对「事件对应的 item」跳过节流，其余仍按节流）。
8. 范围外（明确不做）：不给亮度/自定义视图造事件源；不重写结构对齐；不改指纹与增量同步语义。

### 5.3 需要用户确认的使用场景问题清单（决策门）

1. **是否实际开启使用镜像窗？开启频率如何（常驻 / 偶尔 / 几乎不用）？**
   —— 不用则整个 ITER-15 不值得做，直接关闭本项。
2. **主要用途是什么**：歌词跟唱（实时性敏感，事件驱动收益最大）？
   演示/录屏（延迟无所谓，10Hz 轮询已够）？还是镜像 Touch Bar 控制按钮（按钮文本变化低频）？
3. **快照类内容（Dock 切换 / 音量 / 亮度）的实时性要求**：当前 0.5-1s 节流是否可接受？
   若不可接受，事件驱动对 Dock（E6）与音量（E7）可即时化，但亮度（E8）仍只能轮询。
4. **对电量/CPU 的敏感度**：镜像窗若常驻 + 外接显示器场景，是否值得为此引入
   「6 处订阅 + 防抖 + 兜底降频」的复杂度？（收益即 5.2 所列，代价是维护面增加与 4.3 的回归面）

---

## 六、参考

- 代码：`LyricsMTMR/MTMR/Core/TouchBarMirrorWindowController.swift`（全文，471 行）；
  `TouchBarController.swift:438-441/:749-752`；`LyricsEngine.swift:443/:570-581/:711-726/:1066-1096`；
  `LyricsRendering/LyricsTouchBarItem.swift:139-187`；`Widgets/System/AppScrubberTouchBarItem.swift:34-36`；
  `Widgets/System/VolumeViewController.swift`（CoreAudio listener）；`Widgets/System/BrightnessViewController.swift:26-31`；
  `MTMR/App/AppSettings.swift:4-5/:156-157/:167`；`LyricsIntegration/LyricsItemConfig.swift:85`；
  `Preferences/SlotManager.swift:185/:452`；`Preferences/SettingsSync.swift:185`；
  测试：`LyricsMTMR/MTMRTests/MirrorFingerprintTests.swift`。
- 历史：OPT-17 增量同步（996fc5b）、ITER-3 快照节流（86a207e）、ITER-9/11 自适应+归零（316cce6）、
  FIX-1 冻结修复（15b8512 / PR #19）。
- 文档：`docs/iteration-plan.md`（ITER-15 定义 :238-248，收口结论 :393/:406）；
  `backup/定时器与刷新循环调研报告.md`（镜像窗章节 :35-36/:65/:89，优化建议第 6 条「增量 diff 或
  事件驱动」——增量 diff 已由 OPT-17 落地，事件驱动为本评估主题）；
  `backup/性能优化总报告_v2_三路汇总与实施路线图.md`（无镜像窗专属章节，C1 切应用快速路径相关）。

*本报告为唯一交付物；未创建/修改任何源码文件。*
