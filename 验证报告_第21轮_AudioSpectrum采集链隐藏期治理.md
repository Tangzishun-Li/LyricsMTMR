# 验证报告_第21轮_AudioSpectrum采集链隐藏期治理

- 轮次：第 21 轮（功能/优化迭代第 9 轮）· 子任务 B（实现/优化维度）
- 任务卡：t_5f002e2d（分支 r21/audio，工作区 `.worktrees/round21-B`，基于 main@bc56985）
- 落地目标：第 20 轮 A 卡登记遗留第 11 项前半句收口——实证 AudioSpectrumBarItem 音频采集链（SCK system tap / AVAudioEngine mic engine）在整条 bar 隐藏（黑名单/exitTouchbar）期间是否仍活跃收数；若活跃，评估并落地零权限风险的暂停/恢复路径（隐藏期零采集、恢复自动重启采集并立即刷新显示）
- 日期：2026-08-13

---

## 〇、结论速览

| 项 | 结论 |
|----|------|
| 问题 | **成立**：`AudioSpectrumBarItem.setPaused`（round 20 引入）只暂停 0.04s 显示轮转（`pausableDisplayTimer`），**采集链不在暂停语义内**——SCK stream / mic engine 自 `init` 启动后仅在 `deinit` 与 source 切换时停止，隐藏期间持续活跃收数：系统音频流 48kHz 常开回调、每 1024 样本跑一次 FFT（50% 重叠）、每帧向主线程 hop 送显示数据；mic 路径隐藏期麦克风指示灯常亮（隐私面） |
| 权限风险 | **零新增风险**：TCC 授权（Screen Recording / Microphone）是持久化的（TCC.db 按 bundle+签名记录），engine/stream stop+restart **不重弹授权窗**；macOS 15 每周录屏再确认弹窗是 OS 时间驱动（与启停无关）；且**仓库内已有生产实证路径**——`applySettingsSourceChange` 每次 source 切换即执行 stopSystem/stopMic + startCapture 全套重启，无重弹窗路径 |
| 方案 | **纳入**：采集链并入暂停语义——隐藏时 `stopCapture()`（停 SCK + 停 mic + 重置实时音源时间戳 + 清滚动窗口），恢复时 `startCapture()` 按当前 requestedSource 重建；新增独立 `capturePauseGate`（重复广播幂等，重启不churn）；`SystemAudioTap` 增加 `stopped` 取消标记（防「恢复后立即隐藏」竞态下在途 start Task 复活孤儿 stream）；source 切换在隐藏期只记新值不重启采集（恢复统一重启） |
| 等价性 | 未隐藏时行为严格等价：init 顺序不变（startCapture + startDisplayTimer）、`setPaused` 仅由 TouchBarController 广播触发且未暂停过时幂等 no-op、采集启停全部经主线程 hop + 状态复查；行为差异仅「整条 bar 隐藏期间采集停止」一处 + 恢复首帧由合成/衰减覆盖（不再冻结陈旧光柱，严格更优） |
| 实证 | 分支内 xcodebuild build **BUILD SUCCEEDED** + test **TEST SUCCEEDED —— 166 用例 0 失败 0 意外**（163 基线 + 新增 3 全过，金丝雀锚点 testGoldenAnchors2026/2027/Makeup2026 全绿，WidgetLeakTests 5 用例仍绿无新泄漏） |
| 遗留 | 真机冒烟延续挂账（隐藏期光柱恢复首帧/麦克风指示灯熄灭观感依赖 Touch Bar 真机）；SCK 每周再确认弹窗为 macOS 15 系统行为，与启停无关 |

---

## 一、实证：采集链定位与隐藏期行为（代码证据）

### 1.1 采集链实现定位

`LyricsMTMR/MTMR/Widgets/Media/AudioSpectrumBarItem.swift` 内两条采集链：

| 链 | 实现 | 权限 | 代码位置 |
|----|------|------|----------|
| system（含 auto 默认） | `SystemAudioTap`：`SCShareableContent.excludingDesktopWindows` 取整个 display 的混合音频 → `SCStream(capturesAudio: true, 48kHz, 1ch)` → `addStreamOutput(.audio)` → `startCapture()` | Screen Recording（TCC） | :146-224（tap 类）、:352-371 `startSystem()` |
| mic | `AVAudioEngine` + `inputNode.installTap`（fftSize=1024 buffer）→ `processMicBuffer` | Microphone（TCC） | :380-405 `startMic()` |

### 1.2 采集链生命周期（改动前）

- **启动时机**：`init`（:288 `startCapture()` + :289 `startDisplayTimer()`，与显示轮转同刻启动，非仅播放时）；
- **停止时机**：仅 `deinit`（:304-313）与 `applySettingsSourceChange`（source 切换，:322-331）；
- **与 bar 显隐的关联**：**无**。`setPaused(_:)`（改动前 :315-318）只转发给 `pausableDisplayTimer`（round 20 引入的 0.04s 显示轮转 wrapper），采集链完全不受隐藏影响。

### 1.3 隐藏期行为（改动前）——「隐藏期采集是否空转」答案：**是，活跃收数**

隐藏路径（`TouchBarController` :746-752 `dismissTouchBar` → `setPollingPaused(true)` → 遍历 items/swipeItems 广播 `setPaused(true)`，:762-769）对 AudioSpectrumBarItem 只停掉显示 timer，采集链保持运行：

- **system 链**：SCStream 持续以 48kHz 回调 `stream(_:didOutputSampleBuffer:)` → `ingestSystemSamples`（:427-451）——每缓冲做 RMS 噪声门（低于 ~-66 dBFS 才跳过）、可闻样本 append 进滚动窗、每攒满 1024 样本跑一次 `processWindow` FFT（50% 重叠，约每 21ms 一窗）+ `DispatchQueue.main.async` 送显示；播放中（或环境噪声高于门限）隐藏期 FFT 全速运行；
- **mic 链**：AVAudioEngine tap 持续回调 `processMicBuffer`（:453-467）——RMS 门限（~-54 dBFS）之上同样全速 FFT + 主线程 hop；且**隐藏期麦克风保持开启**（系统麦克风指示灯/控制中心指示持续亮），隐私面问题；
- 显示侧已被 round 20 暂停（25fps 轮转隐藏期不空转），但采集侧「硬件热 + 回调 + FFT + 主线程 hop」全部空转。

**结论**：第 20 轮 A 卡「采集 tap 事件驱动非 Timer 不纳入」的判断只对了一半——事件驱动不等于零成本：事件源（音频硬件）在隐藏期持续产生事件，回调链全速运转。遗留第 11 项前半句（AudioSpectrum 采集 tap 隐藏期治理）本轮实证成立并收口。

---

## 二、评估：暂停/恢复路径与权限风险

### 2.1 零权限风险的启停路径：仓库内已有生产实证

1. **重启路径先例**：`applySettingsSourceChange`（改动前即存在）每次用户在 设置 → 工具 → 音量律动 切换 source 时执行 `stopSystem(); stopMic(); lastRealFeed = 0; startCapture()`——SCK stream 与 mic engine 的 stop+restart 组合是**既有生产路径**，从未引入二次授权弹窗；本卡只是把同一路径接到隐藏/恢复上。
2. **TCC 授权持久性（系统行为）**：Screen Recording / Microphone 授权在首次请求时写入 TCC.db（按 bundle ID + 代码签名记录），状态为 `authorized` 后 `SCStream.startCapture()` / `AVAudioEngine.start()` 不再触发授权 UI；仅当权限被用户在系统设置撤销或系统重置 TCC 时才重新询问——与采集 session 的启停次数无关。
3. **macOS 15 每周录屏再确认**：Sequoia 起系统对录屏权限每周弹出一次再确认（时间驱动，与启停无关），属于 OS 行为，本卡不改变该频率；如实登记见风险点 2。
4. **异常路径覆盖**：
   - `SystemAudioTap.start()` 的 `SCShareableContent` 查询 / `startCapture()` 抛错 → catch → `fail()` → `onFailed` → 显示权限 hint（:360-367），**重启后同一路径重走**：权限仍缺则再次 fail（幂等，hint 保持），权限已授予则正常起流并清除 hint（`feedLevels` 清 hint）；
   - `startMic()` 全程 `MTMRTryOrError` + `engine.start()` try/catch（:383-401）——无输入设备/无权限时 setup 抛错被捕获并打日志，widget 不死、合成兜底照常；错误路径不因重启而新增。

### 2.2 数据连续性损失评估：静默期数据可丢弃

- 频谱是**实时可视化**，无持久状态：`smoothedLevels` 为最近绘制值（隐藏期不绘制），`rolling` 为瞬态 FFT 滚动窗（1024 样本 @48kHz ≈ 21ms，恢复后首批新样本即可重填）；
- 显示侧 round 20 已带 `immediateFireOnResume=true`：恢复瞬间补刷一帧——采集重启（~21-40ms 内首个可闻缓冲到达）之前由合成/衰减动画覆盖，**无冻结帧**（改动前短暂隐藏恢复时反而会因 `lastRealFeed` 新鲜而冻结旧光柱一帧，见第四节等价性对比 3）；
- 与 ClipboardHistory（有历史累积语义）不同，频谱 widget 的契约是「显示正在播放的内容」，隐藏期丢弃的数据无消费者、无历史价值。

### 2.3 结论：可落地

启停路径无新增权限风险、错误路径已覆盖、静默期数据可丢弃——按任务要求落地「隐藏期零采集、恢复自动重启采集并立即刷新显示」。

---

## 三、落地实现（变更明细）

| 文件 | 变更 |
|------|------|
| `LyricsMTMR/MTMR/Widgets/Media/AudioSpectrumBarItem.swift` | ① `SystemAudioTap` 新增 `stopped` 取消标记：`stop()` 置位；`start()` 在 `SCShareableContent` await 后与 `startCapture()` await 后各复查一次（在途 start 不得复活已停流的孤儿 stream，防「恢复后立即隐藏」竞态）；`fail()` 增加 `!stopped` 守卫（停流后的陈旧失败不触发权限 hint）；② 新增 `capturePauseGate = TBPauseGate()`（round 21 注释）——独立于 display timer 的 gate：present 广播对未暂停过的 item 也调 `setPaused(false)`，必须按「状态实际变化」决定是否重启采集（重复广播零副作用）；③ `setPaused`：先停/启显示轮转，再按 gate 变更启停采集，启停经主线程 hop + 状态复查（同 TBPausableTimer 模式，快速 pause/resume 序列最后一次状态为准）；④ 新增 `stopCapture()`（`stopSystem` + `stopMic` + 重置 `lastRealFeed`/`lastAudibleMic`）——统一 stop 路径，`deinit` 与 `applySettingsSourceChange` 改走它；⑤ `applySettingsSourceChange`：隐藏期只记最新 source 不重启采集（恢复时统一重启，避免隐藏期重新起流）；⑥ `stopSystem()` 增 `rolling.removeAll()`（丢弃跨采集会话陈旧窗口，恢复后首批 FFT 全为新鲜样本）；⑦ `startCapture()`/`stopCapture()`/`spectrumTick()` 由 private 放宽为 internal（单测注入点，子类 override 计数） |
| `LyricsMTMR/MTMRTests/PausableTimerTests.swift` | 头部注释补 Round 21 说明；新增「Round 21」节 3 用例（见第五节），沿用既有 helper 与文件（无需 add_files.py 注册，pbxproj 零改动） |

`TouchBarController` **零改动**（第 18 轮 `TBPollPausable` 广播天然覆盖）。

### 设计要点对照需求

1. 隐藏 → 广播 `setPaused(true)` → display timer 无效化 + 采集链停止（SCK 停流 / mic engine 停 + removeTap）→ 隐藏期零采集、无音频硬件热占用 ✓
2. 显示 → 广播 `setPaused(false)` → 采集按当前 requestedSource 重启 + display timer 同参重建并立即补刷一帧 ✓
3. 零权限风险：重启走既有生产路径（source 切换同款）；TCC 持久授权不重弹；异常路径（fail → hint / try-catch）全覆盖 ✓
4. 单测 3 新增（注入式 counting 子类，覆盖启停/幂等/隐藏期 source 变更）✓
5. 等价性论证见第四节 ✓

---

## 四、等价性论证

1. **新建默认未暂停**：gate 默认 false，`init` 顺序不变（`startCapture()` + `startDisplayTimer()`），未隐藏时与改动前逐字节同路径。
2. **广播幂等**：`setPaused` 仅由 `TouchBarController.dismiss/present` 广播触发；未暂停过的 item 收到 `setPaused(false)` → `capturePauseGate.setPaused(false)` 返回 false → **不重启采集**（改动前是 display timer 的 gate 同样 no-op）；重复 dismiss 不双停、重复 present 不重启——零 churn。
3. **恢复首帧语义**：显示侧 `immediateFireOnResume=true` 不变；采集侧恢复时 `lastRealFeed`/`lastAudibleMic` 已在暂停点重置为 0 → 补刷帧走合成/衰减而非「陈旧 feed 冻结」——改动前短暂隐藏（<0.25s）恢复首帧会冻结旧光柱，改动后由动画覆盖，属严格改进且观感不可区分。
4. **采集启动时机**：init / source 切换 / 恢复三处启动点与改动前一致（source 切换在隐藏期延后到恢复，显示侧不可见故语义等价——恢复时按最新 source 起流，与「隐藏期间用户改设置」的预期一致）。
5. **间隔/节奏**：display timer 参数零改动（round 20 同参）；采集侧采样率/通道/滚动窗/FFT 参数零改动，仅生命周期接暂停信号。
6. **竞态**：pause/resume 与采集回调并发——`setPaused` 启停经主线程 hop + gate 复查（最后一次状态为准）；SCK 在途 start 由 `stopped` 标记取消（防孤儿流）；mic tap 回调 `[weak self]` + 主线程 hop，deinit 后自动失效；`SystemAudioTap.stop()` 同步路径与既有 source 切换/deinit 完全一致。
7. **deinit 语义**：由 `stopSystem()+stopMic()` 改为 `stopCapture()`（内容相同 + 2 个时间戳重置，无行为差异）；display timer 由 wrapper 承接（round 20 不变）。

---

## 五、单测清单（步骤③）

文件 `LyricsMTMR/MTMRTests/PausableTimerTests.swift` 新增「Round 21」节 3 用例（沿用既有 helper——pumpRunLoop/waitUntil/testIdentifier，托管测试主线程；counting 子类 `CountingSpectrumItem` override `startCapture`/`stopCapture`/`spectrumTick` 计数，**不触碰真实 SCK/AVAudioEngine/LyricsEngine**——三个方法为 round 21 起的 internal 注入点），3 用例合计 ~3.3s：

| # | 用例 | 验证点 |
|----|------|--------|
| 1 | testAudioSpectrumItemPauseStopsCaptureAndTicksResumeRestarts | init 恰好启动一次采集；`setPaused(true)` 后 `stopCapture` 恰好一次 + display tick 冻结（≥2 interval 不增长）+ 采集不重启；`setPaused(false)` 后 `startCapture` 第二次 + 立即补刷一帧（immediateFireOnResume） |
| 2 | testAudioSpectrumPauseBroadcastIsIdempotent | 未暂停过的 item 收到 present 广播 `setPaused(false)` 零副作用（不重启不停止）；重复 dismiss 广播不双停；第一次真实 resume 重启一次，重复 present 广播不再重启 |
| 3 | testAudioSpectrumSettingsChangeWhilePausedDefersRestart | settingsDriven item 走真实 `UserDefaults.didChangeNotification`：隐藏期改 source（system→mic）只记新值不重启采集（startCount 不变）；resume 后以最新 source 重启（startCount +1）；测试结束恢复原 defaults 值（defer） |

回归：全量 166 用例 = 163 基线 + 3 新增，0 失败 0 意外；金丝雀锚点 `testGoldenAnchors2026/2027/Makeup2026` 全绿；WidgetLeakTests 5 用例仍绿（无新泄漏面——`capturePauseGate` 无闭包持有、hop 全 `[weak self]`）。

---

## 六、验证记录

```
xcodebuild build -project LyricsMTMR.xcodeproj -scheme MTMR -configuration Debug CODE_SIGNING_ALLOWED=NO -derivedDataPath /tmp/LyricsMTMR-dd-r21b-build
  → ** BUILD SUCCEEDED **

xcodebuild test -project LyricsMTMR.xcodeproj -scheme UnitTests -configuration Debug -derivedDataPath /tmp/LyricsMTMR-dd-r21b-test
  → ** TEST SUCCEEDED —— Executed 166 tests, with 0 failures (0 unexpected) **
    （Round 21 三用例全过：1.630s / 1.017s / 0.612s；PausableTimerTests 21/21 = 18 既有 + 3 新增；
      金丝雀 testGoldenAnchors2026/2027/Makeup2026 全绿；WidgetLeakTests 5/5 全过无新泄漏）
```

构建/测试全程在分支 r21/audio 内完成，未触碰其他分支，未 push（父任务收口统一推送）；本轮不触发全量回归（第 20 轮收口整体 163 用例实证，隔代规则下预计第 22 轮触发，届时基线口径 163）。

---

## 七、风险点与遗留

1. **SCK 在途启动竞态**：`stopped` 标记在两个 await 检查点复查，`guard` 与 `self.stream = stream` 之间为纯同步代码（stop 只能在 await 点插入）——竞态窗口已闭合；即使极端调度下仍残留，后果仅为一次多余起流后被 stop（自我纠正），不违反零采集承诺。
2. **macOS 15 每周录屏再确认弹窗**：Sequoia 起系统对 Screen Recording 权限每周再确认一次（时间驱动，与采集启停无关），隐藏期暂停采集不改变该频率；属 OS 行为如实登记，非本卡引入。
3. **真机冒烟仍缺失**：隐藏期麦克风指示灯熄灭、恢复首帧光柱观感依赖 Touch Bar 真机；逻辑已由 3 单测覆盖，渲染观感留待用户验证（延续第 8/17/18/19/20 轮同类遗留口径）。
4. **采集链内部 FFT 未节流**：隐藏期停止后无回调；显示期 SCK 回调频率由系统驱动（~21ms/窗），与改动前一致，非本轮引入。
5. **第 20 轮 A 卡遗留第 11 项后半句**（ClipboardHistory 可改 NSPasteboard.observe 事件驱动消除 1s 轮询）保持挂账，不在本卡范围。
