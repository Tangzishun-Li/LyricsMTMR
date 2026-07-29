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
    static let fps: Double = 60.0
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

class LyricsTouchBarItem: NSCustomTouchBarItem {
    private let stackView = NSStackView()
    private let artworkView = NSImageView()
    private let lyricsLabel = KaraokeLabel(labelWithString: "")
    private let placeholderLabel = NSTextField(labelWithString: "")

    private var config: LyricsItemConfig
    private var engine: LyricsEngine { LyricsEngine.shared }
    private var cancellables = Set<AnyCancellable>()

    private var marqueeTimer: Timer?
    private var marqueeStartTime: Date?
    private var marqueeOverflowWidth: CGFloat = 0
    private var marqueeTimeBudget: TimeInterval = MarqueeMetrics.defaultTimeBudget

    /// Tracks which line/mode the karaoke animation was last built for,
    /// so we only create the (expensive) CAKeyframeAnimation once per
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

            // Build the karaoke CAKeyframeAnimation ONCE per line.
            // The animation runs on the render server and advances
            // autonomously — no per-tick teardown/recreate needed.
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
        handleTextScroll(line: line, lineIndex: idx, active: active, track: track)

        // Only pause/resume on STATE TRANSITIONS. Calling resume every
        // 0.25 s tick resets the CAKeyframeAnimation beginTime and the
        // progress bar never advances past the first fraction of a second.
        let wasPlaying = lastPlaybackState == .playing
        let nowPlaying = track.playbackState == .playing

        if lineChanged {
            // Animation was just (re)created — it starts running by default.
            // Only act if the player is paused.
            if !nowPlaying {
                lyricsLabel.pauseProgressAnimation()
            }
        } else if nowPlaying && !wasPlaying {
            // Resumed from pause → unpick the freeze.
            lyricsLabel.resumeProgressAnimation()
        } else if !nowPlaying && wasPlaying {
            // Paused → freeze the animation in place.
            lyricsLabel.pauseProgressAnimation()
        }
        lastPlaybackState = track.playbackState
    }

    // MARK: - Text Scrolling

    private func handleTextScroll(line: SimpleLyrics.Line, lineIndex: Int, active: SimpleLyrics, track: EngineTrackInfo) {
        guard config.marqueeEnabled else { return }

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
            startMarquee(overflowWidth: overflowWidth, lineIndex: lineIndex, active: active, track: track)
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
        let maxOffset: CGFloat = 0
        let minOffset = -overflowWidth
        let desiredOffset = max(minOffset, min(maxOffset, targetVisibleX - charX))

        if abs(lyricsLabel.bounds.origin.x - desiredOffset) > 2 {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = MarqueeMetrics.animationDuration
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                lyricsLabel.animator().setBoundsOrigin(NSPoint(x: desiredOffset, y: 0))
            }
        }
    }

    private func startMarquee(overflowWidth: CGFloat, lineIndex: Int, active: SimpleLyrics, track: EngineTrackInfo) {
        stopMarqueeTimer()

        let nextPosition: TimeInterval
        if lineIndex + 1 < active.lines.count {
            nextPosition = active.lines[lineIndex + 1].position
        } else {
            nextPosition = track.playbackTime + MarqueeMetrics.defaultTimeBudget
        }

        let timeBudget = max(nextPosition - track.playbackTime, 1.0)

        marqueeOverflowWidth = overflowWidth
        marqueeTimeBudget = timeBudget
        marqueeStartTime = Date()

        marqueeTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / MarqueeMetrics.fps, repeats: true) { [weak self] _ in
            guard let self, let startTime = self.marqueeStartTime else { return }
            let elapsed = Date().timeIntervalSince(startTime)
            let t = elapsed.truncatingRemainder(dividingBy: self.marqueeTimeBudget) / self.marqueeTimeBudget
            let offset = -t * self.marqueeOverflowWidth
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
