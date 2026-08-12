# 验证报告_第22轮_天气widget定位服务隐藏期治理

> 第 22 轮（功能/优化迭代第 10 轮）子任务 B，分支 r22/location，基线 main=b46116b
> 落地目标：WeatherBarItem 与 YandexWeatherBarItem 的 CLLocationManager 定位服务纳入整条 bar 隐藏（黑名单 app / exitTouchbar）暂停——隐藏期停止定位（GPS 关闭、隐私指示灯熄灭），恢复后重新定位并立即补刷天气；评估 stop/start 权限重弹、缓存保留、广播幂等、deinit 清理；TouchBarController 零改动。

## 一、实证（问题成立）

**全库 grep 实证**（基线 b46116b，`grep -rn startUpdatingLocation|stopUpdatingLocation` 全仓）：

| 位置 | 调用 | 说明 |
|---|---|---|
| Widgets/Life/WeatherBarItem.swift:114 | `startUpdatingLocation()` | init 尾部，权限检查通过后 |
| Widgets/Life/YandexWeatherBarItem.swift:65 | `startUpdatingLocation()` | init 尾部，权限检查通过后 |
| Preferences/WeatherTabView.swift:194 | `startUpdatingLocation()` | 设置窗口「定位添加城市」（见 3.6 观察项） |
| **全仓** | **`stopUpdatingLocation()`** | **0 处** |

结论：两个天气 widget 在 init 启动定位后**无任何停止路径**——bar 隐藏仅隐藏 UI（`dismissTouchBar` → `minimizeSystemModal`），item 存活于 TouchBarController.items（TouchBarController.swift:757-760 注释明示），CLLocationManager 持续更新 → GPS 常亮、隐私指示灯常亮、电量消耗。与第 21 轮 AudioSpectrum 采集链同类：事件驱动源在隐藏期持续产生事件。问题成立。

生命周期旁证：WeatherBarItem 的 deinit 因 activity 调度闭包强捕获 self 构成永久循环引用**永不执行**（见 3.5），即使配置热重载替换 item，旧 item + 旧 manager 一并泄漏、GPS 持续活跃——本卡修复后 deinit 可达并统一停定位。

## 二、方案（概述）

两 widget 均 conform `TBPollPausable`（既有协议，TouchBarController 广播零改动）：
- 新增 `locationPauseGate`（TBPauseGate）——「状态实际变化才动作」幂等门（同 round 21 capturePauseGate）；
- 新增 `locationTrackingEnabled` 标志（init 期决定：权限可用且非中国模式固定城市）——setPaused 守卫，城市模式/权限拒绝实例广播 no-op；
- 新增 internal 接缝 `startLocationUpdates()` / `stopLocationUpdates()` / `locationServicesUsable()`（单测注入点，同 round 21 startCapture 模式）；
- `setPaused(true)` → 主线程 hop + gate 复查 → `stopUpdatingLocation()`；`setPaused(false)` → `startUpdatingLocation()` + 立即 `updateWeather()`（用缓存 location 立刻出数）；
- deinit 统一停定位；WeatherBarItem activity 闭包 [weak self] 断循环引用；
- 恢复定位**复用既有 manager 实例**（惰性创建一次），desiredAccuracy/delegate 不变。

## 三、评估与方案取舍

### 3.1 stop/start 是否触发权限重弹 —— 零风险（同第 21 轮结论同构）

- TCC 定位授权持久化（TCC.db 按 bundle ID + 代码签名记录），`authorized` 后 `startUpdatingLocation()` 不再触发授权 UI；仅用户手动撤销/系统重置 TCC 才重新询问——与启停次数无关。
- macOS 定位首次授权弹窗只发生在**首次**定位使用（Info.plist 已声明 NSLocationWhenInUseUsageDescription 等 4 键，MTMR/Info.plist:93-100）；stop→start 不重弹。
- **仓库内生产实证路径**：WeatherTabView「定位添加城市」每次用户点击即创建新 manager 并 startUpdatingLocation（设置窗口内高频启停先例）；App 重启/配置热重载同样反复 start——从未引入二次弹窗。
- 异常路径：权限被撤销后 start → `didFailWithError` 打印错误（原处理逻辑不变），widget 不死、标题保留旧值。

### 3.2 隐藏期已有 location 缓存是否保留显示 —— 保留

- `location` / `prev_location` / `lastLocatedCityName` 均不动，title 保持隐藏前最后一次天气显示；
- 恢复时 `updateWeather()` 直接用缓存 location 立即出数，**不等下一次 fix**（立即补刷语义同 round 21 immediateFireOnResume）；
- 新 fix 到达后 delegate 逻辑不变（prev_location 非 nil 时不重复触发 updateWeather，避免双刷）。

### 3.3 重复广播幂等 —— gate 保证

`presentTouchBar`/`dismissTouchBar` 会对**所有**存活 item 广播 `setPaused`（含从未暂停过的），`TBPauseGate.setPaused` 仅在实际变化时返回 true——重复 present 不重启定位、重复 dismiss 不双停（单测 3 用例直证，同 round 21 口径）。

### 3.4 启停并发竞态 —— 主线程 hop + 状态复查

所有启停经 `DispatchQueue.main.async` + 执行前 gate 复查（同 TBPausableTimer 模式）：快速 pause/resume 序列以最后一次状态为准，迟到的陈旧操作被 guard 丢弃。

### 3.5 deinit 清理 + WeatherBarItem 循环引用修复（顺带根治）

- **发现**：WeatherBarItem 的 `activity.schedule` 闭包强捕获 self（`self.updateWeather()`），self 强持有 activity → 永久循环引用，deinit（原仅 `activity.invalidate()`）永不执行——配置热重载后旧 item 泄漏，其 manager 持续定位（GPS 常亮的隐藏放大器）。Yandex 版本已 [weak self]（第 20 轮 B 卡修复），无此问题。
- **修复**：闭包改 `[weak self]` + `self?.updateWeather()`（completion 无条件调用不变），deinit 可达；
- **deinit 内容**：`activity.invalidate()` + `stopLocationUpdates()`（两 widget 统一）——item 销毁时停定位，防旧 manager 泄漏后 GPS 常亮。
- 取舍：不改 activity 的 internal 语义（调度器见 3.7）；仅访问级别放宽供测试隔离（见 3.8）。

### 3.6 观察项（不纳入，如实登记）：WeatherTabView 定位添加城市

Preferences/WeatherTabView.swift:184-232：用户点「定位添加城市」→ `requestLocation()` + `startUpdatingLocation()` + 0.5s 轮询；resolve 后仅 invalidate 轮询 Timer，**manager 未停**（`@State locationManager` 随窗口关闭释放，但窗口开着时 GPS 持续活跃）。设置窗口生命周期内属用户在场场景、窗口关闭即随视图释放，成本低且不涉及 bar 显隐，**本卡不纳入**（范围约束：两个 bar widget）；登记为观察项，建议后续在 resolve/超时分支补 `stopUpdatingLocation()`。

### 3.7 NSBackgroundActivityScheduler 周期刷新不纳入暂停（范围决策）

两个 widget 的 update 循环是 `NSBackgroundActivityScheduler`（系统级合并调度，非 runloop Timer）——第 20 轮 Timer 盘点口径外（非 Timer/asyncAfter/DispatchSourceTimer），且本卡范围明确为**定位服务**。取舍：
- 保留：隐藏期活动调度器仍按 interval 触发 updateWeather（纯网络请求，用缓存 location，**不唤醒 GPS**）；NSBackgroundActivityScheduler 为低优先级合并调度（节能设计），成本显著低于 GPS；恢复时 setPaused(false) 立即补刷保证新鲜度。
- 若后续要求隐藏期零网络，可单独评估 invalidate/重建调度器（涉及 interval 记忆与恢复语义，超出本卡）。

### 3.8 测试隔离设计（活动调度器首触发不遵守 interval 下限）

实测：NSBackgroundActivityScheduler(interval: 60) 在测试窗口内（~2s）即触发首次执行——首触发不遵守 interval 下限（系统合并调度的已知行为），会污染「刷新次数」断言。取舍：`activity` 访问级别 private → internal（单测注入点，同 round 21 startCapture 放宽先例），计数子类 init 后 `activity.invalidate()` 隔离调度器；刷新计数断言因此**精确可断言**（而非弱化的 ≥ 断言）。

## 四、变更明细

| 文件 | 变更 |
|---|---|
| `LyricsMTMR/MTMR/Widgets/Life/WeatherBarItem.swift` | ① conform `TBPollPausable`；② 新增 `locationPauseGate`（TBPauseGate）+ `locationTrackingEnabled`（init 期置位：权限可用且非中国模式固定城市，setPaused 守卫）；③ 权限双检查（denied/restricted + services disabled）收敛为 internal 接缝 `locationServicesUsable()`（原 print 文案与早退条件逐字等价）；④ manager 创建收敛进 `startLocationUpdates()`（惰性创建复用，原 init 尾部 4 行等价替换），新增 `stopLocationUpdates()`；⑤ `setPaused`：隐藏停定位 / 恢复重启定位 + 立即 updateWeather，主线程 hop + gate 复查；⑥ activity 调度闭包 `[weak self]`（断循环引用，deinit 从此可达）；⑦ `activity` private→internal（测试注入点）；⑧ deinit += stopLocationUpdates |
| `LyricsMTMR/MTMR/Widgets/Life/YandexWeatherBarItem.swift` | 同构 ①-⑤⑦⑧（权限检查收敛、manager 收敛、setPaused、gate、deinit 停定位）；activity 闭包原已 [weak self]（第 20 轮修复）不动 |
| `LyricsMTMR/MTMRTests/PausableTimerTests.swift` | 新增「Round 22」节：`LocationCounts` 共享计数盒（deinit 效应在对象释放后可断言）+ `CountingWeatherItem` / `CountingYandexWeatherItem`（override 三接缝计数 + `locationServicesUsable` 恒 true + init 后 invalidate 调度器）+ 5 用例（见六） |
| `TouchBarController.swift` | **零改动**（TBPollPausable 广播既有，dismiss/present 自动覆盖新 conform 者） |

## 五、等价性论证

- **未隐藏时严格等价**：init 顺序不变（权限检查 → 调度器 → updateWeather → startLocationUpdates 同原 manager 创建位置）；`startLocationUpdates()` 惰性创建 manager 的参数/精度/delegate 与原 4 行逐字一致；setPaused 仅由 TouchBarController 广播触发、未暂停过的 item 收到 setPaused(false) 时 gate 无变化 → 零副作用；权限拒绝/中国模式固定城市实例 init 早退路径不变（locationTrackingEnabled=false → 广播 no-op），manager 永不创建。
- **行为差异仅两处**（均为严格改进）：① 整条 bar 隐藏期间定位停止（GPS 关闭、隐私指示灯熄灭）；② WeatherBarItem 配置热重载后旧 item 可回收（原永久泄漏，含其 GPS）。
- **恢复语义**：立即补刷用缓存 location 出数（不等 fix）；新 fix 到达后 delegate 原逻辑不变（prev_location 判空防重复触发），与改动前逐字节一致。
- **并发**：启停全经主线程 hop + gate 复查（同 round 21 模式），快速广播序列最后一次状态为准。

## 六、单测清单（新增 5 用例，沿用 PausableTimerTests.swift 既有 helper，无需 add_files.py）

| # | 用例 | 断言要点 |
|---|---|---|
| 1 | testWeatherBarItemLocationPauseStopsResumeRestartsAndRefreshes | init 恰好 start 1 次 + init updateWeather 1 次；setPaused(true) → stop 恰好 1 次、不重启、不刷新；setPaused(false) → start 第 2 次 + 立即补刷（refresh 2） |
| 2 | testWeatherBarItemLocationPauseBroadcastIsIdempotent | 未暂停 item 收 setPaused(false) 零副作用（不 start 不 stop 不刷新）；重复 dismiss 不双停；重复 present 不重启不再刷 |
| 3 | testYandexWeatherBarItemLocationPauseResume | 同 1 的 Yandex 版（init start 1 / pause stop 1 / resume start 2 + 补刷 / 重复广播幂等） |
| 4 | testWeatherBarItemChinaCityModeIgnoresPauseBroadcasts | 中国模式固定城市：start 0 次；pause/resume 广播全 no-op（start/stop 均 0） |
| 5 | testWeatherBarItemDeinitStopsLocationAndReleases | 释放后 deinit 停定位（stop 计数 1，经共享计数盒断言）+ weak 引用为 nil（活动调度器闭包不再强持有——循环引用修复实证） |

5 用例合计 ~2.4s（全绿实测）。计数子类三接缝 override（locationServicesUsable / startLocationUpdates / stopLocationUpdates / updateWeather），不触碰真实 CLLocationManager / 网络 / 反地理编码。

## 七、分支验证

- `xcodebuild build`（MTMR, Debug, CODE_SIGNING_ALLOWED=NO，derivedDataPath .build/DerivedData）**BUILD SUCCEEDED**；
- `xcodebuild test`（UnitTests, Debug，同 derivedDataPath）**TEST SUCCEEDED —— 177 用例 0 失败 0 意外**（172 基线 + 新增 5 全过；金丝雀锚点 testGoldenAnchors2026/2027/Makeup2026 全绿，WidgetLeakTests 5 用例仍绿含 YandexWeatherBarItem 无泄漏，PausableTimerTests 23 用例全绿）；
- `make build`（build.sh, Release + 签名）因本机无 "Mac Development" 证书失败——环境问题非代码问题，项目惯例以 Debug+CODE_SIGNING_ALLOWED=NO 为准（与第 21 轮同口径）；
- 本轮不触发全量回归（第 20 轮收口整体 163 用例实证 + 第 21 轮收口 169，隔代规则预计第 22 轮收口父任务整体实证，届时基线 177）。

## 八、风险点与遗留

1. **TCC 状态在运行中被用户撤销**：resume start 后 didFailWithError 打印 + 保持旧显示（原错误路径），不重弹窗、不崩溃——风险零新增。
2. **macOS 首次授权弹窗时机**：首次定位使用（init start）仍可能弹窗（OS 行为，改动前亦然）；隐藏期停止/恢复不增加弹窗次数。
3. **WeatherTabView 定位添加城市不纳入**（观察项，见 3.6）：设置窗口开着时 GPS 持续活跃，建议后续补 stop——不影响本卡验收。
4. **NSBackgroundActivityScheduler 隐藏期仍周期刷新**（范围决策，见 3.7）：非本卡范围，已登记取舍。
5. **真机冒烟延续挂账**（第 8/17/18/19/20/21 轮同口径）：隐藏期隐私指示灯熄灭、恢复定位与补刷观感待用户 Touch Bar 真机确认。
6. **测试环境备注**：xcodebuild 结果包保存报 mkstemp 错误（IDEFoundationErrorDomain Code=12）为 Xcode 工具链 artifact 保存问题，不影响测试结果（TEST SUCCEEDED 判定已过）。
