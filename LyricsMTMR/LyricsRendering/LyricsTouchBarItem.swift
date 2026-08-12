//
//  LyricsTouchBarItem.swift
//  LyricsMTMR
//
//  Adapted from LyricsX TouchBarLyricsItem
//  Original: https://github.com/MxIris-LyricsX-Project/LyricsX
//
//  A full-featured Touch Bar item that displays:
//  - Current song artwork (optional)
//  - Karaoke lyrics with progressive or jump animation
//  - Static "Title - Artist" mode
//  - Artwork-only mode
//  - Click to cycle: original → translation → romaji
//  - Marquee / follow scrolling for long lines
//
//  This source code is licensed under GPL 2.0.
//  See LICENSE file in the project root for full license information.
//

import Cocoa
import Combine

/// Timing constants for marquee scrolling animation.
private enum MarqueeMetrics {
    // OPT-5: 60fps → 30fps — 触摸条宽度有限，30fps 滚动肉眼无差，定时器开销减半
    static let fps: Double = 30.0
    static let defaultTimeBudget: TimeInterval = 4.0
    static let flashDuration: TimeInterval = 1.5
    static let overflowPadding: CGFloat = 15
    static let followVisibleRatio: CGFloat = 0.65
    static let animationDuration: TimeInterval = 0.2
}

/// Combined snapshot of engine state needed to render a lyrics line.
private struct LyricsRenderState {
    let lineIndex: Int?
    let lyrics: SimpleLyrics?
    let translationLyrics: SimpleLyrics?
    let romajiLyrics: SimpleLyrics?
    let clickAction: LyricsClickAction
    let track: EngineTrackInfo
}

class LyricsTouchBarItem: NSCustomTouchBarItem, TBPollPausable {
    private let stackView = NSStackView()
    private let artworkView = NSImageView()
    private let lyricsLabel = KaraokeLabel(labelWithString: "")
    private let placeholderLabel = NSTextField(labelWithString: "")

    /// round 24 收官审计：marquee 暂停门。60fps 滚动 timer 与 bar 显隐零
    /// 关联——播放继续时（Combine 事件驱动 0.25s tick）隐藏期仍全速滚动
    /// 用户看不到的歌词（纯 UI 空转，全库最高频 Timer 之一）；本卡纳入
    /// 暂停：隐藏期停 timer + 不调度 follow 动画，恢复后由下一次
    /// onLyricsUpdate（≤0.25s 播放 tick）自然重建滚动。
    /// round 23 播种：隐藏期重建时初始即暂停。
    private let marqueePauseGate = TBPauseGate(startPaused: TouchBarVisibilityState.shared.isBarHidden)

    /// round 24 测试缝：marquee timer 当前是否在跑（internal 只读）。
    var marqueeTimerActive: Bool { marqueeTimer != nil }

    private var config: LyricsItemConfig
    private var engine: LyricsEngine { LyricsEngine.shared }
    private var cancellables = Set<AnyCancellable>()

    private var marqueeTimer: Timer?
    private var marqueeStartTime: Date?
    private var marqueeOverflowWidth: CGFloat = 0
    private var marqueeTimeBudget: TimeInterval = MarqueeMetrics.defaultTimeBudget
    /// OPT-5 ②: marquee timer 当前服务的行/歌词对象 — 用于「同一行复用 timer，
    /// 仅行切换时重建」，避免 0.25s playback tick 反复重建导致滚动回跳。
    private var marqueeLineIndex: Int?
    private var marqueeLyricsId: ObjectIdentifier?

    /// Tracks which line/mode the karaoke animation was last built for,
    /// so we only rebuild the (expensive) karaoke keyframes once per
    /// line change instead of every 0.25 s playback tick.
    private var lastAnimatedLineIndex: Int?
    private var lastAnimatedClickAction: LyricsClickAction?
    private var lastAnimatedLyricsId: ObjectIdentifier?
    private var lastPlaybackState: PlaybackState?

    override init(identifier: NSTouchBarItem.Identifier) {
        self.config = LyricsItemConfig.shared
        super.init(identifier: identifier)
        setupViews()
        setupSubscriptions()
        setupGesture()
        updatePlaceholder()
    }

    deinit {
        stopMarqueeTimer()
    }

    func applyConfig(_ config: LyricsItemConfig) {
        self.config = config
        lyricsLabel.font = config.font
        lyricsLabel.textColor = config.textColor
        lyricsLabel.progressColor = config.progressColor
        updateArtworkVisibility()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Setup

    private func setupViews() {
        artworkView.wantsLayer = true
        artworkView.layer?.cornerRadius = 4
        artworkView.imageScaling = .scaleProportionallyUpOrDown

        lyricsLabel.font = config.font
        lyricsLabel.textColor = config.textColor
        lyricsLabel.progressColor = config.progressColor
        lyricsLabel.isVertical = false
        lyricsLabel.drawFurigana = false
        lyricsLabel.drawRomajin = false
        lyricsLabel.lineBreakMode = .byClipping
        lyricsLabel.refusesFirstResponder = true

        stackView.wantsLayer = true
        stackView.layer?.masksToBounds = true

        placeholderLabel.font = config.font
        placeholderLabel.textColor = config.textColor.withAlphaComponent(0.5)
        placeholderLabel.isBezeled = false
        placeholderLabel.drawsBackground = false
        placeholderLabel.lineBreakMode = .byTruncatingTail

        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.spacing = 6
        stackView.distribution = .fill

        if config.showArtwork {
            artworkView.widthAnchor.constraint(equalToConstant: config.artworkSize).isActive = true
            artworkView.heightAnchor.constraint(equalToConstant: config.artworkSize).isActive = true
            stackView.addArrangedSubview(artworkView)
        }

        stackView.addArrangedSubview(lyricsLabel)

        view = stackView
    }

    // MARK: - Subscriptions

    private func setupSubscriptions() {
        // Track info changes → update placeholder
        engine.$trackInfo
            .receive(on: DispatchQueue.main)
            .sink { [weak self] info in
                self?.onTrackChanged(info)
            }
            .store(in: &cancellables)

        // Artwork changes → update image (deduplicated via lightweight hash)
        engine.$trackInfo
            .removeDuplicates(by: { ($0.artwork?.contentHash ?? 0) == ($1.artwork?.contentHash ?? 0) })
            .map(\.artwork)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] artwork in
                self?.artworkView.image = artwork
            }
            .store(in: &cancellables)

        // Lyrics/line/track updates → render current line
        engine.$currentLineIndex
            .combineLatest(engine.$currentLyrics)
            .combineLatest(engine.$translationLyrics)
            .combineLatest(engine.$romajiLyrics)
            .combineLatest(engine.$clickAction)
            .combineLatest(engine.$trackInfo)
            .map { value in
                LyricsRenderState(
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

    private func setupGesture() {
        let tap = NSClickGestureRecognizer(target: self, action: #selector(handleTap))
        tap.allowedTouchTypes = .direct
        view.addGestureRecognizer(tap)
    }

    // MARK: - Track Update

    private func onTrackChanged(_ info: EngineTrackInfo) {
        if config.displayMode == .static, !info.title.isEmpty {
            placeholderLabel.stringValue = "\(info.title) — \(info.artist)"
            showPlaceholder()
        } else if info.title.isEmpty {
            updatePlaceholder()
        }
    }

    // MARK: - Lyrics Update

    private func onLyricsUpdate(
        lineIndex: Int?,
        lyrics: SimpleLyrics?,
        translationLyrics: SimpleLyrics?,
        romajiLyrics: SimpleLyrics?,
        clickAction: LyricsClickAction,
        track: EngineTrackInfo
    ) {
        guard config.isKaraoke else { return }

        let activeLyrics: SimpleLyrics?
        switch clickAction {
        case .original: activeLyrics = lyrics
        case .translation: activeLyrics = translationLyrics ?? lyrics
        case .romaji: activeLyrics = romajiLyrics ?? lyrics
        }

        guard let active = activeLyrics,
              let idx = lineIndex,
              idx < active.lines.count else {
            showPlaceholder()
            stopMarqueeTimer()
            lastAnimatedLineIndex = nil
            lastAnimatedClickAction = nil
            lastAnimatedLyricsId = nil
            return
        }

        let line = active.lines[idx]

        // ── Detect whether the visible line or mode actually changed ──
        let lyricsChanged = ObjectIdentifier(active) != lastAnimatedLyricsId
        let lineChanged = idx != lastAnimatedLineIndex
            || clickAction != lastAnimatedClickAction
            || lyricsChanged

        if lineChanged {
            lyricsLabel.stringValue = line.content
            hidePlaceholder()
            lastAnimatedLineIndex = idx
            lastAnimatedClickAction = clickAction
            lastAnimatedLyricsId = ObjectIdentifier(active)

            // Build the karaoke keyframes ONCE per line; KaraokeLabel
            // advances the sweep itself in draw() at 30 fps.
            AppLog.lyrics("onLyricsUpdate: lineChanged idx=\(idx) content=「\(line.content.prefix(30))」words=\(line.words.count) timetags=\(line.timetags.count)")
            if !line.timetags.isEmpty {
                let position = track.playbackTime
                let timeDelay = active.adjustedTimeDelay
                let progress = line.timetags.map {
                    ($0.0 + line.position - timeDelay - position, $0.1)
                }
                AppLog.lyrics("onLyricsUpdate: setting progressAnimation with \(progress.count) points, playbackTime=\(position), linePos=\(line.position)")
                let style: KaraokeStyle = config.karaokeStyle == .jump ? .jump : .progressive
                lyricsLabel.setProgressAnimation(color: config.progressColor, progress: progress, style: style)
            } else {
                AppLog.lyrics("onLyricsUpdate: NO timetags — removing animation")
                lyricsLabel.removeProgressAnimation()
            }
        }

        // ── Lightweight per-tick updates (scroll + pause/resume) ──
        handleTextScroll(line: line, lineIndex: idx, active: active, track: track, lineChanged: lineChanged)

        // Only pause/resume on STATE TRANSITIONS. Calling resume every
        // 0.25 s tick would reset the sweep anchor and the progress
        // would never advance past the first fraction of a second.
        let wasPlaying = lastPlaybackState == .playing
        let nowPlaying = track.playbackState == .playing

        if lineChanged {
            // Animation was just (re)created — it starts running by default.
            // Only act if the player is paused.
            if !nowPlaying {
                lyricsLabel.pauseProgressAnimation()
                // OPT-5 ①: 暂停即停 — 暂停时也停掉 marquee timer，
                // 否则 30/60fps 定时器继续空转（暂停时空转缺陷）。
                stopMarqueeTimer()
            }
        } else if nowPlaying && !wasPlaying {
            // Resumed from pause → unpick the freeze.
            lyricsLabel.resumeProgressAnimation()
        } else if !nowPlaying && wasPlaying {
            // Paused → freeze the animation in place.
            lyricsLabel.pauseProgressAnimation()
            // OPT-5 ①: 暂停即停（同上）。
            stopMarqueeTimer()
        }
        lastPlaybackState = track.playbackState
    }

    // MARK: - Text Scrolling

    /// round 24：隐藏暂停。bar 隐藏期间停止滚动全链——60fps marquee timer
    /// 不建、follow 动画不调度（暂停时 setPaused(true) 已停 timer；此处
    /// guard 拦截隐藏期 onLyricsUpdate 的重建）。恢复时无操作：下一次
    /// onLyricsUpdate（≤0.25s）自然重建滚动（OPT-16 守卫在 marqueeTimer
    /// 为 nil 时同样满足重建条件），相位从头开始（循环滚动无实质差异）。
    func setPaused(_ paused: Bool) {
        guard marqueePauseGate.setPaused(paused) else { return }
        if paused {
            stopMarqueeTimer()
        }
    }

    private func handleTextScroll(line: SimpleLyrics.Line, lineIndex: Int, active: SimpleLyrics, track: EngineTrackInfo, lineChanged: Bool) {
        guard config.marqueeEnabled else { return }
        // round 24：隐藏期间零滚动——60fps timer 不启动、follow 动画不调度；
        // 恢复后由下一次 tick 自然重建（见 setPaused 注释）。
        guard !marqueePauseGate.isPaused else { return }

        let clipWidth = stackView.bounds.width
        guard clipWidth > 0 else { return }

        let textWidth = lyricsLabel.fullTextWidth
        guard textWidth > clipWidth else {
            resetScrollPosition()
            return
        }

        let overflowWidth = textWidth - clipWidth + MarqueeMetrics.overflowPadding

        if config.marqueeStyle == .follow {
            if !line.timetags.isEmpty {
                stopMarqueeTimer()
                updateAutoScroll(timetags: line.timetags, line: line, active: active, track: track, overflowWidth: overflowWidth)
            } else {
                resetScrollPosition()
            }
            return
        }

        // marqueeStyle == .marquee
        if !line.timetags.isEmpty {
            stopMarqueeTimer()
            updateAutoScroll(timetags: line.timetags, line: line, active: active, track: track, overflowWidth: overflowWidth)
        } else {
            lyricsLabel.removeProgressAnimation()
            // OPT-16: marquee 只在线切换（或 timer 缺失/宽度变化需重建）时启动/重建，
            // 移出 0.25s playback Combine 链 — 常规 tick 不再走 startMarquee。
            // startMarquee 内部另有 OPT-5 ② 的同行复用守卫，双保险。
            if lineChanged || marqueeTimer == nil || abs(marqueeOverflowWidth - overflowWidth) > 1 {
                startMarquee(overflowWidth: overflowWidth, lineIndex: lineIndex, active: active, track: track)
            }
        }
    }

    private func updateAutoScroll(timetags: [(TimeInterval, Int)], line: SimpleLyrics.Line, active: SimpleLyrics, track: EngineTrackInfo, overflowWidth: CGFloat) {
        let position = track.playbackTime
        let timeDelay = active.adjustedTimeDelay

        let currentProgress = timetags.map { ($0.0 + line.position - timeDelay - position, $0.1) }

        guard let nextIdx = currentProgress.firstIndex(where: { $0.0 > 0 }),
              nextIdx < timetags.count else {
            return
        }

        let activeCharIndex = timetags[nextIdx].1
        let charX = lyricsLabel.charPosition(at: activeCharIndex)
        let clipWidth = stackView.bounds.width

        let targetVisibleX = clipWidth * MarqueeMetrics.followVisibleRatio
        // bounds.origin.x is the content coordinate shown at the view's LEFT
        // edge (screenX = contentX - origin.x), so revealing content further
        // right requires a POSITIVE origin.
        let desiredOffset = max(0, min(overflowWidth, charX - targetVisibleX))

        if abs(lyricsLabel.bounds.origin.x - desiredOffset) > 2 {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = MarqueeMetrics.animationDuration
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                lyricsLabel.animator().setBoundsOrigin(NSPoint(x: desiredOffset, y: 0))
            }
        }
    }

    /// round 24 双保险：暂停期直接调用也零启动（handleTextScroll 入口 guard
    /// 之外的第二道防线；同时作为单测注入点——internal 同 round 21
    /// startCapture/stopCapture 惯例）。
    func startMarquee(overflowWidth: CGFloat, lineIndex: Int, active: SimpleLyrics, track: EngineTrackInfo) {
        guard !marqueePauseGate.isPaused else { return }
        let nextPosition: TimeInterval
        if lineIndex + 1 < active.lines.count {
            nextPosition = active.lines[lineIndex + 1].position
        } else {
            nextPosition = track.playbackTime + MarqueeMetrics.defaultTimeBudget
        }

        let timeBudget = max(nextPosition - track.playbackTime, 1.0)

        // OPT-5 ②: timer 已存在且仍服务同一行 → 复用，不重建。
        // 0.25s playback tick 曾反复 stop+rebuild + 重置 marqueeStartTime，
        // 导致滚动每 0.25s 跳回起点；仅行切换时才重建 timer。
        // 复用时仅刷新宽度/预算（触摸条尺寸变化场景），滚动相位不重置。
        if marqueeTimer != nil, marqueeLineIndex == lineIndex, marqueeLyricsId == ObjectIdentifier(active) {
            marqueeOverflowWidth = overflowWidth
            marqueeTimeBudget = timeBudget
            return
        }

        stopMarqueeTimer()
        marqueeLineIndex = lineIndex
        marqueeLyricsId = ObjectIdentifier(active)

        marqueeOverflowWidth = overflowWidth
        marqueeTimeBudget = timeBudget
        marqueeStartTime = Date()

        marqueeTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / MarqueeMetrics.fps, repeats: true) { [weak self] _ in
            guard let self, let startTime = self.marqueeStartTime else { return }
            let elapsed = Date().timeIntervalSince(startTime)
            let t = elapsed.truncatingRemainder(dividingBy: self.marqueeTimeBudget) / self.marqueeTimeBudget
            // Positive origin scrolls the text leftward (see updateAutoScroll).
            let offset = t * self.marqueeOverflowWidth
            if self.lyricsLabel.bounds.origin.x != offset {
                self.lyricsLabel.bounds.origin.x = offset
            }
        }
    }

    private func resetScrollPosition() {
        stopMarqueeTimer()
        lyricsLabel.bounds.origin.x = 0
    }

    private func stopMarqueeTimer() {
        marqueeTimer?.invalidate()
        marqueeTimer = nil
        marqueeStartTime = nil
        marqueeLineIndex = nil
        marqueeLyricsId = nil
    }

    // MARK: - Placeholder

    private func updatePlaceholder() {
        if !engine.trackInfo.title.isEmpty {
            placeholderLabel.stringValue = "♫ Loading lyrics..."
        } else {
            placeholderLabel.stringValue = "♫ No music playing..."
        }
        showPlaceholder()
    }

    private func showPlaceholder() {
        guard config.displayMode != .artwork else { return }
        lyricsLabel.isHidden = true
        placeholderLabel.stringValue = "♫ No music..."
        if placeholderLabel.superview == nil {
            stackView.addArrangedSubview(placeholderLabel)
        }
    }

    private func hidePlaceholder() {
        placeholderLabel.removeFromSuperview()
        lyricsLabel.isHidden = false
    }

    // MARK: - Tap Handling

    @objc private func handleTap() {
        let modes: [LyricsClickAction] = [.original, .translation, .romaji]
        guard let currentIdx = modes.firstIndex(of: engine.clickAction) else { return }
        let nextIdx = (currentIdx + 1) % modes.count
        let nextAction = modes[nextIdx]

        engine.clickAction = nextAction

        if let line = engine.currentLyrics?.lines[engine.currentLineIndex ?? 0] {
            lyricsLabel.stringValue = line.content
        }

        let label = nextAction == .original ? "原文" : nextAction == .translation ? "翻译" : "音译"
        showFlash(label)
    }

    private func showFlash(_ text: String) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(clearFlash), object: nil)
        perform(#selector(clearFlash), with: nil, afterDelay: MarqueeMetrics.flashDuration)
    }

    @objc private func clearFlash() {
    }

    private func updateArtworkVisibility() {
        artworkView.isHidden = !config.showArtwork
    }
}
