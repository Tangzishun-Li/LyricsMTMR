# LyricsMTMR CPU 占用归因分析报告

> 任务 t_d0a3dcbf。目的：把实测 15% CPU 逐项归因到 文件:行号，按"日常使用"场景（播放音乐看歌词、切换应用、开过设置）评估每个热点的触发条件、频次、影响，并区分"必须保留"与"可优化"。
> 方法：运行时实测（t_705ecd03 已做 sample/footprint）+ 本次全仓四类扫描（同步 IO / 忙等 / 日志 / 定时器）与逐行源码核验。所有行号已对照源码确认。
> 源码根：`/Users/litz/codespace/MTMR with LyricsX /LyricsMTMR`（目录名末尾有空格）。只读分析，未改源码。

---

## 一、归因结论（摘要）

**实测的 15.3~15.6% CPU 几乎 100% 来自同一个东西：已"关闭"的设置窗口在后台以 60fps 持续渲染 SwiftUI 视图树**（sample 两次均落在 `com.apple.SwiftUI.DisplayLink` → `NSHostingView.startAsyncRendering → ViewGraph.updateOutputsAsync`）。它不是"多个小热点叠加"，而是单一异常常驻热点。

日常使用场景下的 CPU 去向构成（估算，10% 为采样波动）：

| 占比 | 热点 | 判定 |
|---|---|---|
| ~93%（15%） | 幽灵设置窗口 60fps DisplayLink | **可优化（异常）** |
| ~2-4% | 歌词 marquee 60fps + KaraokeLabel 30fps 重建 | **可优化（部分）** |
| ~1% | AppleScript 按钮每 5s fork `top -l 2` | **可优化（异常）** |
| ~0.5% | 每次切应用全量重建 Touch Bar items | **可优化（异常）** |
| ~0.1% | 歌词引擎 0.25s playbackTimer（4Hz 轻量） | **必须保留（正常）** |
| ~0% | 其余（设置页一次性 IO、日志、无忙等） | 排除 |

---

## 二、Top 热点明细（按 CPU 贡献排序）

### 热点 1：幽灵设置窗口 —— 15% CPU（实测值，即全部）

- **文件:行号**：
  - `MTMR/App/AppDelegate.swift:143` `private var unifiedSettingsController: UnifiedSettingsWindowController?` —— 强持有，全文件无置 nil 路径；`:156-167` openSettings 仅 nil 时创建
  - `MTMR/Preferences/UnifiedSettingsWindowController.swift:133-137` windowWillClose 只清 `weak static current` + `SettingsWindowState.isVisible = false`，**不释放窗口本体**
  - `UnifiedSettingsWindowController.swift:437-441` `Deck.Background.onAppear` 里 `withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true))` —— 全项目唯一 repeatForever 动画，不订阅任何可见性状态
  - `UnifiedSettingsWindowController.swift:886-892` SettingsTabCache 无限缓存已访问 tab 的 AnyView；`:1119-1127` ZStack 全量挂载
  - `UnifiedSettingsWindowController.swift:421-436` 两个大 RadialGradient（700×700 / 620×620）`.blur(radius: 5)` 每帧重渲
- **触发条件**：打开过一次设置窗口（任意方式关闭，包括点红叉）。之后永续。
- **调用频次**：60fps（DisplayLink），每帧渲染整棵 21-tab 图层树；每 8s 一个动画周期。
- **可能影响**：CPU 15% 常驻（风扇/续航）、CoreAnimation 136MB / 1023 regions、MALLOC 抖动；Touch Bar 本身的动画（Equalizer `:1113`、歌词预览 `LyricsTabView.swift:1057-1058`）都有 `paused:` 保护，唯独 Background 漏了。
- **判定**：**可优化（异常消耗）**。与用户感知症状完全吻合；日常使用中设置窗口只开一次，其余时间 100% 是浪费。

---

### 热点 2：歌词 marquee 60fps —— 日常播放时几乎常驻

- **文件:行号**：
  - `LyricsRendering/LyricsTouchBarItem.swift:371` `marqueeTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / MarqueeMetrics.fps, ...)`；`MarqueeMetrics.fps = 60.0`（`:25`）
  - `:316-321` 普通 LRC 行（无逐字 timetags）且文本溢出 clipWidth → `startMarquee`；`:355-381` startMarquee 每次 `stopMarqueeTimer()` + 重建 timer + `marqueeStartTime = Date()`（`:369`）
  - `:279-285` 暂停分支只调 `pauseProgressAnimation()`，**不 stopMarqueeTimer** → 暂停时空转
- **触发条件**：播放中、当前行无逐字时间标签、文本宽度 > 触摸条 clipWidth。默认 `marqueeEnabled=true`、`marqueeStyle=.marquee`（`LyricsItemConfig.swift:51-52`）→ **普通 LRC 歌曲播放期间几乎常驻**。
- **调用频次**：60fps 主线程 timer；每 tick 做一次 `bounds.origin.x` 变更（`:377-379`）。且每 0.25s 被 playbackTimer 经 Combine 链重进 `handleTextScroll` → startMarquee → timer 重建 + 起点重置 → 滚动每 0.25s 跳回起点（缺陷 B，同时是 4Hz 的 timer 重建开销）。
- **可能影响**：触摸条可见性无关地持续 60fps 主线程定时器 + 每 0.25s 重建；视觉效果反复回跳；暂停播放后 CPU 不降（缺陷 A）。
- **判定**：**可优化**。60→30fps 肉眼无差；timer 复用（仅行切换时重建）；暂停分支补 stopMarqueeTimer。

### 热点 3：KaraokeLabel 每 tick / 每帧重建 —— 播放带时间轴歌词时的 MALLOC 抖动源

- **文件:行号**：
  - `LyricsRendering/KaraokeLabel.swift:167-173` `fullTextWidth`：每次调用新建 `CTFramesetter.create` + `suggestFrameSize`，**不缓存**（同文件 `:129-156` 的 `ctFrame()` 明明有缓存模式可复用）；被 `LyricsTouchBarItem.swift:297` 每次 `onLyricsUpdate` 调用 → 播放中每 0.25s 一次完整文本 shaping（CoreText 布局+测量）
  - `KaraokeLabel.swift:353-370` karaokeTimer 30fps（`KaraokeMetrics.fps=30` `:33`），回调只置 `needsDisplay=true` → draw() 全帧 CTFrameDraw 扫光（`:340-351`）；有 timetags 行才启动，暂停/播完自动退休（`:287/:363-366`）——机制干净
  - `KaraokeLabel.swift:465-501` ruby（romaji 注音）：`drawRubyText` 每帧、每个字形调用 `makeRubyAttributedString` —— 重建 NSAttributedString + size() 测量，且 `:475-483` while 收缩循环最多迭代约 20 次（每次重建+测量）；开启注音时 = 30fps × 每字形 × 多轮测量
- **触发条件**：karaoke 模式 + 播放带逐字时间标签的歌曲（30fps 扫光）；注音开启时叠加 ruby 重建。
- **调用频次**：30fps draw + 4Hz fullTextWidth；ruby 为 30fps × 每字形。
- **可能影响**：MALLOC 瞬时对象抖动（130MB 总量的一部分）、draw 路径耗时随字形数线性增长；注音开启时最重。
- **判定**：30fps 扫光效果本体**必须保留**（视觉需要）；fullTextWidth 缓存、ruby CTLine 预计算、`intrinsicContentSize`（`:158-164` 同样不缓存）**可优化**。

---

### 热点 4：脚本按钮每 5s fork `top -l 2` —— 用户激活配置中实际在跑

- **文件:行号**：`MTMR/Core/AppleScriptTouchBarItem.swift:49` `DispatchQueue.appleScriptQueue.asyncAfter(deadline: .now() + interval)` 递归 `refreshAndSchedule()`；`execute()`（`:64-84`）同步执行 NSAppleScript 脚本（用户配置为 `top -l 2 -n 0 -F | egrep ... | awk`，一次 fork 3 个子进程）；队列定义 `:88`（串行 `mtmr.applescript`）
- **触发条件**：item 存在即常驻（init `:15-38` 编译脚本后立即首跑）。用户 items.json 中 `refreshInterval: 5`。
- **调用频次**：每 5s 一次；`top -l 2` 每次做两次全系统采样，单次耗时数百 ms。
- **可能影响**：瞬时 CPU/IO 峰值每 5s 一次（采样时系统负载虚高、风扇忽转）；阻塞的是串行 appleScriptQueue（**非主线程**，主线程事件循环不受阻，但其它 AppleScript item 会被排队延迟）；每次切应用触发 TouchBar 重建时该 item 重新 init → 重新编译脚本。
- **判定**：**可优化（异常消耗）**。5s 间隔过密；`top -l 2` 可用 1 次采样或直接读 sysctl/sysinfo 替代，或间隔提到 ≥15s。

### 热点 5：每次切应用全量重建 Touch Bar items —— 主线程卡顿源

- **文件:行号**：
  - `MTMR/Core/TouchBarController.swift:337-339` didLaunch / didTerminate / didActivate 三个 NSWorkspace 通知全部指向 `activeApplicationChanged` → `updateActiveApp()`（`:444-446`）
  - `:448-497` `updateActiveApp`：默认 `freezeOnAppSwitch=false` 时**无条件**走 `prepareTouchBar()`（`:490`）全量 `createItems()` 销毁重建（`:623-682`）；`appDidChange`（`:450`）只在用户 override 复位与主题切换分支使用，**默认分支无快速路径** —— 同一应用反复激活也全量重建
- **触发条件**：任何前台应用切换（日常高频）；应用启动/退出也触发。
- **调用频次**：每次前后台切换 1 次（含切回本应用弹 popover 等场景）。
- **可能影响**：主线程一次性重建全部 item（数 10ms 级卡顿、与主线程 CAAnimation dealloc 抖动互相印证）；连锁副作用——歌词 item 重新订阅引擎、AppleScript item 重新编译脚本、定时器全部重建。
- **判定**：**可优化（异常消耗）**。`guard appDidChange`（或 touchBarIsBuilt 且未变更时直接返回）即可消除绝大多数重建。

### 热点 6（P2）：无内存警告响应 —— 内存压力下无兜底

- **文件:行号**：全仓 grep `didReceiveMemoryWarning` / memory pressure 0 命中；`UnifiedSettingsWindowController.swift:886-892` SettingsTabCache 无上限；CoverCache 无 eviction 钩子。
- **触发条件**：系统内存压力（日常低概率，但与 304MB 常驻叠加后风险上升）。
- **判定**：**可优化（健壮性）**。实现 `applicationDidReceiveMemoryWarning` 清 SettingsTabCache + CoverCache.memoryCache。

---

## 三、任务清单逐类排查结论（排除项，避免误改）

| 类别 | 排查结果 | 证据 |
|---|---|---|
| 高复杂度算法 | 仅 ruby while 收缩循环（KaraokeLabel:475-483，每字形≤20 次测量，已列入热点 3）；其余 O(n) 轻量（updateAutoScroll :329-331 map+firstIndex） | 全仓算法扫描 |
| 忙等循环 | **无**（`while true`/`while(1)` 0 命中） | grep 全仓 |
| 大循环内同步 IO | **无**：全部 `Data(contentsOf:)`/`String(contentsOf:)` 在 Preferences 各 tab 一次性读取（KeyBindingTabView:362、ToolsTabView:332、SettingsSync:32/99/141/182 等），打开页面才执行 | grep 全仓 |
| 事件循环阻塞 | **无主线程阻塞**：AppleScript fork 在串行 appleScriptQueue（:88）；`top -l 2` 阻塞该队列而非主线程；NSAlert.runModal 仅用户主动关窗触发 | 调用链核验 |
| 日志序列化开销 | **无热路径日志**：29 处 NSLog/print + 162 处 AppLog 调用点全部事件驱动/一次性（歌曲切换、错误、启动）；playbackTimer 回调（LyricsEngine.swift:711-726）与 draw 路径无任何日志 | grep + 逐点核验 |
| 歌词引擎 0.25s tick | 4Hz、回调轻量（时间计算 + EngineTrackInfo 重建 + timetags map）；启停与播放状态同步（syncPlaybackTimer :440、deinit :488 全清理） | LyricsEngine.swift:707-732, 1098-1118 |
| 设置页同步 IO | 一次性、非热路径，保留（简单正确） | 见上 |

## 四、必须保留 vs 可优化（总表）

**必须保留（正常必要开销）**：
1. 歌词引擎 0.25s playbackTimer —— 进度精确性需要 4Hz 节拍，回调已最简化，启停正确
2. KaraokeLabel 30fps 扫光效果 —— 视觉需求；但需去掉其上的重复计算（fullTextWidth/ruby/intrinsicContentSize）
3. 设置页一次性同步 IO —— 低频非热路径，改异步收益极小且引入复杂度
4. 各 item 的 deinit 清理 / weak self 递归 —— 已是正确模式，勿回退

**可优化（异常消耗，按收益排序）**：
| # | 项 | 预计回收 | 改动点 |
|---|---|---|---|
| 1 | 幽灵设置窗口（热点 1） | **~15% CPU + ~136MB CA**（大头） | AppDelegate:143 改 weak / windowWillClose 回调置 nil；Background repeatForever 加 isVisible 暂停（复用 :1113 模式）；SettingsTabCache 加 LRU |
| 2 | marquee 两缺陷（热点 2） | ~1-2% + 视觉回跳修复 | LyricsTouchBarItem:279-285 补 stop；:355-381 timer 复用；fps 60→30 |
| 3 | KaraokeLabel 重复计算（热点 3） | ~0.5-1.5% + MALLOC 抖动 | fullTextWidth/intrinsicContentSize 缓存；ruby CTLine 预计算 |
| 4 | AppleScript 5s fork（热点 4） | ~0.5-1% + 系统负载虚高 | 间隔 5→≥15s；`top -l 2`→`-l 1` 或 sysctl |
| 5 | 切应用全量重建（热点 5） | 主线程卡顿消除 | updateActiveApp 加 `guard appDidChange` 快速路径 |
| 6 | 内存警告响应（热点 6） | 内存压力兜底 | applicationDidReceiveMemoryWarning 清缓存 |

**预期效果**：仅落地 #1 一项，15% CPU 归零、内存 304MB→~170MB；全部落地后日常使用 CPU ~1-2%。修复均为行为无关改动（生命周期/频率/缓存），不改变 Touch Bar 外观与交互。

---

*本报告与《性能优化总报告_300MB内存与15%CPU.md》《定时器与刷新循环调研报告.md》互为补充：总报告给修复路线图，本报告给"为什么是这些、哪些必须留"的归因依据。下一轮修复卡可直接按本报告第二节热点编号 + 第四节表格落地。*



