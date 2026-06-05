import Cocoa
import Combine

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
    private var marqueeTimeBudget: TimeInterval = 4.0

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

    private func setupSubscriptions() {
        engine.$trackInfo
            .receive(on: DispatchQueue.main)
            .sink { [weak self] info in
                self?.onTrackChanged(info)
            }
            .store(in: &cancellables)

        engine.$trackInfo
            .map(\.artwork)
            .removeDuplicates(by: { $0?.tiffRepresentation == $1?.tiffRepresentation })
            .receive(on: DispatchQueue.main)
            .sink { [weak self] artwork in
                self?.artworkView.image = artwork
            }
            .store(in: &cancellables)

        engine.$currentLineIndex
            .combineLatest(engine.$currentLyrics, engine.$translationLyrics, engine.$romajiLyrics, engine.$clickAction, engine.$trackInfo)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] idx, lyrics, tLyrics, rLyrics, action, info in
                self?.onLyricsUpdate(lineIndex: idx, lyrics: lyrics, translationLyrics: tLyrics, romajiLyrics: rLyrics, clickAction: action, track: info)
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

    private func onLyricsUpdate(lineIndex: Int?, lyrics: SimpleLyrics?, translationLyrics: SimpleLyrics?, romajiLyrics: SimpleLyrics?, clickAction: LyricsClickAction, track: EngineTrackInfo) {
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
            return
        }

        let line = active.lines[idx]
        lyricsLabel.stringValue = line.content
        hidePlaceholder()

        handleTextScroll(line: line, lineIndex: idx, active: active, track: track)

        if !line.timetags.isEmpty, track.playbackState == .playing {
            let position = track.playbackTime
            let timeDelay = active.adjustedTimeDelay
            let progress = line.timetags.map {
                ($0.0 + line.position - timeDelay - position, $0.1)
            }

            let style: KaraokeStyle = config.karaokeStyle == "jump" ? .jump : .progressive
            lyricsLabel.setProgressAnimation(color: config.progressColor, progress: progress, style: style)
        } else {
            lyricsLabel.removeProgressAnimation()
        }

        if track.playbackState == .playing {
            lyricsLabel.resumeProgressAnimation()
        } else {
            lyricsLabel.pauseProgressAnimation()
        }
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

        let overflowWidth = textWidth - clipWidth + 15

        if config.marqueeStyle == "follow" {
            if !line.timetags.isEmpty {
                stopMarqueeTimer()
                updateAutoScroll(timetags: line.timetags, line: line, active: active, track: track, overflowWidth: overflowWidth)
            } else {
                resetScrollPosition()
            }
            return
        }

        // marqueeStyle == "marquee"
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

        let targetVisibleX = clipWidth * 0.65
        let maxOffset: CGFloat = 0
        let minOffset = -overflowWidth
        let desiredOffset = max(minOffset, min(maxOffset, targetVisibleX - charX))

        if abs(lyricsLabel.bounds.origin.x - desiredOffset) > 2 {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
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
            nextPosition = track.playbackTime + 4.0
        }

        let timeBudget = max(nextPosition - track.playbackTime, 1.0)

        marqueeOverflowWidth = overflowWidth
        marqueeTimeBudget = timeBudget
        marqueeStartTime = Date()

        marqueeTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self, let startTime = self.marqueeStartTime else { return }
            let elapsed = Date().timeIntervalSince(startTime)
            let t = elapsed.truncatingRemainder(dividingBy: self.marqueeTimeBudget) / self.marqueeTimeBudget
            let offset = -t * self.marqueeOverflowWidth
            if self.lyricsLabel.bounds.origin.x != offset {
                self.lyricsLabel.bounds.origin.x