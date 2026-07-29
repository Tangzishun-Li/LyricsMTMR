//
//  PlaybackProgressBarItem.swift
//  LyricsMTMR
//
//  Native-style Touch Bar playback progress slider.
//  Mimics the Apple Now Playing scrubber: thin monochrome track,
//  white fill, small round thumb, time labels on drag.
//

import Cocoa
import Combine

// MARK: - Native-style Progress Slider View

private class NativeProgressSliderView: NSView {

    // MARK: Public state

    var progress: CGFloat = 0 {
        didSet { if !isScrubbing { needsDisplay = true } }
    }

    var duration: TimeInterval = 0
    var onScrub: ((TimeInterval) -> Void)?

    private(set) var isScrubbing = false
    private var scrubProgress: CGFloat = 0

    // MARK: Layout constants (matching native Touch Bar Now Playing)

    private let trackHeight: CGFloat = 3
    private let thumbRadius: CGFloat = 4
    private let thumbRadiusActive: CGFloat = 5.5
    private let timeLabelHeight: CGFloat = 11
    private let timeLabelFont = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium)

    // MARK: Colors (monochrome, Apple-native feel)

    private let trackColor = NSColor(white: 1.0, alpha: 0.18)
    private let fillColor = NSColor(white: 1.0, alpha: 0.85)
    private let thumbColor = NSColor.white
    private let thumbShadowColor = NSColor(white: 0, alpha: 0.4)
    private let timeLabelColor = NSColor(white: 1.0, alpha: 0.55)
    private let timeLabelActiveColor = NSColor(white: 1.0, alpha: 0.9)

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let width = bounds.width
        let activeProgress = isScrubbing ? scrubProgress : progress
        let clamped = max(0, min(1, activeProgress))

        // Vertical layout: time labels at top, track centered below
        let showLabels = isScrubbing
        let trackAreaTop: CGFloat = showLabels ? timeLabelHeight + 2 : 0
        let trackMidY = trackAreaTop + (bounds.height - trackAreaTop) / 2

        // Time labels (visible while scrubbing)
        if showLabels, duration > 0 {
            let elapsed = clamped * duration
            let remaining = duration - elapsed

            let attrs: [NSAttributedString.Key: Any] = [
                .font: timeLabelFont,
                .foregroundColor: timeLabelActiveColor
            ]

            let elapsedStr = formatTime(elapsed) as NSString
            elapsedStr.draw(at: NSPoint(x: 0, y: 0), withAttributes: attrs)

            let remainStr = "-\(formatTime(remaining))" as NSString
            let remainSize = remainStr.size(withAttributes: attrs)
            remainStr.draw(at: NSPoint(x: width - remainSize.width, y: 0), withAttributes: attrs)
        }

        // Background track
        let trackY = trackMidY - trackHeight / 2
        let trackRect = CGRect(x: 0, y: trackY, width: width, height: trackHeight)
        let trackPath = CGPath(roundedRect: trackRect, cornerWidth: trackHeight / 2, cornerHeight: trackHeight / 2, transform: nil)
        ctx.addPath(trackPath)
        ctx.setFillColor(trackColor.cgColor)
        ctx.fillPath()

        guard clamped > 0.003 else { return }

        // Filled portion (solid white, no gradient)
        let fillWidth = width * clamped
        let fillRect = CGRect(x: 0, y: trackY, width: fillWidth, height: trackHeight)
        let fillPath = CGPath(roundedRect: fillRect, cornerWidth: trackHeight / 2, cornerHeight: trackHeight / 2, transform: nil)
        ctx.addPath(fillPath)
        ctx.setFillColor(fillColor.cgColor)
        ctx.fillPath()

        // Thumb
        let r = isScrubbing ? thumbRadiusActive : thumbRadius
        let thumbX = fillWidth

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -0.5), blur: 2, color: thumbShadowColor.cgColor)
        ctx.setFillColor(thumbColor.cgColor)
        ctx.fillEllipse(in: CGRect(x: thumbX - r, y: trackMidY - r, width: r * 2, height: r * 2))
        ctx.restoreGState()
    }

    // MARK: Mouse interaction (drag to seek)

    override func mouseDown(with event: NSEvent) {
        beginScrub(at: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard isScrubbing else { return }
        updateScrub(at: event)
    }

    override func mouseUp(with event: NSEvent) {
        guard isScrubbing else { return }
        updateScrub(at: event)
        endScrub()
    }

    private func beginScrub(at event: NSEvent) {
        isScrubbing = true
        updateScrub(at: event)
    }

    private func updateScrub(at event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        let ratio = max(0, min(1, loc.x / bounds.width))
        scrubProgress = ratio
        needsDisplay = true

        if duration > 0 {
            onScrub?(TimeInterval(ratio) * duration)
        }
    }

    private func endScrub() {
        isScrubbing = false
        needsDisplay = true
    }

    // MARK: Helpers

    private func formatTime(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - PlaybackProgressBarItem

class PlaybackProgressBarItem: NSCustomTouchBarItem {

    private let sliderView = NativeProgressSliderView(frame: NSRect(x: 0, y: 0, width: 220, height: 30))
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?

    override init(identifier: NSTouchBarItem.Identifier) {
        super.init(identifier: identifier)

        sliderView.wantsLayer = true
        sliderView.layer?.backgroundColor = NSColor.clear.cgColor
        view = sliderView

        sliderView.onScrub = { [weak self] time in
            LyricsEngine.shared.seek(to: time)
        }

        observePlayback()
    }

    required init?(coder: NSCoder) { return nil }

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
            guard let self = self, !self.sliderView.isScrubbing else { return }
            let info = LyricsEngine.shared.trackInfo
            self.updateProgress(info: info)
        }
    }

    private func updateProgress(info: EngineTrackInfo) {
        sliderView.duration = info.duration
        guard info.duration > 0 else {
            sliderView.progress = 0
            return
        }
        let ratio = info.playbackTime / info.duration
        sliderView.progress = CGFloat(max(0, min(1, ratio)))
    }
}
