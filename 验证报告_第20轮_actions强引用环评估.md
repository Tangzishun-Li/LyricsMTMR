# 验证报告_第20轮_actions强引用环评估

- 任务：t_60cbd9a4（第 20 轮 B 卡，代码质量）
- 分支：r20/code-quality（工作区 .worktrees/round20-B）
- 基线：main@1a4374d，全量 156 用例 0 失败
- 结论：**构成真实强引用环（2 处，pre-existing），已最小修复 + 单测实证 deinit 可达**

---

## 1. 背景

第 19 轮 A 卡（t_daabd270）登记超出范围观察（第 20 轮遗留问题清单第 10 项②）：
`CustomButtonTouchBarItem actions 强自引用环（pre-existing）`——round-19 的 deinit 单测
（`PausableTimerTests.testCPUItemDeinitStopsChain`）当时以 `item.actions.removeAll()` 手动
打破该环后，deinit 才得以运行并暴露了 CPUBarItem 的 libdispatch suspend 队列崩溃（已修）；
**环本身未动**，遗留本卡评估。

本卡按约束：不重开分支、不新建子卡；若评估结论为「不构成泄漏」则如实交付结论报告，不得为改而改。

## 2. 引用图分析（三条指定链 + 审计发现链）

### 链 1：item → actions → closure → ?

`CustomButtonTouchBarItem`（struct ItemAction 的 `closure` 为 `(() -> Void)?`，item 强持有 actions 数组）。

全库 23 处 `ItemAction(` 构造点逐一核查：

| 构造点 | 捕获方式 | 强弱 |
|---|---|---|
| DarkModeBarItem:14 / NightShiftBarItem:34 / InputSourceBarItem:22 / DnDBarItem:22 / UsageBarItem:72 / ThemeSwitchBarItem:35 / MusicBarItem:46-48 / PomodoroBarItem:56-57 / WeatherBarItem:74 / StockBarItem:67 / UpNextScrubberTouchBarItem:80 / AppScrubberTouchBarItem:117,120 | `[weak self]` 闭包 | 弱 ✅ |
| BarItemFactory:278 | `[weak ocgItem]` | 弱 ✅ |
| BarItemFactory:283/286（actionResolver/longActionResolver 注入） | resolver 为 `{ [weak self] in self?.action(forItem:) }`（TouchBarController:829-832）；返回闭包只捕获 keycode/source/url 等局部值 | 弱 ✅ |
| BarItemFactory:291（closureResolver） | `closure(for:)` 外层包 `[weak self]`（:971） | 弱 ✅ |
| BarItemFactory:363（createErrorItem） | 仅捕获局部字符串 originalType/reason | 无 self 捕获 ✅ |
| **CPUBarItem:29-32** | **`ItemAction(trigger: .singleTap, defaultTapAction)` 方法引用** | **强 ❌ 成环** |
| **YandexWeatherBarItem:68-71** | **`ItemAction(trigger: .singleTap, defaultTapAction)` 方法引用** | **强 ❌ 成环** |

Swift 语义：实例方法引用（`defaultTapAction`）作为闭包值传递时**强捕获 self**，且无法用
捕获列表改写——形成 `item → actions → ItemAction.closure → item` 经典保留环。item 被
NSTouchBar 释放后，环内互相强持有，deinit 永不可达（真泄漏）。其余 21 处均无环。

### 链 2：item → button → cell → parentItem

- `CustomButtonTouchBarItem.button`（private var，强）
- `button.cell`（NSButton 强持有 cell）
- `CustomButtonCell.parentItem`：**`weak var parentItem: CustomButtonTouchBarItem?`（CustomButtonTouchBarItem.swift:175，原代码即 weak）**

结论：cell 反向引用为弱 → **无环** ✅。`reinstallButton()` 中 `CustomButtonCell(parentItem: self)` 安全。

### 链 3：item → view → gestureRecognizer → target

- `view = button`（item 强持有 view）
- `view.addGestureRecognizer(longClick/multiClick)`（NSView 强持有手势）
- `NSGestureRecognizer.target`：AppKit 头文件明确 `@property (nullable, weak) id target;`
  （NSGestureRecognizer.h:44）——**weak**；`delegate` 同为 weak

结论：手势 target 反向引用为弱 → **无环** ✅。注意 item 另经 `private var longClick/multiClick`
直接强持有手势，方向均为 item 向外，无反向强边。

### 审计额外发现（链 4/5，同属「闭包强捕获 self」缺陷类，阻止同一 deinit）

- **链 4：YandexWeatherBarItem → activity(NSBackgroundActivityScheduler) → schedule block → self**：
  `activity.schedule { self.updateWeather() … }`（原 :56-59）强捕获 self，scheduler 被 item 强持有
  → 同样成环，deinit（其中 `activity.invalidate()`）永不可达。
- **链 5：YandexWeatherBarItem → updateWeatherTask(URLSessionDataTask) → completion → self**：
  完成闭包强捕获 self（原 :82），请求在途期间 item ↔ task 互持（虽请求结束/取消后自解，
  但会推迟 deinit 至网络终结，且与链 1/4 叠加）。

## 3. 结论

1. **CPUBarItem、YandexWeatherBarItem 的 actions 强引用环属实**，阻止 deinit（真泄漏）：
   round-19 测试的 `actions.removeAll()` 绕开即是该环存在的直接证据。→ **需修复**。
2. 视图层级（链 2/3）为 AppKit 固有结构 + weak 反向引用，**无环**，无需改动（`parentItem`
   原即 weak，手势 target 原即 weak）。
3. 其余 21 处 ItemAction 构造点 + factory 注入链均 [weak self]，无环。
4. YandexWeatherBarItem 另有 2 处同缺陷类强捕获（scheduler 块、URLSession 完成闭包），
   一并修复以保证 deinit 整体可达（同为一行级 [weak self] 调整）。

## 4. 改动清单（2 文件，4 处，全部最小改动）

| 文件 | 改动 | 语义 |
|---|---|---|
| LyricsMTMR/MTMR/Widgets/System/CPUBarItem.swift:28-33 | `ItemAction(trigger: .singleTap, defaultTapAction)` → `ItemAction(trigger: .singleTap) { [weak self] in self?.defaultTapAction() }` | 行为等价，断环 |
| LyricsMTMR/MTMR/Widgets/Life/YandexWeatherBarItem.swift:67-71 | 同上（actions 方法引用） | 行为等价，断环 |
| LyricsMTMR/MTMR/Widgets/Life/YandexWeatherBarItem.swift:56-59 | `activity.schedule { self.updateWeather() … }` → `[weak self] … self?.updateWeather() …`（completion 无条件调用） | 行为等价，断环 |
| LyricsMTMR/MTMR/Widgets/Life/YandexWeatherBarItem.swift:81-104 | URLSession 完成闭包 `{ data, _, error in … }` → `[weak self]` + guard；内层 `DispatchQueue.main.async` 同步弱化，文本先构造成局部常量 | 行为等价，断环 |

无其他文件改动；`CustomButtonTouchBarItem.swift` 本身零改动（视图链原即无环）。

## 5. 单测

| 测试 | 变更 | 证明点 |
|---|---|---|
| PausableTimerTests.testCPUItemDeinitStopsChain | **去掉 `item.actions.removeAll()` 绕开**（该绕开是 round-19 为环打的补丁） | CPUBarItem 在 actions 原样保留时 deinit 可达；在途 asyncAfter hop 不复活（原有第二断言保留） |
| WidgetLeakTests.testYandexWeatherBarItemDoesNotLeak（新增） | autoreleasepool 建/释 + runloop 空转后断言 weak 为 nil | YandexWeatherBarItem 三处强捕获修复后 deinit 可达 |

说明：YandexWeatherBarItem 测试会真实走 init（含 CLLocationManager 创建与一次 yandex.ru 请求发起），
但均不反向强持 item（manager.delegate weak、URLSession 完成闭包已弱化），断言与网络/定位结果无关，
无环境波动风险。

## 6. 分支验证

- 构建：xcodebuild test（UnitTests, Debug，独立 derivedDataPath /tmp/LyricsMTMR-dd-r20b-test）
- 结果：**TEST SUCCEEDED —— 157 用例 0 失败 0 意外**（156 基线 + 新增 1，
  金丝雀锚点 testGoldenAnchors2026/2027/Makeup2026 全绿，WidgetLeakTests 5 用例全绿无泄漏）

## 7. 等价性论证

- 触发语义：`callActions(for:)` 仍调用同一 `defaultTapAction()`；仅引用捕获由强转弱，
  item 存活期间行为逐字节等价。
- scheduler：`completion(.finished)` 无条件调用（协议要求），仅 `updateWeather()` 改为弱引用调用。
- URLSession：完成闭包逻辑不变，仅弱化捕获；内层主线程刷新改为弱引用 + 局部文本常量（原 `self.unitsStr`
  在闭包执行时已由强 self 保证，现文本在构造时求值，等价）。
- 生命周期：断环后 item 随 NSTouchBar 释放即刻回收（CPU 链 round-19 已证不复活；
  Yandex 三链弱化后无任何外部强持有者）。

## 8. 风险与遗留

- 风险低：改动为既有全库惯例（其余 21 处均为 [weak self]），无新 API、无行为分支。
- 遗留挂账（如实登记，超出本卡范围）：
  - YandexWeatherBarItem 的真实网络请求在 item 释放后仍会进行到完成（无持有影响）；
  - 其余 21 处已为 [weak self]，无同类问题；视图/手势链为 AppKit 固有结构，随 NSTouchBar
    生命周期统一释放（与第 6 轮内存修复基线一致）；
  - TouchBar item 真机冒烟（开窗内存线性增长、隐藏整树释放）仍按第 19 轮遗留 5 挂账跟踪。
