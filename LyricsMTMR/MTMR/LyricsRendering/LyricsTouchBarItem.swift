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
//
//  This source code is licensed under GPL 2.0.
//  See LICENSE file in the project root for full license information.
//
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

    override init(identifier: NSTouchBarItem.Identifier) {
        self.config = LyricsItemConfig.shared
        super.init(identifier: identifier)
        setupViews()
        setupSubscriptions()
        setupGesture()
        updatePlaceholder()
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
        lyricsLabel.lineBreakMode = .byTruncatingTail
        lyricsLabel.refusesFirstResponder = true

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
            return
        }

        let line = active.lines[idx]
        lyricsLabel.stringValue = line.content
        hidePlaceholder()

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

    // MARK: - Placeholder

    private func updatePlaceholder() {
        showPlaceholder()
    }

    private func showPlaceholder() {
        guard config.displayMode != .artwork else { return }
        lyricsLabel.isHidden = true

        let info = engine.trackInfo
        let hasLyrics = engine.currentLyrics != nil

        if hasLyrics {
            if !info.title.isEmpty {
                placeholderLabel.stringValue = info.artist.isEmpty
                    ? info.title
                    : "\(info.title) — \(info.artist)"
            } else {
                placeholderLabel.stringValue = "♫ Loading lyrics..."
            }
        } else if !info.title.isEmpty {
            placeholderLabel.stringValue = "♫ Loading lyrics..."
        } else {
            placeholderLabel.stringValue = "♫ No music playing..."
        }

        if placeholderLabel.superview == nil {
            stackView.addArrangedSubview(placeholderLabel)
        }
    }

    private func hidePlaceholder() {
        placeholderLabel.removeFromSuperview()
        lyricsLabel.isHidden = false
    }

    private func hideLyrics() {
        lyricsLabel.isHidden = true
        lyricsLabel.removeProgressAnimation()
    }

    // MARK: - Tap Handling

    @objc private func handleTap() {
        let modes: [LyricsClickAction] = [.original, .translation, .romaji]
        let hasTranslation = engine.translationLyrics != nil
        let hasRomaji = engine.romajiLyrics != nil
        let availableModes = modes.filter {
            switch $0 {
            case .original: return true
            case .translation: return hasTranslation
            case .romaji: return hasRomaji
            }
        }
        guard !availableModes.isEmpty else { return }

        let currentIdx = availableModes.firstIndex(of: engine.clickAction) ?? 0
        let nextIdx = (currentIdx + 1) % availableModes.count
        let nextAction = availableModes[nextIdx]
        engine.setClickAction(nextAction)

        let label = nextAction == .original ? "原文" : nextAction == .translation ? "翻译" : "音译"
        showFlash(label)
    }

    private func showFlash(_ text: String) {
        lyricsLabel.stringValue = "[ \(text) ]"
        lyricsLabel.removeProgressAnimation()
        let savedIdx = engine.currentLineIndex
        let savedAction = engine.clickAction
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self else { return }
            self.onLyricsUpdate(
                lineIndex: savedIdx,
                lyrics: self.engine.currentLyrics,
                translationLyrics: self.engine.translationLyrics,
                romajiLyrics: self.engine.romajiLyrics,
                clickAction: savedAction,
                track: self.engine.trackInfo
            )
        }
    }

    private func updateArtworkVisibility() {
        artworkView.isHidden = !config.showArtwork
    }
}
