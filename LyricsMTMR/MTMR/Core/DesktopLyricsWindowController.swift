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
        setupSubscriptions()
        refreshContent()
    }

    func hide() {
        let wasVisible = visibility.isVisible
        visibility.hide()
        guard wasVisible else { return }
        currentLabel?.pauseProgressAnimation()
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
        let textColor = config.textColor
        currentLabel?.font = font
        currentLabel?.textColor = textColor
        currentLabel?.progressColor = config.progressColor
        prevLabel?.font = font
        prevLabel?.textColor = textColor.withAlphaComponent(Metrics.contextAlpha)
        nextLabel?.font = font
        nextLabel?.textColor = textColor.withAlphaComponent(Metrics.contextAlpha)
        placeholderLabel?.font = font
        placeholderLabel?.textColor = textColor.withAlphaComponent(Metrics.placeholderAlpha)
    }

    /// 桌面歌词窗口字号独立于 Touch Bar（com.lyricsmtmr.desktopLyrics.fontSize），
    /// 字体族/颜色复用 LyricsItemConfig（与 Touch Bar 歌词同源）。
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
        if restoreSaved, let saved = Self.savedFrameOrigin(), savedIsOnAnyScreen(saved) {
            origin = saved
        }
        let target = origin ?? defaultOrigin(for: size)

        isProgrammaticMove = true
        panel.setFrame(NSRect(origin: target, size: size), display: true)
        isProgrammaticMove = false
    }

    private func savedIsOnAnyScreen(_ point: NSPoint) -> Bool {
        NSScreen.screens.contains { $0.frame.contains(point) }
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

    private static func savedFrameOrigin() -> NSPoint? {
        decodeFrameOrigin(AppSettings.desktopLyricsFrame)
    }

    @objc private func windowDidMove(_ notification: Notification) {
        guard !isProgrammaticMove,
              visibility.isVisible,
              let panel = notification.object as? NSPanel, panel === self.panel else { return }
        // 用户拖动期间 didMove 多次触发，直接覆盖即可，最终值即用户停手位置。
        AppSettings.desktopLyricsFrame = Self.encodeFrameOrigin(panel.frame.origin)
    }

    @objc private func screenParametersDidChange() {
        guard visibility.isVisible, let panel else { return }
        // 主屏幕变化后：记忆位置若已不在任何屏幕内 → 回到主屏幕默认位置。
        let origin = panel.frame.origin
        if !savedIsOnAnyScreen(origin) {
            positionPanel(restoreSaved: false)
        }
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
                currentLabel?.setProgressAnimation(color: config.progressColor, progress: progress, style: style)
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
    }

    /// 无歌词/暂停时直接刷新占位（不重建动画）。
    private func showPlaceholder(_ text: String) {
        placeholderLabel?.stringValue = text
        placeholderLabel?.isHidden = false
        prevLabel?.isHidden = true
        currentLabel?.isHidden = true
        nextLabel?.isHidden = true
        currentLabel?.removeProgressAnimation()
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
}
