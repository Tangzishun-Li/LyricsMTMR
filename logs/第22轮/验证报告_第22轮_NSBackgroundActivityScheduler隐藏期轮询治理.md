# 验证报告_第22轮_NSBackgroundActivityScheduler隐藏期轮询治理

- 轮次：第 22 轮（功能/优化迭代第 10 轮）· 子任务 A（实现/优化维度）
- 任务卡：t_5621d8ad（分支 r22/feature，工作区 `.worktrees/round22-A`，基于 main@b46116b）
- 落地目标：全库最后 4 个用 `NSBackgroundActivityScheduler` 自驱动轮询的 widget（CurrencyBarItem / WeatherBarItem / YandexWeatherBarItem / UpNextScrubberTouchBarItem）纳入第 18~21 轮「隐藏期零空转」治理主线——bar 隐藏（黑名单 app / exitTouchbar）期间零网络请求（UpNext 为零 EventKit 查询），恢复后按原节奏继续轮询并立即补刷
- 日期：2026-08-13

---

## 〇、结论速览

| 项 | 结论 |
|----|------|
| 问题 | **成立**：全库 4 个 widget 用 `NSBackgroundActivityScheduler` 自驱动轮询（`grep -rn NSBackgroundActivityScheduler` 仅命中这 4 文件），均未 conform `TBPollPausable`、不在 `TouchBarController.setPollingPaused` 广播体系内（:762-769 仅遍历 items/swipeItems 对 `TBPollPausable` 广播）——隐藏期间调度器仍按 interval 触发网络请求，与第 18~21 轮治理主线（其余 ~30 项 Timer/自循环/采集链均已纳入）不一致 |
| 方案 | **门控回调（gate the callback）**，非 invalidate+重建：调度器保持存活，每次触发经新增 `pollTick()` 过 `TBPauseGate` 门——隐藏期触发零工作（不发请求），恢复后调度器按原 interval 继续 + `setPaused(false)` 立即补刷一次。invalidate+重建被否决（同 identifier 重复注册风险 + 快速切换竞态，见二章） |
| 等价性 | 未隐藏时严格等价：调度器参数/触发路径零改动（仅块内先过门再走原方法）、初始 fetch 时机不变、completion(.finished) 无条件调用、广播幂等（gate 变更检测）、竞态串行主线程 hop + 状态复查；行为差异仅「整条 bar 隐藏期间调度器触发被门拦截」一处（即目标本身） |
| 顺带修复 | CurrencyBarItem / WeatherBarItem 的 schedule 块原强捕获 self（item→activity→block→item 保留环 → 项重建后旧 item 永不释放且调度器持续轮询），本轮一并弱化为 `[weak self]`（与 Yandex/UpNext 原有写法一致）——新增 3 个泄漏回归测试钉死 |
| 实证 | 分支内 xcodebuild build **BUILD SUCCEEDED** + test **TEST SUCCEEDED —— 181 用例 0 失败 0 意外**（172 基线 + 新增 9 全过，金丝雀锚点 testGoldenAnchors2026/2027/Makeup2026 全绿，WidgetLeakTests 8 用例全绿无泄漏；leak 测试中 fire-and-forget 网络尝试 -1003 无影响，同 round-20 先例） |
| 遗留 | 真机冒烟延续挂账（隐藏期流量/请求实证、恢复补刷观感依赖 Touch Bar 真机）；隐藏期重建 item 的 init 单次 fetch 为配置变更事件请求（边界说明见 3.4） |

---

## 一、实证：4 个 scheduler widget 与治理主线的缺口

### 1.1 缺口成立（grep 实证，main@b46116b）

```
$ grep -rn "NSBackgroundActivityScheduler" --include="*.swift" -l
./LyricsMTMR/MTMR/Widgets/Life/YandexWeatherBarItem.swift
./LyricsMTMR/MTMR/Widgets/Life/CurrencyBarItem.swift
./LyricsMTMR/MTMR/Widgets/Life/WeatherBarItem.swift
./LyricsMTMR/MTMR/Widgets/Media/UpNextScrubberTouchBarItem.swift
```

全库仅此 4 处。逐一核查：

| widget | 调度器 | 网络/查询目标 | schedule 块捕获 | 触发入口（隐藏期仍活跃） |
|--------|--------|----------------|------------------|--------------------------|
| CurrencyBarItem（:72-106） | `"<id>.updatecheck"` interval 来自配置 | Coinbase 汇率 `api.coinbase.com` | **强 self**（保留环） | 调度器定时触发 |
| WeatherBarItem（:45-104） | 同上 | OpenWeather / 中国天气网 | **强 self**（保留环） | 调度器 + `CLLocationManager` 定位回调（didUpdateLocations → updateWeather、didChangeAuthorization）+ china 模式反地理编码 |
| YandexWeatherBarItem（:38-60） | 同上 | `yandex.ru/pogoda` 页面 | weak self（round-20 B 已修） | 调度器 + 定位回调 + 授权变更 |
| UpNextScrubberTouchBarItem（:36-60） | `"<id>.updateCheck"` 固定 60s（BarItemFactory :115） | EventKit 事件查询（本地数据库，无网络但同为周期性工作） | weak self | 调度器 + `EKEventStoreChanged` 通知 |

- 4 者均**未**声明 `TBPollPausable`（`grep TBPollPausable` 26 文件 62 处命中无这 4 个）→ `TouchBarController.setPollingPaused`（:762-769）广播到不了它们；
- `NSBackgroundActivityScheduler` 的触发与 app 前台状态/bar 显隐无关（系统级后台活动调度器）——黑名单 app 在前台或 exitTouchbar 后，调度器仍按 interval 触发块 → 网络请求持续发出（Coinbase/Yandex/天气为真实出网，UpNext 为周期 EventKit 查询 + 视图重建）。

### 1.2 隐藏期语义（改动前）

`dismissTouchBar` → `setPollingPaused(true)` 对 4 者零效果；`presentTouchBar` → `setPollingPaused(false)` 同样零效果。第 18 轮（TBPollPausable 协议 + 广播）、第 19/20 轮（8+8 项 Timer 迁移 TBPausableTimer/TBPauseGate）、第 21 轮（AudioSpectrum 采集链 capturePauseGate）覆盖了 Timer 自循环与采集链，**scheduler 自驱动类是最后的治理缺口**——本卡收口。

---

## 二、方案取舍：门控回调 vs invalidate+重建

`NSBackgroundActivityScheduler` 公开 API 无 pause/resume，只有 `invalidate()`（一次性作废，不可复用）。两条候选路径评估：

| 维度 | A. 门控回调（**选用**） | B. invalidate+重建 |
|------|------------------------|--------------------|
| 隐藏期网络请求 | **零**（块内过门即返回，completion 照常） | 零（调度器不存在），但**在途块无法取消**——块已开始执行时 invalidate 不中断它 → 仍须门控兜底，即 B 必然叠加 A |
| 线程安全 | `TBPauseGate` NSLock 保护，scheduler 块跑在系统队列读门、广播主线程写门，无生命周期竞态 | 重建调度器需跨线程协调（块可能在任意队列执行、invalidate 从主线程来），快速 pause/resume 序列下「旧 identifier 尚未注销、新实例已 schedule」竞态窗口真实存在 |
| 同 identifier 重复注册 | 不存在（从不重建） | `NSBackgroundActivityScheduler` 以 identifier 注册到系统层；invalidate 的注销是异步的，同 identifier 紧邻重建有「already registered」报错/静默失败风险（Apple 文档：重复注册同 identifier 的新活动会被拒绝）——失败即 widget 永久停更，属正确性回归 |
| 重复广播幂等 | gate 变更检测天然幂等（round 19 起全库统一模式） | 每次 setPaused(false) 重建一个新调度器实例，重复 present 广播会连环重建（须额外防抖） |
| 隐藏期空转面 | 调度器仍按 interval 触发（一个锁读 + 布尔判断 + completion 调用，微秒级，无网络/IO/查询——与第 18~21 轮「停工作不停心跳」的语义一致：Timer 类 widget 隐藏期 invalidate 零触发，但 scheduler 是系统级组件，其触发开销由系统合并/延迟调度，不可控也不构成空转） | 零触发 |
| 隐藏期 source/setting 变更 | 天然正确：gate 保持，变更经重建 item（见 3.4）广播同步补暂停 | 重建窗口内变更与调度器生命周期交错，需额外状态机 |
| 代码量/风险 | 每 widget +1 gate +2 方法 +1 行块改造，模式与 round 19~21 完全一致 | 每 widget 重写调度器生命周期，风险面大 |

**结论**：门控回调是唯一同时满足「隐藏期零网络请求」硬指标与线程安全/幂等/无正确性回归的方案；invalidate+重建的「零触发」额外收益不构成资源意义（微秒级 no-op），却引入 identifier 注册竞态与重复广播连环重建两个正确性风险，否决。这与 round 21 AudioSpectrum 治理的形态一致（第 21 轮也是「事件源保持、出口门控」——SCK stream 是停掉而非门控，但其重启路径有仓库内生产实证且无注册竞态；scheduler 无等价的安全重启路径，故门控）。

---

## 三、变更明细（4 文件 + 2 测试文件；TouchBarController 零改动）

### 3.1 CurrencyBarItem.swift（Widgets/Life/）

1. 类声明加 `TBPollPausable`（:12）；
2. 新增 `private let pollGate = TBPauseGate()`（:26，附注释）；
3. schedule 块改 `[weak self]` + 调 `pollTick()`（:108-111）——**顺带修复保留环**（原 `self.updateCurrency()` 强捕获：item→activity→block→item 循环，deinit 不可达 → 预设重载后旧 item 连同调度器永驻并持续轮询）；
4. 新增 `pollTick()`（:121-126）：`guard !pollGate.isPaused else { return }` 后走 `updateCurrency()`——scheduler 触发入口，隐藏期拦截；
5. 新增 `setPaused(_:)`（:130-142）：gate 变更检测（重复广播幂等）→ 恢复时主线程 hop + 状态复查（快速 pause/resume 最后一次状态为准）→ 立即 `updateCurrency()` 补刷；
6. `updateCurrency()` 顶部加 `guard !pollGate.isPaused`（:167）——兜底覆盖所有入口（补刷/任何外部调用），隐藏期任何入口零出网。

### 3.2 WeatherBarItem.swift（Widgets/Life/）

1. 类声明加 `TBPollPausable`（:15）；
2. 新增 `pollGate`（:23-28，注释）；
3. schedule 块 `[weak self]` + `pollTick()`（:107-110）——同样修复保留环；
4. 新增 `pollTick()`（:130-135）、`setPaused(_:)`（:139-151，主线程 hop + 复查 + 补刷）；
5. `updateWeather()` 顶部 guard（:152）——覆盖调度器/补刷/**定位回调**（didUpdateLocations :229、didChangeAuthorization :265）/china 城市切换（tap :76-79）全部入口；
6. `resolveLocationCity()` 顶部 guard（:273）——反地理编码走 Apple 网络服务（CLGeocoder），隐藏期同样拦截；恢复后用最新已知定位补刷。

### 3.3 YandexWeatherBarItem.swift（Widgets/Life/）

1. 类声明加 `TBPollPausable`（:12）；
2. 新增 `pollGate`（:37-43，注释）；
3. schedule 块改调 `pollTick()`（:63-66，原已 `[weak self]` 不动）；
4. 新增 `pollTick()`（:87-92）、`setPaused(_:)`（:96-108）；
5. `updateWeather()` 顶部 guard（:109）——覆盖调度器/补刷/定位回调（:133/:143）全部入口。

### 3.4 UpNextScrubberTouchBarItem.swift（Widgets/Media/）

1. 类声明加 `TBPollPausable`（:13）；
2. 新增 `pollGate`（:20-25，注释）；
3. 原 6 参 init 改 `convenience`（:41-44），委托新增 7 参 designated init（:49-50，`eventSources: [IUpNextSource]? = nil` 测试缝）——`eventSources == nil` 生产路径与原先逐字节等价（默认创建 `UpNextCalenderSource`）；显式传入时跳过真实 EventKit 源（单测不触发 TCC 日历授权弹窗）；
4. schedule 块改调 `pollTick()`（:75-78，原已 `[weak self]`）；
5. 新增 `pollTick()`（:92-97）、`setPaused(_:)`（:101-113）；
6. `updateView()` 顶部 guard（:114）——覆盖调度器与 `EKEventStoreChanged` → `updateCallback` → updateView 事件入口（隐藏期零 EventKit 查询、零视图重建；恢复 setPaused(false) 统一补刷）。

### 3.5 隐藏期 source/setting 变更的延迟处理（边界说明）

这 4 个 widget 的 source/setting（币种对/城市/interval）均为 init 捕获的不可变配置，无运行时热更新路径——设置变更 = `createAndUpdatePreset` → `createItems()` 全量重建 item：

- 旧 item：`discardCurrentItems` 释放引用 → deinit → `activity.invalidate()`（既有逻辑；保留环修复后 deinit 真正可达，旧调度器停止触发）；
- 新 item：init 时 gate 默认未暂停 → **初始 fetch 执行一次**（配置变更事件触发的单次请求，非轮询空转——与第 19~21 轮重建 item 的初始行为完全一致）；随后 `updateActiveApp()` 在同一 runloop 周期内同步广播 `setPollingPaused(true)`（黑名单前台场景）→ 新 item 的 gate 立即置暂停 → 此后调度器触发全部被门拦截。两次广播之间无调度器触发窗口（首次触发 ≥ interval 之后，远大于广播间隔）。

### 3.6 广播接线（零改动验证）

`TouchBarController.setPollingPaused`（:762-769）遍历 `items.values` + `swipeItems` 对 `TBPollPausable` 广播——4 个 widget conform 后自动纳入，TouchBarController 无任何改动（`git diff` 确认零命中）。

---

## 四、等价性论证

| 行为面 | 改动前 | 改动后（未隐藏时） |
|--------|--------|--------------------|
| 调度器注册 | identifier + interval + repeats + QoS | 逐字节相同（Currency/Weather 块捕获由强转弱，调度参数不变） |
| 触发频率 | 系统按 interval 调度块 | 相同；块内先过门（未暂停恒过）再走原方法 |
| completion | 块末无条件 `completion(.finished)` | 相同（含被门拦截时也调用——活动正常结束，不向系统标记 deferred） |
| 初始 fetch | init 末尾执行一次 | 相同（gate 默认未暂停） |
| 定位/授权/EventKit 事件入口 | 直接执行更新 | 相同（未隐藏时 guard 恒通过） |
| 补刷 | 无此概念（恢复时数据可能是整个隐藏期前的旧值） | 恢复立即补刷一次——严格改进（隐藏期可能数小时，币价/天气/日历均已过期） |
| 广播幂等 | 无广播可收 | gate 变更检测：重复 setPaused 同值 no-op；从未暂停 item 收 setPaused(false) 零副作用 |
| 竞态 | 无并发状态 | 恢复补刷经主线程 hop + gate 复查，快速 pause/resume 最后一次状态为准（同 TBPausableTimer/AudioSpectrum round-21 模式） |
| 内存 | Currency/Weather 保留环泄漏（预设重载即泄漏一个 item + 调度器） | 环已断，deinit 可达 → invalidate → 随项回收（严格改进，3 个泄漏测试钉死） |

行为差异汇总：① 整条 bar 隐藏期间调度器触发被门拦截（零网络/零查询）——目标本身；② 恢复时立即补刷一次；③ Currency/Weather 保留环修复。其余全等。

---

## 五、单测清单（+9：PausableTimerTests +6、WidgetLeakTests +3）

沿用既有测试文件（第 19~21 轮惯例），无需 add_files.py 注册。测试基建：文件级共享计数子类（override 网络/EventKit 入口计数，不触碰真实请求/权限；`CountingUpNextSource` 为 `IUpNextSource` 假源）；测试实例 interval=3600（真实系统调度器在测试生命周期内绝不触发，`pollTick()` 直驱即调度器块本体）；`CountingWeatherItem` 用 china+city 模式（无 CLLocationManager），`CountingYandexItem` 与 Weather 均 override 定位 delegate 三方法中和异步定位噪声。

| 用例 | 验证点 |
|------|--------|
| `testCurrencyItemPauseFreezesPollAndResumeRefreshes` | init 恰 1 次 fetch → setPaused(true) 后两次 pollTick 零计数 → setPaused(false) 立即补刷恰 1 次，且不再多刷 |
| `testWeatherItemPauseFreezesPollAndResumeRefreshes` | 同上（china+city 构造） |
| `testYandexItemPauseFreezesPollAndResumeRefreshes` | 同上（delta 断言——init 计数随定位授权环境 0/1，不依赖绝对值） |
| `testUpNextItemPauseFreezesPollAndResumeRefreshes` | 假源 queryCount：init 1 次 → 隐藏期 pollTick 零查询 → 恢复立即补刷 1 次 |
| `testSchedulerWidgetsPauseBroadcastIsIdempotent` | 4 widget 联合：未暂停 item 收 setPaused(false) 零副作用、重复 dismiss 广播不双停、隐藏期 pollTick 全被门拦截、首次恢复各恰补刷 1 次、重复 present 广播不再刷 |
| `testCurrencyRapidPauseResumeSkipsStaleResumeRefresh` | pause→resume→再 pause（hop 落地前）：陈旧补刷 hop 被 gate 复查丢弃；最终 resume 恰补刷 1 次 |
| `testCurrencyBarItemDoesNotLeak`（WidgetLeakTests） | 保留环修复回归：建/释后 weak 为 nil（改动前强捕获 → 本用例失败） |
| `testWeatherBarItemDoesNotLeak`（WidgetLeakTests） | 同上 |
| `testUpNextScrubberDoesNotLeak`（WidgetLeakTests） | 注入假源构造（无 EventKit 授权弹窗），建/释后 weak 为 nil |

实证：xcodebuild test（UnitTests, Debug，独立 derivedDataPath /tmp/LyricsMTMR-dd-r22a-test）**TEST SUCCEEDED —— 181 用例 0 失败 0 意外**（172 基线 + 9 新增全过：PausableTimerTests 24 = 18+6、WidgetLeakTests 8 = 5+3；金丝雀锚点 testGoldenAnchors2026/2027/Makeup2026 全绿）。leak 测试的 Currency/Weather 初始 fetch 为 fire-and-forget 弱引用请求（-1003 代理错误日志无影响，同 round-20 B 卡 testYandexWeatherBarItemDoesNotLeak 先例）。分支 xcodebuild build（MTMR, Debug, CODE_SIGNING_ALLOWED=NO，/tmp/LyricsMTMR-dd-r22a-build）**BUILD SUCCEEDED**。本轮分支验证即全量回归（172 基线全部复跑 + 9 新增，181 全绿；第 20 轮分解前全量 156 + 第 21 轮收口整体 172 实证后，隔代规则下轮（第 23 轮）分解前不触发，预计第 24 轮触发，届时基线 181）。

---

## 六、风险点与遗留

1. **真机冒烟挂账延续**：隐藏期零请求/恢复补刷观感依赖 Touch Bar 真机（第 18~21 轮同一挂账家族）；本卡为纯逻辑 + 单测覆盖（gate 语义/幂等/竞态），系统调度器行为（触发节拍）未变，风险低；
2. **初始 fetch 边界**（3.5）：隐藏期重建 item 的 init 单次 fetch 是配置变更事件请求（与第 19~21 轮重建行为一致）；严格「隐藏期零请求」需全局隐藏态注入 init，超出本轮范围——已如实记录，非轮询空转；
3. **NSBackgroundActivityScheduler 触发不确定性**：系统可合并/延迟调度（非精确周期），gate 方案不依赖其触发精度（隐藏期触发即拦截，恢复期触发即刷新，补刷保证显示新鲜度）；
4. **保留环修复的行为变化**：Currency/Weather 旧 item 现在会在预设重载时真正释放——其 in-flight 网络请求以弱引用结束（无崩溃/无异常路径变化）；调度器 invalidate 由既有 deinit 负责；
5. **UpNext convenience init**：6 参入口改 convenience 委托 7 参——BarItemFactory :115 调用点编译期验证通过，生产路径逐字节等价；
6. **遗留登记（新增）**：无新挂账；本轮收口后「隐藏期零空转」治理主线缺口清零（Timer 类 16 项 + 自循环 2 项 + 采集链 + scheduler 类 4 项全部纳入）。
