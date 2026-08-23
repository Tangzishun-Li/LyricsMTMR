//
//  DesktopLyricsWindowController.swift
//  LyricsMTMR
//
//  Round 51 (A): 桌面歌词窗口 MVP — 歌词产品空白面补全（前端体验/UI 维度）。
//
//  无边框/透明/置顶/非激活样式的桌面歌词悬浮窗：
//  - NSPanel（.nonactivatingPanel + .fullSizeContentView），不抢焦点；
//  - 显示当前行卡拉 OK 歌词 + 前/后 1 行上下文（三行竖排，当前行复用
//    KaraokeLabel 逐字高亮，上下文行用普通 NSTextField 降透明度）；
//  - 无歌词/暂停时显示占位文案；单击窗口隐藏，拖拽空白处 reposition；
//  - 位置持久化到 UserDefaults（com.lyricsmtmr.desktopLyrics.frame），
//    字号走独立键（com.lyricsmtmr.desktopLyrics.fontSize），
//    字体族/颜色复用 LyricsItemConfig（与 Touch Bar 歌词同源）。
//
//  This source code is licensed under GPL 2.0 (karaoke rendering adapted
//  from LyricsX — see KaraokeLabel.swift header).

import Cocoa
import Combine

// MARK: - 纯逻辑：卡拉 OK 进度映射（LyricsEngine 与桌面歌词窗口共享）

/// 把一行歌词的 word timetags 映射为「距当前播放时刻的相对进度」数组。
/// 公式与 LyricsEngine.updateKaraokeProgress 原实现逐字节等价：
///   progress[i] = (timetags[i].0 + linePosition - timeDelay - playbackTime, timetags[i].1)
/// 抽为纯函数后两侧共用同一数据源，杜绝两处公式漂移。
enum LyricsKaraokeMapper {
    static func progress(
        timetags: [(TimeInterval, Int)],
        linePosition: TimeInterval,
        timeDelay: TimeInterval,
        playbackTime: TimeInterval
    ) -> [(TimeInterval, Int)] {
        timetags.map { ($0.0 + linePosition - timeDelay - playbackTime, $0.1) }
    }
}

// MARK: - 纯逻辑：三行歌词布局上下文

/// 桌面歌词窗口的内容布局（纯函数，便于单测）。
enum DesktopLyricsLayout {
    struct LineContext: Equatable {
        let prev: String?
        let current: String?
        let next: String?
    }

    /// 从歌词行数组 + 当前行号求「前/当前/后」三行文本。
    /// 越界/空数组/nil 行号一律返回全 nil（调用方走占位分支）。
    static func lineContext(lines: [SimpleLyrics.Line], currentIndex: Int?) -> LineContext {
        guard let idx = currentIndex,
              !lines.isEmpty,
              idx >= 0,
              idx < lines.count else {
            return LineContext(prev: nil, current: nil, next: nil)
        }
        return LineContext(
            prev: idx > 0 ? lines[idx - 1].content : nil,
            current: lines[idx].content,
            next: idx + 1 < lines.count ? lines[idx + 1].content : nil
        )
    }

    /// 占位文案决策：返回非空字符串表示「显示占位」，空串表示「渲染歌词」。
    /// 无曲目 → 等待播放；有曲目但暂停 → 已暂停；播放中但歌词未就绪 → 加载中。
    static func placeholder(trackTitle: String, isPlaying: Bool, hasLyrics: Bool) -> String {
        if trackTitle.isEmpty { return "♪ 等待播放…" }
        if !isPlaying { return "♪ 已暂停" }
        if !hasLyrics { return "♪ 加载歌词…" }
        return ""
    }
}

// MARK: - 纯逻辑：窗口可见性状态机

/// 窗口控制器可见性三态（show/hide/toggle 幂等），纯状态机便于单测。
enum DesktopLyricsVisibility: Equatable {
    case hidden
    case visible

    var isVisible: Bool { self == .visible }

    mutating func show() { self = .visible }
    mutating func hide() { self = .hidden }
    mutating func toggle() { self = isVisible ? .hidden : .visible }
}

// MARK: - 纯逻辑：长行滚动（round 52）

/// 桌面歌词窗口长行滚动的纯函数决策与相位（round 52 新增）。
///
/// 机制与 LyricsTouchBarItem（round 24）同源：对「文本宽 > 可视区宽」的长行，
/// 有 timetag 的卡拉 OK 行走 follow 跟随滚动（让正在演唱的字保持在可视区），
/// 无 timetag 长行走 0→overflowWidth 循环 marquee；两者均为 bounds.origin.x
/// 平移——KaraokeLabel 的卡拉 OK 高亮 clip 随文本同移，逐字高亮不脱位
/// （R51 D11 遗留点「滚动与逐字高亮共用当前行标签」评估结论）。
enum DesktopLyricsMarquee {
    /// 长行判定：文本渲染宽度超出可用区宽度即触发滚动。
    static func needsMarquee(textWidth: CGFloat, availableWidth: CGFloat) -> Bool {
        textWidth > availableWidth
    }

    /// 循环滚动总行程：文本尾+间距离开可视区右缘所需平移量，下限 0。
    static func overflowWidth(textWidth: CGFloat, availableWidth: CGFloat, padding: CGFloat) -> CGFloat {
        max(0, textWidth - availableWidth + padding)
    }

    /// 循环滚动可用时长：下一行歌词到来前的窗口（无下一行用默认预算），下限钳制。
    static func nextLineTimeBudget(
        nextLinePosition: TimeInterval?,
        playbackTime: TimeInterval,
        defaultBudget: TimeInterval,
        minBudget: TimeInterval
    ) -> TimeInterval {
        let next = nextLinePosition ?? (playbackTime + defaultBudget)
        return max(next - playbackTime, minBudget)
    }

    /// 循环 marquee 相位：0→overflowWidth 线性推进，达预算后回绕从头开始
    /// （R24 先例：循环滚动相位从头开始无实质差异）。
    static func marqueeOffset(elapsed: TimeInterval, budget: TimeInterval, overflowWidth: CGFloat) -> CGFloat {
        guard budget > 0, overflowWidth > 0 else { return 0 }
        let t = elapsed.truncatingRemainder(dividingBy: budget) / budget
        return t * overflowWidth
    }

    /// follow 跟随目标偏移：让正在演唱的字符出现在可视区 ratio 处，夹在 [0, overflowWidth]。
    static func followOffset(charX: CGFloat, clipWidth: CGFloat, ratio: CGFloat, overflowWidth: CGFloat) -> CGFloat {
        min(overflowWidth, max(0, charX - clipWidth * ratio))
    }
}

// MARK: - 纯逻辑：位置记忆屏幕边界校验（round 59 c）

/// 位置记忆恢复前的屏幕边界守卫（R51 A 卡遗留 4）：用户改坏 frame 后记忆原点
/// 可能完全落到所有屏幕之外，仅靠「原点在屏内」判定拦不住（原点在外=整窗外，
/// 但若只查原点、窗口主体在屏内的情况又会被误杀）——统一按「记忆 frame 与
/// 任一屏幕 frame 有交集」判定：部分越界保留（macOS 允许窗口半藏屏外，可能
/// 是用户有意为之），完全在外 → 忽略记忆值用默认位。
enum DesktopLyricsFrameGuard {
    /// 记忆 frame 是否至少与一块屏幕相交（相交即可恢复，完全在外才回退）。
    static func isRecoverable(frame: NSRect, screens: [NSRect]) -> Bool {
        screens.contains { $0.intersects(frame) }
    }

    /// 从记忆字符串求可恢复的原点：空串/垃圾串/解码失败/完全屏外一律 nil
    /// （调用方走 R51 默认位置计算），屏内原点原样返回。
    static func recoverableOrigin(raw: String, size: NSSize, screens: [NSRect]) -> NSPoint? {
        guard let origin = DesktopLyricsWindowController.decodeFrameOrigin(raw),
              isRecoverable(frame: NSRect(origin: origin, size: size), screens: screens) else {
            return nil
        }
        return origin
    }
}

// MARK: - 桌面歌词窗口控制器

final class DesktopLyricsWindowController: NSObject {
    static let shared = DesktopLyricsWindowController()

    /// 面板样式常量（与 TouchBarMirrorWindowController 同构）。
    private enum Metrics {
        static let horizontalPadding: CGFloat = 18
        static let verticalPadding: CGFloat = 10
        static let lineSpacing: CGFloat = 3
        static let minWidth: CGFloat = 180
        static let maxWidthRatio: CGFloat = 0.8
        static let maxWidthCap: CGFloat = 900
        static let defaultBottomInset: CGFloat = 100
        static let contextAlpha: CGFloat = 0.55
        static let placeholderAlpha: CGFloat = 0.6
    }

    private var panel: NSPanel?
    private var backgroundView: NSView?
    private var prevLabel: NSTextField?
    private var currentLabel: KaraokeLabel?
    private var nextLabel: NSTextField?
    private var placeholderLabel: NSTextField?

    private var visibility: DesktopLyricsVisibility = .hidden
    var isVisible: Bool { visibility.isVisible }

    private var cancellables = Set<AnyCancellable>()
    private var engine: LyricsEngine { .shared }
    private var config: LyricsItemConfig { .shared }

    /// 卡拉 OK 动画重建守卫（同 LyricsTouchBarItem）：仅行/模式切换时重建
    /// keyframes，常规 0.25s 播放 tick 不复建（KaraokeLabel 内部 30fps 自走）。
    private var lastAnimatedLineIndex: Int?
    private var lastAnimatedClickAction: LyricsClickAction?
    private var lastAnimatedLyricsId: ObjectIdentifier?
    private var lastPlaybackState: PlaybackState?

    // MARK: 长行滚动（round 52）状态

    /// 滚动时序常量（与 LyricsTouchBarItem.MarqueeMetrics 同源，round 24 审计值）。
    private enum MarqueeMetrics {
        static let fps: Double = 30.0
        static let defaultTimeBudget: TimeInterval = 4.0
        static let minTimeBudget: TimeInterval = 1.0
        static let overflowPadding: CGFloat = 15
        static let followVisibleRatio: CGFloat = 0.65
        static let animationDuration: TimeInterval = 0.2
    }

    private var marqueeTimer: Timer?
    private var marqueeStartTime: Date?
    private var marqueeOverflowWidth: CGFloat = 0
    private var marqueeTimeBudget: TimeInterval = MarqueeMetrics.defaultTimeBudget
    /// OPT-5 ② 同款守卫：timer 当前服务的行/歌词对象——同一行复用 timer 不重建，
    /// 仅行切换时重建（防 0.25s playback tick 反复重启导致滚动回跳）。
    private var marqueeLineIndex: Int?
    private var marqueeLyricsId: ObjectIdentifier?

    /// 程序化 setFrame 也会触发 didMove —— 用此标记区分用户拖拽，只在用户
    /// 拖动结束时持久化（程序化定位不写盘，避免启动/屏幕切换瞬间覆盖用户记忆位置）。
    private var isProgrammaticMove = false

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - 生命周期（AppDelegate 接线）

    /// 应用退出清理：停止订阅、关闭并释放面板。
    func shutdown() {
        cancellables.removeAll()
        resetMarquee()
        panel?.orderOut(nil)
        panel = nil
        backgroundView = nil
        prevLabel = nil
        currentLabel = nil
        nextLabel = nil
        placeholderLabel = nil
        visibility = .hidden
    }

    // MARK: - 显示/隐藏

    func show() {
        let wasHidden = !visibility.isVisible
        visibility.show()
        guard wasHidden else { return }

        if panel == nil {
            buildPanel()
        }
        positionPanel(restoreSaved: true)
        panel?.orderFront(nil)
        // r57-g：面板已 orderFront，恢复可见 → 补启动挂起的卡拉 OK 动画 +
        // 解冻既有动画（隐藏期 windowVisibilityDidChange(false) 冻结在当前进度）。
        currentLabel?.windowVisibilityDidChange(isVisible: true)
        // marquee 侧：隐藏期引擎 tick 只存参数不建表（updateMarquee 竞态复查），
        // 恢复可见后按当前行重建（refreshContent → onLyricsUpdate → updateMarquee）。
        setupSubscriptions()
        refreshContent()
    }

    func hide() {
        let wasVisible = visibility.isVisible
        visibility.hide()
        guard wasVisible else { return }
        currentLabel?.pauseProgressAnimation()
        // r57-g：冻结卡拉 OK 动画（防 orderOut 后引擎 tick 重建 30fps 离屏重绘）。
        currentLabel?.windowVisibilityDidChange(isVisible: false)
        resetMarquee()
        panel?.orderOut(nil)
    }

    func toggle() {
        if visibility.isVisible {
            hide()
        } else {
            show()
        }
    }

    /// 设置页字号滑块实时生效。
    func applyFontSize() {
        applyTypography()
        refreshContent()
    }

    /// 设置页长行滚动开关实时生效：关→立即停止并归位；开→按当前行重建。
    func applyMarqueeSetting() {
        guard visibility.isVisible else { return }
        if AppSettings.desktopLyricsMarqueeEnabled {
            refreshContent()
        } else {
            resetMarquee()
        }
    }

    /// 设置页「重置窗口位置」（R51 A 卡遗留 4，round 59 c）：清空位置记忆键，
    /// 运行中的窗口立即回主屏幕默认位（复用 R51 defaultOrigin 计算逻辑）；
    /// 窗口未显示时仅清键——下次 show() 恢复时记忆为空自然落默认位。
    /// 清键与定位均属程序化移动（不触发 didMove 落盘），不会回写记忆值。
    func resetPosition() {
        AppSettings.desktopLyricsFrame = ""
        guard visibility.isVisible, panel != nil else { return }
        positionPanel(restoreSaved: false)
    }

    // MARK: - 面板构建

    private func buildPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 100),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.hasShadow = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false

        let bg = NSView(frame: panel.contentView!.bounds)
        bg.wantsLayer = true
        bg.layer?.backgroundColor = NSColor(white: 0.06, alpha: 0.62).cgColor
        bg.layer?.cornerRadius = 10
        bg.layer?.borderWidth = 0.5
        bg.layer?.borderColor = NSColor(white: 0.55, alpha: 0.28).cgColor
        // round 52：卡内裁剪——长行 marquee 滚动文本不越出圆角卡边界（Touch Bar
        // 侧由 stackView.masksToBounds 承担，桌面窗口由背景视图承担同款职责）。
        bg.layer?.masksToBounds = true
        bg.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(bg)
        backgroundView = bg

        // 单击窗口 → 隐藏（拖拽会被 isMovableByWindowBackground 消费，
        // NSClickGestureRecognizer 在位移超过阈值时自动取消，二者不冲突）。
        let click = NSClickGestureRecognizer(target: self, action: #selector(handleClick))
        bg.addGestureRecognizer(click)

        let prev = NSTextField(labelWithString: "")
        let current = KaraokeLabel(labelWithString: "")
        let next = NSTextField(labelWithString: "")
        let placeholder = NSTextField(labelWithString: "")

        for label in [prev, next, placeholder] {
            label.lineBreakMode = .byTruncatingTail
            label.isBezeled = false
            label.drawsBackground = false
            label.refusesFirstResponder = true
            label.alignment = .center
        }
        current.lineBreakMode = .byClipping
        current.isBezeled = false
        current.drawsBackground = false
        current.refusesFirstResponder = true
        current.alignment = .center

        for label in [prev, current, next] {
            bg.addSubview(label)
        }
        placeholder.isHidden = true
        bg.addSubview(placeholder)

        prevLabel = prev
        currentLabel = current
        nextLabel = next
        placeholderLabel = placeholder

        self.panel = panel
        applyTypography()
    }

    private func applyTypography() {
        let font = desktopFont()
        let textColor = resolveDesktopTextColor()
        let progressColor = resolveDesktopProgressColor()
        currentLabel?.font = font
        currentLabel?.textColor = textColor
        currentLabel?.progressColor = progressColor
        prevLabel?.font = font
        prevLabel?.textColor = textColor.withAlphaComponent(Metrics.contextAlpha)
        nextLabel?.font = font
        nextLabel?.textColor = textColor.withAlphaComponent(Metrics.contextAlpha)
        placeholderLabel?.font = font
        placeholderLabel?.textColor = textColor.withAlphaComponent(Metrics.placeholderAlpha)
    }

    // MARK: - 桌面歌词独立配色（round 55 A）

    /// 设置页切换独立配色开关 / 更改颜色时调用：立即刷新当前显示。
    func applyColors() {
        guard visibility.isVisible else { return }
        applyTypography()
        // 卡拉 OK 动画颜色同步（若当前行有动画，需重建以使用新进度颜色）。
        if let current = currentLabel, let lineIndex = lastAnimatedLineIndex,
           let lyrics = engine.currentLyrics, lineIndex < lyrics.lines.count {
            let line = lyrics.lines[lineIndex]
            if !line.timetags.isEmpty {
                let progress = LyricsKaraokeMapper.progress(
                    timetags: line.timetags,
                    linePosition: line.position,
                    timeDelay: lyrics.adjustedTimeDelay,
                    playbackTime: engine.trackInfo.playbackTime
                )
                let style: KaraokeStyle = config.karaokeStyle == .jump ? .jump : .progressive
                current.setProgressAnimation(color: resolveDesktopProgressColor(), progress: progress, style: style)
            }
        }
    }

    /// 解析桌面歌词文字颜色：独立配色开启时从 AppSettings hex 读取，否则回退全局。
    private func resolveDesktopTextColor() -> NSColor {
        if AppSettings.desktopLyricsUseIndependentColors,
           let color = AppSettings.desktopLyricsColor(from: AppSettings.desktopLyricsTextColorHex) {
            return color
        }
        return config.textColor
    }

    /// 解析桌面歌词进度颜色：独立配色开启时从 AppSettings hex 读取，否则回退全局。
    private func resolveDesktopProgressColor() -> NSColor {
        if AppSettings.desktopLyricsUseIndependentColors,
           let color = AppSettings.desktopLyricsColor(from: AppSettings.desktopLyricsProgressColorHex) {
            return color
        }
        return config.progressColor
    }

    /// 桌面歌词窗口字号独立于 Touch Bar（com.lyricsmtmr.desktopLyrics.fontSize），
    /// 字体族/颜色复用 LyricsItemConfig（与 Touch Bar 歌词同源）。
    /// round 55 A：开启独立配色时，文字/进度颜色从 AppSettings 独立键读取。
    private func desktopFont() -> NSFont {
        let size = CGFloat(AppSettings.desktopLyricsFontSize)
        if config.fontName == "System" {
            return NSFont.systemFont(ofSize: size)
        }
        return NSFont(name: config.fontName, size: size) ?? NSFont.systemFont(ofSize: size)
    }

    // MARK: - 位置

    /// 默认位置：主屏幕底部居中（略高于 Dock）。
    private func defaultOrigin(for size: NSSize) -> NSPoint {
        guard let screen = NSScreen.main else { return NSPoint(x: 200, y: 200) }
        let sf = screen.visibleFrame
        let x = sf.midX - size.width / 2
        let y = sf.minY + Metrics.defaultBottomInset
        return NSPoint(x: x, y: y)
    }

    private func positionPanel(restoreSaved: Bool) {
        guard let panel else { return }

        var size = panel.frame.size
        // 保持既有尺寸（内容刷新时会重新测量）；首次构建用默认宽高。
        if size.width < 1 || size.height < 1 {
            size = NSSize(width: 400, height: 100)
        }

        var origin: NSPoint?
        if restoreSaved, let saved = DesktopLyricsFrameGuard.recoverableOrigin(
            raw: AppSettings.desktopLyricsFrame,
            size: size,
            screens: NSScreen.screens.map(\.frame)
        ) {
            origin = saved
        }
        let target = origin ?? defaultOrigin(for: size)

        isProgrammaticMove = true
        panel.setFrame(NSRect(origin: target, size: size), display: true)
        isProgrammaticMove = false
    }

    @objc private func screenParametersDidChange() {
        guard visibility.isVisible, let panel else { return }
        // 主屏幕变化后：记忆位置若与所有屏幕均无交集 → 回主屏幕默认位置
        // （round 59 c 起与启动恢复共用 DesktopLyricsFrameGuard 矩形相交判定）。
        let frame = panel.frame
        if !DesktopLyricsFrameGuard.isRecoverable(frame: frame, screens: NSScreen.screens.map(\.frame)) {
            positionPanel(restoreSaved: false)
        }
    }

    /// 窗口位置持久化："x,y" 字符串（缺省空串 = 未记忆，用默认位置）。
    static func encodeFrameOrigin(_ point: NSPoint) -> String {
        "\(point.x),\(point.y)"
    }

    static func decodeFrameOrigin(_ raw: String) -> NSPoint? {
        let parts = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2,
              let x = Double(parts[0]),
              let y = Double(parts[1]),
              x.isFinite, y.isFinite else {
            return nil
        }
        return NSPoint(x: x, y: y)
    }

    @objc private func windowDidMove(_ notification: Notification) {
        guard !isProgrammaticMove,
              visibility.isVisible,
              let panel = notification.object as? NSPanel, panel === self.panel else { return }
        // 用户拖动期间 didMove 多次触发，直接覆盖即可，最终值即用户停手位置。
        AppSettings.desktopLyricsFrame = Self.encodeFrameOrigin(panel.frame.origin)
    }

    @objc private func handleClick() {
        hide()
    }

    // MARK: - 数据流（订阅 LyricsEngine）

    private func setupSubscriptions() {
        guard cancellables.isEmpty else { return }

        engine.$currentLineIndex
            .combineLatest(engine.$currentLyrics)
            .combineLatest(engine.$translationLyrics)
            .combineLatest(engine.$romajiLyrics)
            .combineLatest(engine.$clickAction)
            .combineLatest(engine.$trackInfo)
            .map { value in
                (
                    lineIndex: value.0.0.0.0.0,
                    lyrics: value.0.0.0.0.1,
                    translationLyrics: value.0.0.0.1,
                    romajiLyrics: value.0.0.1,
                    clickAction: value.0.1,
                    track: value.1
                )
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.onLyricsUpdate(
                    lineIndex: state.lineIndex,
                    lyrics: state.lyrics,
                    translationLyrics: state.translationLyrics,
                    romajiLyrics: state.romajiLyrics,
                    clickAction: state.clickAction,
                    track: state.track
                )
            }
            .store(in: &cancellables)
    }

    private func onLyricsUpdate(
        lineIndex: Int?,
        lyrics: SimpleLyrics?,
        translationLyrics: SimpleLyrics?,
        romajiLyrics: SimpleLyrics?,
        clickAction: LyricsClickAction,
        track: EngineTrackInfo
    ) {
        guard visibility.isVisible else { return }

        let activeLyrics: SimpleLyrics?
        switch clickAction {
        case .original: activeLyrics = lyrics
        case .translation: activeLyrics = translationLyrics ?? lyrics
        case .romaji: activeLyrics = romajiLyrics ?? lyrics
        }

        let hasLyrics: Bool
        if let active = activeLyrics, let idx = lineIndex, idx >= 0, idx < active.lines.count {
            hasLyrics = true
        } else {
            hasLyrics = false
        }

        let placeholderText = DesktopLyricsLayout.placeholder(
            trackTitle: track.title,
            isPlaying: track.playbackState == .playing,
            hasLyrics: hasLyrics
        )

        if !placeholderText.isEmpty {
            showPlaceholder(placeholderText)
            lastAnimatedLineIndex = nil
            lastAnimatedLyricsId = nil
            lastPlaybackState = track.playbackState
            return
        }

        guard let active = activeLyrics, let idx = lineIndex, idx < active.lines.count else { return }
        let context = DesktopLyricsLayout.lineContext(lines: active.lines, currentIndex: idx)
        let line = active.lines[idx]

        // ── 行/模式变化 → 重建文本与卡拉 OK keyframes（每行仅一次）──
        let lyricsChanged = ObjectIdentifier(active) != lastAnimatedLyricsId
        let lineChanged = idx != lastAnimatedLineIndex
            || clickAction != lastAnimatedClickAction
            || lyricsChanged

        if lineChanged {
            prevLabel?.stringValue = context.prev ?? ""
            currentLabel?.stringValue = context.current ?? ""
            nextLabel?.stringValue = context.next ?? ""
            // round 52：行切换即归位滚动相位（新行从开头渲染，不继承旧行滚动偏移）。
            currentLabel?.bounds.origin.x = 0
            hidePlaceholder()

            prevLabel?.isHidden = context.prev == nil
            nextLabel?.isHidden = context.next == nil

            let progress = LyricsKaraokeMapper.progress(
                timetags: line.timetags,
                linePosition: line.position,
                timeDelay: active.adjustedTimeDelay,
                playbackTime: track.playbackTime
            )
            if !progress.isEmpty {
                let style: KaraokeStyle = config.karaokeStyle == .jump ? .jump : .progressive
                currentLabel?.setProgressAnimation(color: resolveDesktopProgressColor(), progress: progress, style: style)
            } else {
                currentLabel?.removeProgressAnimation()
            }

            lastAnimatedLineIndex = idx
            lastAnimatedClickAction = clickAction
            lastAnimatedLyricsId = ObjectIdentifier(active)
        }

        // ── 播放/暂停状态迁移 → 冻结/解冻扫描 ──
        let wasPlaying = lastPlaybackState == .playing
        let nowPlaying = track.playbackState == .playing
        if nowPlaying && !wasPlaying {
            currentLabel?.resumeProgressAnimation()
        } else if !nowPlaying && wasPlaying {
            currentLabel?.pauseProgressAnimation()
        }
        lastPlaybackState = track.playbackState

        relayout()
        updateMarquee(active: active, lineIndex: idx, track: track)
    }

    /// 无歌词/暂停时直接刷新占位（不重建动画）。
    private func showPlaceholder(_ text: String) {
        placeholderLabel?.stringValue = text
        placeholderLabel?.isHidden = false
        prevLabel?.isHidden = true
        currentLabel?.isHidden = true
        nextLabel?.isHidden = true
        currentLabel?.removeProgressAnimation()
        resetMarquee()
        relayout()
    }

    private func hidePlaceholder() {
        placeholderLabel?.isHidden = true
        prevLabel?.isHidden = false
        currentLabel?.isHidden = false
        nextLabel?.isHidden = false
    }

    /// 窗口刷新时按当前引擎状态重绘一次（show() 时保证不空窗）。
    private func refreshContent() {
        guard visibility.isVisible else { return }
        onLyricsUpdate(
            lineIndex: engine.currentLineIndex,
            lyrics: engine.currentLyrics,
            translationLyrics: engine.translationLyrics,
            romajiLyrics: engine.romajiLyrics,
            clickAction: engine.clickAction,
            track: engine.trackInfo
        )
    }

    // MARK: - 布局（手动测量，随内容自适应尺寸）

    /// 依可见标签测量宽度/高度并 setContentSize，同时保持窗口中心不动。
    private func relayout() {
        guard let panel, let content = panel.contentView, let bg = backgroundView else { return }

        let font = desktopFont()
        let lineHeight = ceil(font.ascender - font.descender + font.leading) + 2

        let visibleLabels: [NSTextField] = [
            prevLabel, currentLabel, nextLabel, placeholderLabel
        ].compactMap { $0 }.filter { !$0.isHidden }

        var maxTextWidth: CGFloat = 0
        for label in visibleLabels {
            let text = label.stringValue
            guard !text.isEmpty else { continue }
            let w = NSAttributedString(
                string: text,
                attributes: [.font: label.font ?? font]
            ).size().width
            maxTextWidth = max(maxTextWidth, w)
        }

        let screenWidth = NSScreen.main?.frame.width ?? 1280
        let maxWidth = min(screenWidth * Metrics.maxWidthRatio, Metrics.maxWidthCap)
        let width = min(max(maxTextWidth + Metrics.horizontalPadding * 2, Metrics.minWidth), maxWidth)
        let visibleLineCount = max(1, visibleLabels.filter { !($0 === placeholderLabel) && !$0.stringValue.isEmpty }.count)
        let height = CGFloat(visibleLineCount) * lineHeight
            + CGFloat(max(0, visibleLineCount - 1)) * Metrics.lineSpacing
            + Metrics.verticalPadding * 2

        let oldFrame = panel.frame
        let newFrame = NSRect(
            x: oldFrame.midX - width / 2,
            y: oldFrame.midY - height / 2,
            width: width,
            height: height
        )
        // 内容自适应 resize 属程序化移动：不覆盖用户拖拽记忆位置。
        isProgrammaticMove = true
        panel.setFrame(newFrame, display: true)
        isProgrammaticMove = false
        bg.frame = content.bounds

        layoutLabels(in: content.bounds, lineHeight: lineHeight)
    }

    private func layoutLabels(in bounds: NSRect, lineHeight: CGFloat) {
        let visibleLabels: [NSTextField] = [
            prevLabel, currentLabel, nextLabel, placeholderLabel
        ].compactMap { $0 }.filter { !$0.isHidden }

        var y = bounds.maxY - Metrics.verticalPadding - lineHeight
        for label in visibleLabels {
            let textWidth = min(
                NSAttributedString(
                    string: label.stringValue,
                    attributes: [.font: label.font ?? desktopFont()]
                ).size().width,
                bounds.width - Metrics.horizontalPadding * 2
            )
            label.frame = NSRect(
                x: bounds.midX - textWidth / 2,
                y: y,
                width: textWidth,
                height: lineHeight
            )
            y -= lineHeight + Metrics.lineSpacing
        }
    }

    // MARK: - 长行滚动（round 52）

    /// 行绘制后按当前行宽度决策滚动方式（relayout 后调用，面板尺寸已定）。
    /// 有 timetag 的卡拉 OK 行 → follow 跟随（正在演唱的字保持可视，无 timer）；
    /// 无 timetag 长行 → 循环 marquee（30fps timer 仅此场景运行）。
    private func updateMarquee(active: SimpleLyrics, lineIndex: Int, track: EngineTrackInfo) {
        guard AppSettings.desktopLyricsMarqueeEnabled,
              visibility.isVisible,
              let current = currentLabel,
              !current.isHidden,
              let panel else {
            resetMarquee()
            return
        }
        let clipWidth = panel.frame.width - Metrics.horizontalPadding * 2
        guard clipWidth > 0 else {
            resetMarquee()
            return
        }
        let textWidth = current.fullTextWidth
        guard DesktopLyricsMarquee.needsMarquee(textWidth: textWidth, availableWidth: clipWidth) else {
            resetMarquee()
            return
        }
        // r57-g 竞态复查：visibility 状态与真实窗口可见性可能短暂错位
        // （hide 已执行但引擎 tick 先到重建路径）。Timer 创建前以窗口实际
        // isVisible 为准——不可见只存参数不建表，恢复可见由 show() 补建。
        if let window = panel as NSPanel?, window.isVisible == false {
            marqueeOverflowWidth = DesktopLyricsMarquee.overflowWidth(
                textWidth: textWidth,
                availableWidth: clipWidth,
                padding: MarqueeMetrics.overflowPadding
            )
            marqueeTimeBudget = DesktopLyricsMarquee.nextLineTimeBudget(
                nextLinePosition: lineIndex + 1 < active.lines.count ? active.lines[lineIndex + 1].position : nil,
                playbackTime: track.playbackTime,
                defaultBudget: MarqueeMetrics.defaultTimeBudget,
                minBudget: MarqueeMetrics.minTimeBudget
            )
            marqueeStartTime = nil
            stopMarqueeTimer()
            return
        }
        let overflow = DesktopLyricsMarquee.overflowWidth(
            textWidth: textWidth,
            availableWidth: clipWidth,
            padding: MarqueeMetrics.overflowPadding
        )
        let line = active.lines[lineIndex]

        if !line.timetags.isEmpty {
            // 卡拉 OK 行：follow 跟随滚动——不建 timer，动画式移动，
            // 逐字高亮 clip 随 bounds.origin 同移，高亮与文本不脱位。
            stopMarqueeTimer()
            updateFollowScroll(timetags: line.timetags, line: line, active: active, track: track, overflowWidth: overflow)
            return
        }

        // 无 timetag 长行：循环 marquee（OPT-5 ② 同款守卫——同一行复用 timer，
        // 仅行切换时重建，防 0.25s tick 反复重启导致滚动回跳）。
        let timeBudget = DesktopLyricsMarquee.nextLineTimeBudget(
            nextLinePosition: lineIndex + 1 < active.lines.count ? active.lines[lineIndex + 1].position : nil,
            playbackTime: track.playbackTime,
            defaultBudget: MarqueeMetrics.defaultTimeBudget,
            minBudget: MarqueeMetrics.minTimeBudget
        )
        if marqueeTimer != nil, marqueeLineIndex == lineIndex, marqueeLyricsId == ObjectIdentifier(active) {
            marqueeOverflowWidth = overflow
            marqueeTimeBudget = timeBudget
            return
        }

        stopMarqueeTimer()
        marqueeLineIndex = lineIndex
        marqueeLyricsId = ObjectIdentifier(active)
        marqueeOverflowWidth = overflow
        marqueeTimeBudget = timeBudget
        marqueeStartTime = Date()
        let timer = Timer(timeInterval: 1.0 / MarqueeMetrics.fps, repeats: true) { [weak self] _ in
            guard let self, let startTime = self.marqueeStartTime else { return }
            let elapsed = Date().timeIntervalSince(startTime)
            let offset = DesktopLyricsMarquee.marqueeOffset(
                elapsed: elapsed,
                budget: self.marqueeTimeBudget,
                overflowWidth: self.marqueeOverflowWidth
            )
            if self.currentLabel?.bounds.origin.x != offset {
                self.currentLabel?.bounds.origin.x = offset
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        marqueeTimer = timer
    }

    /// follow 跟随滚动：目标偏移 = 让正在演唱的字符出现在可视区 65% 处
    /// （与 LyricsTouchBarItem.updateAutoScroll 同款公式，夹在 [0, overflowWidth]）。
    private func updateFollowScroll(
        timetags: [(TimeInterval, Int)],
        line: SimpleLyrics.Line,
        active: SimpleLyrics,
        track: EngineTrackInfo,
        overflowWidth: CGFloat
    ) {
        guard let current = currentLabel else { return }
        let progress = LyricsKaraokeMapper.progress(
            timetags: timetags,
            linePosition: line.position,
            timeDelay: active.adjustedTimeDelay,
            playbackTime: track.playbackTime
        )
        guard let nextIdx = progress.firstIndex(where: { $0.0 > 0 }), nextIdx < timetags.count else { return }
        let charX = current.charPosition(at: timetags[nextIdx].1)
        let desired = DesktopLyricsMarquee.followOffset(
            charX: charX,
            clipWidth: current.frame.width,
            ratio: MarqueeMetrics.followVisibleRatio,
            overflowWidth: overflowWidth
        )
        if abs(current.bounds.origin.x - desired) > 2 {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = MarqueeMetrics.animationDuration
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                current.animator().setBoundsOrigin(NSPoint(x: desired, y: 0))
            }
        }
    }

    /// 停止滚动并归位（隐藏/占位/行切换/无溢出/开关关闭共用）。
    private func resetMarquee() {
        stopMarqueeTimer()
        currentLabel?.bounds.origin.x = 0
    }

    private func stopMarqueeTimer() {
        marqueeTimer?.invalidate()
        marqueeTimer = nil
        marqueeStartTime = nil
        marqueeLineIndex = nil
        marqueeLyricsId = nil
    }
}
