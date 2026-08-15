# 验证报告_第23轮_WeatherTabView定位生命周期治理

> 第 23 轮（功能/优化迭代第 11 轮）子任务 B · 分支 r23/location-fix（基于 main@8b15f98）
> 承接：第 22 轮 B 卡（t_0693cc33）登记遗留观察项 —— WeatherTabView 定位添加城市 resolve/超时后未停 manager

## 一、实证（问题成立）

main@8b15f98 源码 `LyricsMTMR/MTMR/Preferences/WeatherTabView.swift` locateAndAddCity()（原 :184-232）：

1. 每次点击新建 `CLLocationManager` 后调 `requestLocation()` + `startUpdatingLocation()`（:193-194）。
2. 0.5s 轮询 Timer 在 resolve 成功（attempts>=2 且 manager.location 非空 → reverseGeocode）或超时（attempts>12 ≈ 6.5s）后**仅 `timer.invalidate()`**——全文件无 `stopUpdatingLocation`（grep 实证 1 start 0 stop）。
3. `startUpdatingLocation` 是**持续定位**请求：成功路径 GPS 永久活跃（隐私指示灯常亮 + 电量消耗），超时路径同样泄漏；仅当 6.5s 超时兜底后 timer 停止，但 GPS 仍不关。
4. 视图无消失钩子：设置窗口关闭（第 22 轮内存修复后为 orderOut 隐藏复用，窗口树常驻）或切页（ZStack opacity + LRU 缓存，tab 常驻挂载）时 onDisappear 均不触发，manager 无人停止。

与第 22 轮 B 卡治理的 WeatherBarItem/YandexWeatherBarItem（stopLocationUpdates 模式）形成对照：设置窗口内的定位添加是用户在场的一次性操作，但 manager 泄漏同样造成 GPS 常开。

## 二、方案（概述）

提取**定位会话封装 `WeatherLocationSession`**（internal，单测注入缝），接管 CLLocationManager + 轮询 Timer + 反地理编码的完整生命周期；视图只保留按钮态与结果文案。三路径统一停定位：

- **resolve 成功**：取得 fix 的当拍即 `stopUpdatingLocation()`（GPS 关闭），再走反地理编码；
- **超时**：`stop()`（停定位 + 失效 timer）后报 timedOut；
- **视图消失（等价生命周期）**：`stop()` 停定位 + 取消在途 geocode + 释放引用。

视图侧生命周期钩子：`onDisappear`（防御）+ `SettingsWindowState.isVisible`（窗口关闭/最小化/切后台/Space 切换）+ `SettingsWindowState.activeTab`（切页）。

## 三、评估与方案取舍

### 3.1 requestLocation 与 startUpdatingLocation 并存的原因与取舍 —— 保留并存

原实现无 delegate，靠轮询读 `manager.location`。requestLocation 为**一次性请求**：首 fix 失败（kCLErrorLocationUnknown 等）后不再补发，无 delegate 时失败不可见；startUpdatingLocation 为**持续更新兜底**，保证轮询窗口内 manager.location 能拿到 fix——两者缺一不可（首 fix 后反地理编码添加城市的语义依赖持续源）。**取舍：保留并存调用**（start 时两者都发），停止时 `stopUpdatingLocation()` 关掉持续部分；一次性 request 在途请求无 delegate → 无观察效应，不构成泄漏。

### 3.2 SwiftUI 视图生命周期与 CLLocationManager delegate 的关系 —— 本项目无 delegate

本实现自始至终无 CLLocationManager delegate（原实现同样没有）：fix 靠轮询读取 manager.location 属性获得，delegate 回调路径不存在，故不存在 delegate 生命周期管理问题。会话封装保持这一形态（LocationProviding 抽象只暴露 location 只读属性 + 三个方法）。

### 3.3 onDisappear 在本架构下不可靠 —— 用 isVisible + activeTab 做等价生命周期

实证（UnifiedSettingsWindowController.swift）：
- **窗口关闭**：windowShouldClose → hideWindow() → orderOut 隐藏复用（2026-08-12 内存修复），窗口与整棵 SwiftUI 树常驻（闲置 GC 1h 后才可能释放）→ onDisappear 不触发；
- **切页**：SettingsRootView content 为 ZStack + opacity 交叉淡化 + tabCache LRU 常驻挂载 → onDisappear 不触发。

故采用代码库既有的可见性信号 `SettingsWindowState.shared`（Deck 动画/Equalizer 同款）：`isVisible=false`（关窗/最小化/Space 切换/失焦）与 `activeTab != .weather`（切页）均停会话；onDisappear 保留为防御钩子。

**取舍（如实登记）**：isVisible=false 在窗口失去 key 状态（用户点击其他应用）时也会触发，即「定位中切走焦点」会取消在途操作（按钮复位，用户回来重点即可）。操作本身 1~6.5s 一次性，取消成本极低；若保留 GPS 至完成则违背「用户不在看时不开 GPS」的治理本意。窗口真正关闭的路径因此被完整覆盖。

### 3.4 权限拒绝 / 定位服务关闭路径 —— 保持原状（不改语义）

原实现无权限检查：权限拒绝/服务关闭时无 delegate → manager.location 恒 nil → 落入超时路径（~6.5s）显示「定位超时，请检查权限」——文案已提示权限，语义合理。**不引入快速失败**：若在 start 时检查权限并早退，会打断「轮询窗口内用户恰好通过 TCC 弹窗授权」的合法流程（授权后 fix 在窗口内到达即可 resolve）。治理收益：超时路径现在会停 manager（原泄漏），无行为回退。

### 3.5 重复点击 / 多实例并存 —— 三层防护

1. 按钮 `disabled(locating)`（原样保留）；2. locateAndAddCity 入口先 `locationSession?.stop()` 停旧会话；3. 会话内部 `start()` 重复调用为 no-op（`guard timer == nil`）。单测覆盖第 3 层。

### 3.6 stop 后丢弃在途反地理编码结果 —— 与「释放引用」要求一致

视图消失时 stop() 会 `cancelGeocode()`，迟到的 geocode 完成回调因 `stopped` 守卫被丢弃（城市不会在窗口隐藏期间被静默加入）。此窗口极小（geocode ~1s 内完成），用户重开窗口重试即可——与任务「视图消失路径释放引用」的要求一致，如实登记该行为差异。

### 3.7 兜底：会话随视图树释放（闲置 GC 路径）

窗口树被闲置 GC / 内存压力释放时，会话随 @State 释放：deinit 守卫（未 stopped、未 resolve、timer 存活）补一次 stopUpdatingLocation；Timer 块 [weak self] 使孤儿 Timer 在下一次触发时自失效，无永久轮询。

### 3.8 stopUpdatingLocation 每会话恰好一次 —— 契约

resolve 路径在 poll 内停；stop() 在已 resolve 时跳过重复 stop（只取消 geocode）；deinit 在 stopped/didResolve 时跳过。所有路径合计恰 1 次 stop，单测以计数断言钉死。

## 四、变更明细

| 文件 | 变更 |
|---|---|
| `LyricsMTMR/MTMR/Preferences/WeatherLocationSession.swift` | **新增**（add_files.py 注册）：WeatherLocationSession —— LocationProviding/GeocodingProviding 双抽象（生产 = CLLocationManager/CLGeocoder 扩展 conform，测试 = 假源/假 geocoder）；Outcome 枚举（city/noPlacemark/timedOut）；pollInterval/maxAttempts 可注入（默认 0.5s/12 次与生产逐字一致）；start/stop/isActive；resolve 当拍停定位；超时 stop；stop 幂等 + 丢弃在途结果；deinit 兜底 |
| `LyricsMTMR/MTMR/Preferences/WeatherTabView.swift` | `@State locationManager` → `@State locationSession`；+`@ObservedObject windowState`（SettingsWindowState.shared）；locateAndAddCity 重写为创建会话（先停旧会话 + 结果回调：city 去重/保存/文案，noPlacemark/超时文案与原文逐字一致）；+stopLocationSession()；body +onDisappear / isVisible / activeTab 三个生命周期钩子 |
| `LyricsMTMR/MTMRTests/WeatherLocationSessionTests.swift` | **新增**（add_files.py Tests: 注册）9 用例（见六） |
| `LyricsMTMR.xcodeproj/project.pbxproj` | add_files.py 幂等注册 2 文件（C0FE/C0FF 与 C1FE/C1FF 前缀分域） |

## 五、等价性论证

**未治理路径严格等价**（仅传入时机/结果处理方式变化，可观察行为逐项一致）：
- 轮询节奏 0.5s、fix 验收门槛 attempts>=2、超时 attempts>12（≈6.5s）——默认参数逐字一致；
- 城市提取 `placemark.locality ?? placemark.administrativeArea` + 「市」后缀剥离——逻辑原样搬入会话，且因此获得单测覆盖；
- 结果文案三句（已添加：X / 无法获取定位 / 定位超时，请检查权限）逐字一致；
- 全部状态写入仍在主线程（Timer 主 runloop + geocode 完成主线程 hop），@State 写安全；
- requestLocation + startUpdatingLocation 并存调用顺序不变。

**行为差异（全部为治理目标或已登记的取舍）**：
1. resolve 成功后 GPS 立即关闭（原：永久活跃——本次修复的核心）；
2. 超时后 GPS 关闭（原：泄漏）；
3. 窗口关闭/最小化/失焦/切页时在途操作取消并停 GPS（原：持续到完成；3.3/3.6 登记）；
4. 会话随视图树释放时 GPS 兜底关闭（原：随 manager 释放由系统关，现为显式）；
5. 城市去重/保存逻辑仍在视图回调（不变），但「市」剥离移入会话（可测，行为不变）。

## 六、单测清单（新增 9 用例，MTMRTests/WeatherLocationSessionTests.swift，add_files.py Tests: 注册）

测试缝：FakeLocationSource（假定位源，可注入 fix + 计数 start/stop/request）、FakeGeocoder（捕获完成回调手动触发 + 计数 cancel）、MKPlacemark(addressDictionary:) 构造假 placemark（零网络、零真实 CoreLocation）；快速会话参数 pollInterval=0.02 / maxAttempts=3（超时 ~60ms，语义与生产同构）。9 用例合计 ~1.0s。

| 用例 | 断言要点 |
|---|---|
| testResolvePathDeliversCityAndStopsLocationUpdates | fix 前不 resolve（attempts>=2 门槛）；resolve 当拍 stopUpdatingLocation 恰 1 次（GPS 关）；「成都市」→「成都」剥后缀；timer 失效（isActive=false）；后续无重复 geocode/stop |
| testResolveFallsBackToAdministrativeAreaAndStops | locality 缺失时回退 administrativeArea（「四川省」）；stop 恰 1 次 |
| testResolveWithoutPlacemarkReportsNoPlacemarkAndStops | geocode 无结果 → .noPlacemark；stop 恰 1 次 |
| testTimeoutPathStopsLocationUpdatesAndReportsTimedOut | 无 fix 超时 → .timedOut；stop 恰 1 次；零 geocode；timer 失效；无重复结果 |
| testStopWhilePollingStopsManagerAndTimerAndDiscardsResults | 轮询中 stop → stop 1 次 + cancelGeocode 1 次 + timer 失效；迟到的 fix 不产生任何结果 |
| testStopWhileGeocodingDiscardsPendingResult | resolve 后（已停 GPS）外部 stop 不重复 stop（恰 1 次）但取消在途 geocode；迟到完成回调被丢弃（视图隐藏后不静默加城市） |
| testDoubleStartIsIgnored | 重复 start 不重复 request/startUpdatingLocation（防多实例并存） |
| testStopBeforeStartIsNoOp | 未 start 的会话 stop 零副作用 |
| testStopIsIdempotent | 重复 stop 只停一次（重复 dismiss/隐藏广播幂等） |

## 七、分支验证

- **build**：`xcodebuild build -project LyricsMTMR.xcodeproj -scheme MTMR -configuration Debug -derivedDataPath /tmp/LyricsMTMR-dd-r23b-build CODE_SIGNING_ALLOWED=NO` → **BUILD SUCCEEDED**
- **test**：`xcodebuild test -project LyricsMTMR.xcodeproj -scheme UnitTests -configuration Debug -derivedDataPath /tmp/LyricsMTMR-dd-r23b-test CODE_SIGNING_ALLOWED=NO` → **TEST SUCCEEDED —— 195 用例 0 失败 0 意外**（186 基线 + 新增 9 全过；金丝雀锚点 testGoldenAnchors2026/2027/Makeup2026 全绿；WidgetLeakTests 8 用例全绿无新泄漏）
- 本轮分支验证即全量（任务口径：不触发跨轮全量回归，第 22 轮收口已整体实证 186）

## 八、风险点与遗留

- **失焦取消**：定位中用户点击其他应用（窗口失去 key 状态）会取消在途操作——按 3.3 取舍登记，按钮复位可重试；如需「失焦不取消」需区分 close-hide 与 resignKey 两种 isVisible=false 来源，超出本轮最小改动原则；
- **真机冒烟挂账**：设置窗口内定位添加的 GPS 隐私指示灯熄灭/恢复观感依赖 Touch Bar 真机（第 22 轮同口径延续）；
- **onDisappear 依赖**：视图树卸载路径（闲置 GC 后重开窗口）依赖 onDisappear + deinit 兜底，若未来窗口生命周期架构变化需复查三钩子覆盖；
- 约束遵守：仅动本工作区与 r23/location-fix 分支，未 push 远端（父任务收口统一推送），未开新分支/新子任务/无 parents 依赖；完成自查 git status 干净 + commit 已提交。
