//
//  PlaybackProgressBarItem.swift
//  LyricsMTMR
//
//  A slim, elegant playback progress bar for the Touch Bar.
//  Subscribes to LyricsEngine.shared.trackInfo and renders a
//  gradient-filled progress track with a glowing playhead dot.
//

import Cocoa
import Combine

// MARK: - Progress Bar View

private class ProgressTrackView: NSView {
    var progress: CGFloat = 0 {
        didSet { needsDisplay = true }
    }

    var trackColor: NSColor = NSColor(white: 1, alpha: 0.12)
    var fillColor: NSColor = NSColor(srgbRed: 1.00, green: 0.56, blue: 0.34, alpha: 1.0)
    var glowColor: NSColor = NSColor(srgbRed: 1.00, green: 0.72, blue: 0.42, alpha: 0.9)

    private let trackHeight: CGFloat = 4
    private let dotRadius: CGFloat = 4

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let width = bounds.width
        let midY = bounds.midY
        let trackY = midY - trackHeight / 2
        let clampedProgress = max(0, min(1, progress))

        // Background track
        let trackRect = CGRect(x: 0, y: trackY, width: width, height: trackHeight)
        let trackPath = CGPath(roundedRect: trackRect, cornerWidth: trackHeight / 2, cornerHeight: trackHeight / 2, transform: nil)
        ctx.addPath(trackPath)
        ctx.setFillColor(trackColor.cgColor)
        ctx.fillPath()

        guard clampedProgress > 0.005 else { return }

        // Filled portion with gradient
        let fillWidth = width * clampedProgress
        let fillRect = CGRect(x: 0, y: trackY, width: fillWidth, height: trackHeight)
        let fillPath = CGPath(roundedRect: fillRect, cornerWidth: trackHeight / 2, cornerHeight: trackHeight / 2, transform: nil)

        ctx.saveGState()
        ctx.addPath(fillPath)
        ctx.clip()

        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                fillColor.withAlphaComponent(0.7).cgColor,
                fillColor.cgColor
            ] as CFArray,
            locations: [0, 1]
        )!
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: midY), end: CGPoint(x: fillWidth, y: midY), options: [])
        ctx.restoreGState()

        // Playhead dot with glow
        let dotX = fillWidth

        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 6, color: glowColor.cgColor)
        ctx.setFillColor(glowColor.cgColor)
        ctx.fillEllipse(in: CGRect(x: dotX - dotRadius, y: midY - dotRadius, width: dotRadius * 2, height: dotRadius * 2))
        ctx.restoreGState()

        // Inner white core
        let coreRadius = dotRadius * 0.5
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fillEllipse(in: CGRect(x: dotX - coreRadius, y: midY - coreRadius, width: coreRadius * 2, height: coreRadius * 2))
    }
}

// MARK: - PlaybackProgressBarItem

class PlaybackProgressBarItem: NSCustomTouchBarItem {

    private let progressView = ProgressTrackView(frame: NSRect(x: 0, y: 0, width: 200, height: 30))
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?

    override init(identifier: NSTouchBarItem.Identifier) {
        super.init(identifier: identifier)
        progressView.wantsLayer = true
        progressView.layer?.backgroundColor = NSColor.clear.cgColor
        view = progressView

        observePlayback()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        timer?.invalidate()
    }

    private func observePlayback() {
        LyricsEngine.shared.$trackInfo
            .receive(on: DispatchQueue.main)
            .sink { [weak self] info in
                self?.updateProgress(info: info)
            }
            .store(in: &cancellables)

        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let info = LyricsEngine.shared.trackInfo
            self.updateProgress(info: info)
        }
    }

    private func updateProgress(info: EngineTrackInfo) {
        guard info.duration > 0 else {
            progressView.progress = 0
            return
        }
        let ratio = info.playbackTime / info.duration
        progressView.progress = CGFloat(max(0, min(1, ratio)))
    }
}
