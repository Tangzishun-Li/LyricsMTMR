# 修复报告_t_aeb0b769_权限弹窗零自动申请治理

> 用户问题卡（dashboard 2026-08-14 02:33 创建）：「为什么不停地弹出让我授权麦克风和位置信息呢？…只要我不操作它，看板任务就没有办法继续下去…你得修一下。至少得提醒他们，不是这样搞检测的，一直在弹弹窗。」
> 分支：r30/permission-lazy（独立于轮次系统的用户问题修复；收口后合入 main 并 push）
> 完成：2026-08-14

---

## 一、根因（TCC 日志 + 代码双实证）

### 1.1 弹窗风暴的直接证据（com.apple.TCC 日志，2026-08-14 02:30~02:34）

看板第 29 轮父任务收口全量回归（`xcodebuild test`，02:30:01~02:33:11，TEST_HOST=真实 LyricsMTMR.app）期间：

| 服务 | 请求次数 | 时间窗口 | 来源 |
|---|---|---|---|
| kTCCServiceMicrophone | 12 | 02:32:10~02:33:08 | Toxblh.LyricsMTMR（测试宿主 pid 1394，binary=/private/tmp/LyricsMTMR-dd-r29-final-test/…） |
| kTCCServiceCalendar | 8 | 02:32:10~02:33:08 | 同上 |
| kTCCServiceReminders | 5 | 02:32:10~02:33:08 | 同上 |
| kTCCServiceScreenCapture | 2 | 02:32:10~02:33:08 | 同上 |
| kTCCServiceSystemPolicyDownloadsFolder | 1 | 02:34:03 | 其他客户端（非本项目） |

其中 3 次为**真实弹窗**（tccd 日志 "Prompting policy for hardened runtime; allow prompt: Allow"），需要用户逐一点击才能继续——正是「只要我不操作它，看板任务就没有办法继续下去」的直接来源。测试日志佐证：`02:33:08.327/.349 throwing -10877`（AVAudioEngine 在 TCC 弹窗未决时启动失败），随后 9 次麦克风 AUTHREQ 密集请求（02:33:08.315~.391）。

### 1.2 根因链（三层）

1. **ad-hoc 签名 → 每次构建都是「全新应用」**：构建产物 `Signature=adhoc, TeamIdentifier=not set`（codesign 实证）。TCC 对无稳定签名（Designated Requirement 含 cdhash）的应用按二进制指纹记录授权——**每轮重建 cdhash 变化，TCC 视作新应用，授权状态回到 notDetermined**，弹窗每轮重来。round 21 论证「TCC 持久授权零重弹」只覆盖了同构建内引擎重启，跨构建不成立。
2. **测试宿主 = 真实 App + 注册表对账测试全量实例化**：UnitTests scheme 的 TEST_HOST 是真实 LyricsMTMR.app；`RegistryReconciliationTests.testFactoryCreatesEveryCanonicalType` 经 BarItemFactory **真实构造全部 98 种 widget**，其中天气/Yandex/频谱/噪音计/upNext/出行/会议 等组件在 init 即自动触碰受保护服务（定位/麦克风/录屏/日历/提醒）→ 每轮回归必然弹窗。
3. **组件「init 即自动申请」的产品行为**：7 个组件在 init 无条件/无授权检查地启动受保护服务（详见 §2 修复清单），既污染测试，也不符合最小权限 UX（首启即弹窗）。

### 1.3 被排除的假设（如实登记）

- PausableTimerTests 把 UserDefaults `com.lyricsmtmr.spectrum.source` 写成 "mic" 不还原 → **不成立**：该测试已有 `defer` 还原（PausableTimerTests.swift:724-730），用户域实测 source="system"。麦克风请求来自真实引擎启动（授权门缺失），非配置污染。
- WeType 输入法 02:33:27~56 的 26 次麦克风请求（com.tencent.inputmethod.wetype, pid 871）→ **与本项目无关**（输入法语音输入会话反复请求），用户体感上叠加了弹窗噪音，已提示用户可检查 WeType 语音输入快捷键。

---

## 二、修复（权限惰性化：init 零自动 TCC，显式点按才申请）

统一原则：**任何受保护服务（麦克风/定位/录屏/日历/提醒）在 init/自动路径上绝不自动发起 TCC 申请**；未授权时组件显示提示文案，用户显式点按才申请授权或跳系统设置。授权后路径照常工作。

| 文件 | 改动 |
|---|---|
| Widgets/Life/WeatherBarItem.swift | ① `locationServicesUsable()`：`.notDetermined` 不再算可用（此前视为可用 → init 自动 startUpdatingLocation → 弹窗）；② init 惰性路径：定位被阻塞且非中国模式固定城市时，不调度天气、不启动定位，显示「点按定位/定位未授权」提示 + 点按动作（notDetermined→requestWhenInUseAuthorization，denied→跳系统设置定位面板）；③ 新增注入点 `currentLocationAuthorizationStatus()`/`requestLocationAuthorization()`（internal，计数子类 override）/`openLocationSettings()`；④ `didChangeAuthorization` 授权后接续：置 locationTrackingEnabled、补调度器、startLocationUpdates + 立即补刷（惰性实例 init 未调度）；⑤ 抽取 `scheduleWeatherActivity()`/`ensureManager()` 复用 |
| Widgets/Life/YandexWeatherBarItem.swift | 同 WeatherBarItem 全部镜像（无固定城市模式，恒需定位） |
| Widgets/Media/AudioSpectrumBarItem.swift | ① `startMic()` 授权门：`micAuthorizationStatus()`（新注入点）非 `.authorized` → 不建引擎、零 TCC；notDetermined→「需麦克风权限 · 点按开启」，denied/restricted→「麦克风未授权 · 点按设置」；② `startSystem()` 录屏预检：`screenCaptureAccessPreflight()`（新注入点，包 CGPreflightScreenCaptureAccess）未授予 → 不发起 SCK 流（此前发起即触发录屏弹窗），直接显示既有提示；③ onTap 按 `requestedSource` 分流：mic 提示 → 点按即 requestAccess（授权后重启采集链），录屏提示 → 跳系统设置录屏面板（原行为）；④ 测试缝 `currentHint` |
| Widgets/Productivity/NoiseMeter.swift | `startEngine()` 授权门：`micAuthorizationStatus()`（新注入点）非 `.authorized` → 不启动引擎（apply() 既有「需要权限」态展示）；注释修正 round 21「授权持久化」断言（跨构建不成立） |
| Widgets/Life/TravelCountdown.swift | init 删除 `TBEvents.requestAccess()`（compute() 既有「需要权限」展示；授权路径=系统设置→隐私→日历） |
| Widgets/Life/MeetingCountdown.swift | 同 TravelCountdown |
| Widgets/Media/UpNextScrubberTouchBarItem.swift | ① `UpNextCalenderSource`：init 仅在已授权时刷新，未决定/拒绝零自动申请；新增 `requestAccessIfNeeded()`（点按触发：notDetermined→申请，denied/restricted→跳系统设置日历面板，已授权→补刷）；**顺带修复原 authorized 分支漏置 hasPermission=true 导致组件恒空的潜在 bug**；② `IUpNextSource` 协议新增 `requestAccessIfNeeded()`（协议扩展默认 no-op）；③ updateView 无事件且存在未授权源时显示「点按授权日历」提示项（点按路由到源申请）；④ `items`/`UpNextItem` 转 internal（测试缝） |

**行为对照**（变更前后）：

| 场景 | 修复前 | 修复后 |
|---|---|---|
| 首启/每轮重建后启动 App（含定位型天气） | 定位弹窗 | 组件显示「点按定位」，点按才申请 |
| 测试宿主全量实例化 98 widget | 麦克风/日历/提醒/录屏/定位弹窗风暴，任务卡死 | 零弹窗（授权门拦截） |
| 麦克风源频谱/噪音计 | 引擎启动即弹窗 | 提示 + 点按申请 |
| 录屏源频谱 | SCK 流发起即弹窗 | 预检拦截 + 提示（点按跳设置） |
| upNext（用户预设含此组件） | init 即申请日历权限 | 「点按授权日历」提示项 |

---

## 三、单测（Round 30 段，PausableTimerTests 8 用例，计数子类模式）

| 用例 | 断言要点 |
|---|---|
| testWeatherItemLocationUnavailableShowsHintAndDoesNotAutoStart | 定位不可用 → startLocationUpdates=0、updateWeather=0、title=「点按定位」；点按 → request 恰 1 次且不启动定位 |
| testWeatherItemLocationDeniedShowsSettingsHintAndTapDoesNotRequest | denied → title=「定位未授权」；点按不发起申请（跳设置） |
| testYandexWeatherItemLocationUnavailableShowsHintAndDoesNotAutoStart | Yandex 镜像 |
| testSpectrumMicNotDeterminedShowsHintWithoutStartingCapture | 未决定 → 「需麦克风权限 · 点按开启」，引擎零启动 |
| testSpectrumMicDeniedShowsSettingsHint | denied → 「麦克风未授权 · 点按设置」 |
| testSpectrumSystemWithoutScreenRecordingPreflightShowsHint | 录屏未授予 → 预检拦截显示提示，不发起 SCK |
| testNoiseMeterMicNotAuthorizedSkipsEngineAndShowsNeedPermission | 未授权 → 引擎零启动，apply() 显示「需要权限」 |
| testUpNextShowsPermissionHintWhenSourceMissingPermission | 无权限源 → 恰 1 个「点按授权日历」提示项；点按路由到源申请恰 1 次 |

新注入点（internal 计数子类可 override）：`currentLocationAuthorizationStatus` / `requestLocationAuthorization` / `openLocationSettings` / `micAuthorizationStatus`（AudioSpectrum+NoiseMeter）/ `screenCaptureAccessPreflight` / `currentHint` / `items`。

---

## 四、验证（全量回归 + TCC 零请求实证）

- 构建：`xcodebuild build-for-testing`（UnitTests, Debug, 独立 derivedDataPath /tmp/LyricsMTMR-dd-r30-build）**TEST BUILD SUCCEEDED**（零新增告警）。
- 全量回归：`xcodebuild test-without-building` 连续两轮 **248 用例（240 基线 + 8 新增）0 失败 0 意外**（第一轮 2 失败为本卡新增天气测试自身的守卫条件笔误——`startLocationUpdates` 调用处漏加 `locationTrackingEnabled &&` 条件，修复后两轮全绿；金丝雀 StockMarketHoursTests 三锚点全绿，WidgetLeakTests 8 全绿）。
- **关键实证（TCC 日志，`log stream --predicate 'subsystem == "com.apple.TCC"'` 全程并行采集，04:10:08~04:11:37）**：
  - **弹窗（"Prompting policy … allow prompt: Allow"）= 0**（修复前第 29 轮单轮 3 次真实弹窗 + 27 次请求风暴）；
  - 应用侧全部事件均为 **preflight=yes 状态查询**（授权门读状态，零副作用）：麦克风 ×2、录屏 ×2、日历/提醒 ×若干、ListenEvent/Accessibility 等系统侧 ×若干；
  - 日志中连续出现 `Failed to match existing code requirement for subject Toxblh.LyricsMTMR` —— ad-hoc 签名 → 每次构建 cdhash 变化 → TCC 身份不匹配的直接系统级证据；
  - 唯一 preflight=no 为测试宿主 teardown 时刻 replayd（系统录屏守护进程）的收尾请求，无任何弹窗。
- 结论：**修复后看板回归（xcodebuild test）不再产生任何权限弹窗，「任务卡在弹窗上等用户点」的根因消除**。

---

## 五、遗留与建议（提醒后续轮次/用户）

1. **治本建议（用户侧，一次配置）**：在 Xcode 为项目配置 DEVELOPMENT_TEAM（自动签名用开发证书），使每次构建签名稳定 → TCC 授权跨构建记忆，即便未来有组件申请也只需授权一次。当前 ad-hoc 签名是「每轮重弹」的结构性原因。**注意**：配置后首次运行仍会弹一次（未决定），此后不再弹。此改动涉及签名配置，需用户确认后由人工在 Xcode 完成（或另开卡评估 `CODE_SIGN_IDENTITY` 工程化）。
2. **后续轮次提醒**：测试宿主即真实 App，注册表测试会实例化全部组件——**任何新组件若在 init 自动触碰受保护服务，回归必弹窗卡人**；本卡已把现有 7 个组件全部惰性化，新增组件请沿用授权门模式（可复跑 /tmp/tcc-r30-run.log 同款命令自查 TCC 日志）。
3. **UpNext 授权入口**：TravelCountdown/MeetingCountdown 无点按能力，未授权时显示「需要权限」，授权路径=系统设置→隐私与安全性→日历；如后续要在设置面板加一键授权按钮（CalendarTabView），可复用 `TBEvents.requestAccess()`（已保留）。
4. **WeType 输入法**：02:33:27~56 的 26 次麦克风请求来自微信输入法语音输入会话（非本项目）；若频繁弹窗可检查其语音输入快捷键/设置。
5. 真机冒烟延续挂账不变（第 8/17~29 轮同口径）：本卡修复后的提示文案/点按申请 UX 观感，留待用户 Touch Bar 真机确认。
