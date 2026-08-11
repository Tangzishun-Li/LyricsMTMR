# LyricsMTMR 内存/渲染调研报告（304MB 物理内存）

> 只读调研，未修改任何源码。运行时证据：CoreAnimation 136MB / 1023 regions、MALLOC_NANO 53MB、MALLOC_SMALL 44MB、MALLOC_TINY 27MB、MALLOC_MEDIUM 6MB、untagged VM_ALLOCATE 17MB，total 304MB，peak 322MB（低于峰值 → 稳定平台期，非无限泄漏）。

## 结论先行

304MB 中约 136MB CoreAnimation 的主要来源已定位：**设置窗口（"Night Deck"）从未被释放** —— `AppDelegate` 强持有窗口控制器且关窗后不释放，`repeatForever` 动画 + 两个大尺寸 blur 渐变 + 21 个 tab 的图层树（`SettingsTabCache` 全量缓存、ZStack 全量挂载）永久驻留，窗口"关闭"后仍在离屏渲染。其余大头是歌词渲染的**每 tick/每帧重建**（CTFramesetter、ruby 布局）造成的堆分配抖动（MALLOC_TINY+SMALL+NANO ≈ 124MB 中大量是这类瞬时对象）。**全仓库未实现任何内存警告响应。**

---

## 1. "Night Deck" 设计系统 → 离屏渲染堆积 CoreAnimation（136MB / 1023 regions）

证据：`Preferences/UnifiedSettingsWindowController.swift`

| 行号 | 问题 |
|---|---|
| :421-428 | `RadialGradient` **700×700pt** + `.blur(radius: 5)`（:427）overlay 在背景右上 |
| :429-436 | 第二个 `RadialGradient` **620×620pt** + `.blur(radius: 5)`（:435）左下 |
| :437-441 | `withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true))` 驱动 `drifting`，**永不停止** |
| :1113 | 对比：`Equalizer` 已正确实现 `paused: !windowState.isVisible` 暂停，但 `Deck.Background` 没有观察可见性 |
| :459-473 | `Card` 每张卡 `.shadow(color: .black.opacity(0.28), radius: 10, y: 4)`（:472）→ 每张卡一个离屏 shadow 层；全 Preferences 共 **19 处 `.shadow(`**（Pill :548、Segmented :621、NavItem :1212、appIcon :1040、SlotsTabView :132/:466/:563 等） |
| :886-892 | `SettingsTabCache` 缓存**所有访问过的 tab 的 AnyView**，仅 profile 导入时清除（:937） |
| :1119-1127 | `content` 的 ZStack 把**所有已缓存 tab 同时挂载**在视图树中（opacity 0 也保留 CALayer）——21 个 tab → 上千 CALayer，与实测 **1023 regions** 吻合 |

**根本性生命周期 bug（"窗口关闭后仍离屏渲染"的直接原因）：**
- `App/AppDelegate.swift:143` `private var unifiedSettingsController: UnifiedSettingsWindowController?` —— **强持有**；
- `AppDelegate.swift:156-167` `openSettings` 创建后**永不置 nil**；
- `UnifiedSettingsWindowController.swift:133-137` `windowWillClose` 只把**弱引用** `current = nil` 并置 `isVisible = false`，窗口、NSHostingView、整棵图层树、`repeatForever` 动画全部继续存活 → SwiftUI DisplayLink 持续重绘不可见窗口（与 sample 中"SwiftUI DisplayLink 持续重绘"吻合）。

**内存估算：**
- 700×700pt @2x = 1400×1400px RGBA ≈ **7.8MB**/backing；blur 需要源+结果两份缓冲 ≈ **~16MB**；两个渐变合计 ≈ **24~30MB 离屏缓冲**；
- `repeatForever` 每帧让 blur 层失效重渲 → 每帧产生新的 CA backing store/IOSurface 暂存（blur 内容每帧变化无法缓存）；
- 全窗口 980×660 @2x 图层树（每 tab 数百层 × 访问过的 tab 数）是 136MB 的主体；窗口永不释放 → 稳定平台期（与 peak 322MB / 当前 304MB 一致）。

## 2. LyricsIntegration 缓存检查

| 文件:行号 | 结论 |
|---|---|
| `LyricsIntegration/CoverCache.swift:12-23` | **有界，无问题**：NSCache countLimit=100 + totalCostLimit=20MB，:82 按 `w*h*4` 正确计 cost；ImageIO 256px 降采样解码（:10, :62-77）；URLCache 20MB 内存 / 100MB 磁盘（:16） |
| `CoverCache.swift:51` | 小瑕疵：fallback 读 `URLCache.shared` 而非自定义 session cache（:16），降级路径大概率 miss 重复请求——非内存问题 |
| `LyricsIntegration/LyricsSelectionCache.swift:30-121` | 小型 JSON 存 UserDefaults，有界，无问题 |
| `LyricsIntegration/NetEaseProvider.swift:60-165` | **无缓存**：每次换歌重新下载+解析 YRC/KRC/LRC（:265-357, :366-441），结果只保存在 `LyricsEngine` 当前歌曲 @Published（LyricsEngine.swift:444-446）——**非内存问题**，是重复网络/CPU（建议加小型 SimpleLyrics LRU） |

## 3. Widgets 大对象持有

- `LyricsRendering/LyricsTouchBarItem.swift:44-47`：`artworkView` 持有 CoverCache 的 256px 缩略图（有界）；`KaraokeLabel` 为 NSTextField 子类，正常。
- **全仓库无 WebView**（grep WKWebView/WebView/NSVisualEffectView 均无命中）。
- `Widgets/WidgetKit.swift:48-62` `TB.symbol()`：每次调用新建 NSImage（drawingHandler 离屏绘制），全仓仅 2 处直接调用，非热路径。
- `Widgets/Life/StockBarItem.swift:400-472`：`renderStock` 每次刷新新建小尺寸 NSImage（~30pt 高），秒级刷新，可接受。
- 结论：Widgets 无无界大对象；大头全在设置窗口（见 §1）。

## 4. 每帧/每 tick 重建模式（同时烧 CPU 和堆分配）

| 文件:行号 | 问题 |
|---|---|
| `LyricsRendering/KaraokeLabel.swift:167-173` `fullTextWidth` | **每次调用新建 CTFramesetter + suggestFrameSize，且不缓存**（对比 :129-156 `_ctFrame` 有缓存）。调用方 `LyricsTouchBarItem.swift:297` 在**每次 onLyricsUpdate 都执行**（行未变也执行），引擎每 **0.25s** 发布一次（`LyricsIntegration/LyricsEngine.swift:711` playbackTimer）→ 播放中每 0.25s 一次完整文本 shaping → CT 对象 + 堆分配持续（MALLOC_TINY/SMALL 贡献者） |
| `KaraokeLabel.swift:465-501` `makeRubyAttributedString`/`drawRubyText` | **每次 draw() 为每个 romaji 注解重建** NSAttributedString + NSFont + 测量循环 + `CTLineCreateWithAttributedString`（:498），draw 由 **30fps 定时器**（:353-370）驱动 → drawRomajin 开启时每帧全量重建 ruby 布局。`romajinAnnotations`（:96）已存在，完全可预计算缓存 CTLine |
| `LyricsTouchBarItem.swift:371-381` | marquee **60fps** 定时器（`Timer.scheduledTimer`）常驻主 runloop，Touch Bar 不可见时也持续触发并写 `bounds.origin.x`（:377-379） |
| `KaraokeLabel.swift:353-370` | karaoke 30fps 定时器同样不感知可见性 |
| `KaraokeLabel.swift:215-282` | 已做对的部分：`setProgressAnimation` 每行只重建一次（`LyricsTouchBarItem.swift:61-64, 234-244` 的 lastAnimated* 去重），高亮字符串+CTFrame 缓存于 `_progressCTFrame`（:277）——不要回退 |

## 5. 内存警告 / 自动清理 / 图层复用

- **完全没有实现**：grep `didReceiveMemoryWarning` / memory pressure 处理 —— 全仓 0 命中；`AppDelegate.swift` 未实现该方法。
- 唯一 NSCache 限额在 `CoverCache.swift:21-22`，无 eviction 钩子；`SettingsTabCache` 无上限、无警告清理；无图层复用模式。

## 6. 机制估算 + 逐项优化建议

**机制**：设置窗口关闭 ≠ 释放。AppDelegate 强持有控制器 → NSWindow/NSHostingView/全部 CALayer（含所有访问过 tab 的图层 + blur/shadow 离屏 backing store）驻留；`repeatForever` 保持 DisplayLink 激活，blur 层每帧失效重渲 → CA 持续分配/保留 IOSurface（1023 regions）；blur 需源+目标双 backing（两个渐变 ≈ 24~30MB），19 处 shadow 使每个卡片/胶囊离屏渲染。内容恒定后不再增长 → 304MB 稳定平台（peak 322MB）。

**优化建议（按收益排序）：**

1. **关窗即释放（最大单项，预计回收大部分 136MB）**：`AppDelegate.swift:158` 在 `UnifiedSettingsWindowController.swift:133` `windowWillClose` 中回调置 `unifiedSettingsController = nil`（`openSettings:157` 已支持 `window == nil` 时重建）；或给 `SettingsTabCache` 加"窗口关闭时 removeAll"。整棵图层树+动画随窗口释放。
2. **暂停 Background 动画**：`Deck.Background`（:437-441）观察 `SettingsWindowState.isVisible`，不可见时停止 `repeatForever`（复用 :1113 Equalizer 的 paused 模式）。
3. **去掉两处 `.blur(radius: 5)`**（:427, :435）：CGContext **预渲染静态模糊纹理**（启动一次），动画只做 opacity/transform —— 消除 blur 每帧重渲。
4. **削减 19 处 shadow**：重点 `Card`（:472）、`Pill`（:548）、`NavItem`（:1212）；每处 shadow = 一个离屏层。
5. **SettingsTabCache 加 LRU**（:886-892）：只保留最近 3~5 个 tab；暴露 `removeAll()` 给内存警告。
6. **实现 `applicationDidReceiveMemoryWarning`**：清 `SettingsTabCache`、`CoverCache.memoryCache.removeAllObjects()`、`URLCache.shared.removeAllCachedResponses()`。
7. **缓存 `fullTextWidth`**（`KaraokeLabel.swift:167-173`）：与 `_ctFrame` 同生命周期缓存，消除每 0.25s 的 CTFramesetter 重建。
8. **预计算 ruby CTLine**（`KaraokeLabel.swift:465-501`）：`romajinAnnotations` 里每个注解在布局时算好最终 NSAttributedString/CTLine，draw 只 `CTLineDraw`。
9. **定时器感知可见性**：marquee 60fps（`LyricsTouchBarItem.swift:371`）与 karaoke 30fps（`KaraokeLabel.swift:355`）在 Touch Bar 不可见时 invalidate。
10. **可选**：NetEase lyrics 加小型 LRU（`NetEaseProvider.swift:60-165`），省重复下载+解析。
