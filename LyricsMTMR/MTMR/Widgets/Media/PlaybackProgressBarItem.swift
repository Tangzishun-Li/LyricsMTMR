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
    /// Track geometry from the last draw pass, reused by the scrub handlers.
    private var trackRect: CGRect = .zero

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

        // Native Now Playing layout: elapsed / -remaining labels pinned to
        // both edges, thin track stretched between them.
        var labelLeftWidth: CGFloat = 0
        var labelRightWidth: CGFloat = 0
        let showLabels = duration > 0
        if showLabels {
            let elapsed = clamped * duration
            let remaining = duration - elapsed
            let attrs: [NSAttributedString.Key: Any] = [
                .font: timeLabelFont,
                .foregroundColor: isScrubbing ? timeLabelActiveColor : timeLabelColor
            ]
            let elapsedStr = formatTime(elapsed) as NSString
            let es = elapsedStr.size(withAttributes: attrs)
            labelLeftWidth = es.width
            elapsedStr.draw(at: NSPoint(x: 0, y: bounds.midY - es.height / 2), withAttributes: attrs)
            let remainStr = "-\(formatTime(remaining))" as NSString
            let rs = remainStr.size(withAttributes: attrs)
            labelRightWidth = rs.width
            remainStr.draw(at: NSPoint(x: width - rs.width, y: bounds.midY - rs.height / 2), withAttributes: attrs)
        }

        let trackX = showLabels ? labelLeftWidth + 8 : 0
        let trackW = max(10, width - trackX - (showLabels ? labelRightWidth + 8 : 0))
        trackRect = CGRect(x: trackX, y: 0, width: trackW, height: bounds.height)
        let trackMidY = bounds.midY

        // Background track
        let trackY = trackMidY - trackHeight / 2
        let trackPath = CGPath(roundedRect: CGRect(x: trackX, y: trackY, width: trackW, height: trackHeight),
                               cornerWidth: trackHeight / 2, cornerHeight: trackHeight / 2, transform: nil)
        ctx.addPath(trackPath)
        ctx.setFillColor(trackColor.cgColor)
        ctx.fillPath()

        guard clamped > 0.003 else { return }

        // Filled portion (solid white, no gradient)
        let fillWidth = trackW * clamped
        let fillRect = CGRect(x: trackX, y: trackY, width: fillWidth, height: trackHeight)
        let fillPath = CGPath(roundedRect: fillRect, cornerWidth: trackHeight / 2, cornerHeight: trackHeight / 2, transform: nil)
        ctx.addPath(fillPath)
        ctx.setFillColor(fillColor.cgColor)
        ctx.fillPath()

        // Thumb
        let r = isScrubbing ? thumbRadiusActive : thumbRadius
        let thumbX = trackX + fillWidth

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -0.5), blur: 2, color: thumbShadowColor.cgColor)
        ctx.setFillColor(thumbColor.cgColor)
        ctx.fillEllipse(in: CGRect(x: thumbX - r, y: trackMidY - r, width: r * 2, height: r * 2))
        ctx.restoreGState()
    }

    // MARK: Mouse interaction (drag to seek)

    /// The Touch Bar treats the first touch like a "first mouse" event; without
    /// this override the initial tap is swallowed by window activation and the
    /// drag never starts.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

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
        let rect = trackRect.width > 0 ? trackRect : bounds
        let ratio = max(0, min(1, (loc.x - rect.minX) / rect.width))
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

class PlaybackProgressBarItem: NSCustomTouchBarItem, TBPollPausable {

    private let sliderView: NativeProgressSliderView
    private var cancellables = Set<AnyCancellable>()

    /// 0.5s 进度轮询（round 20：隐藏期间整体暂停——隐藏期刷新不可见；
    /// 恢复后立即补刷一次，进度条不会停留在陈旧位置）。
    private lazy var pausableTimer = TBPausableTimer(interval: 0.5, tolerance: 0.05,
                                                     immediateFireOnResume: true) { [weak self] in
        guard let self = self, !self.sliderView.isScrubbing else { return }
        let info = LyricsEngine.shared.trackInfo
        self.updateProgress(info: info)
    }

    init(identifier: NSTouchBarItem.Identifier, width: CGFloat = 0) {
        // 支持主题 JSON 里用 width 指定滑条宽度（原生 Now Playing 风格），
        // 未指定时用默认 220；下限 120 防止时间标签挤不下。
        let w = width > 0 ? max(120, width) : 220
        sliderView = NativeProgressSliderView(frame: NSRect(x: 0, y: 0, width: w, height: 30))
        super.init(identifier: identifier)

        sliderView.wantsLayer = true
        sliderView.layer?.backgroundColor = NSColor.clear.cgColor
        view = sliderView

        sliderView.onScrub = { time in
            LyricsEngine.shared.seek(to: time)
        }

        observePlayback()
    }

    required init?(coder: NSCoder) { return nil }

    /// 隐藏（黑名单/exitTouchbar）时暂停 0.5s 进度轮询；显示时恢复并立即补刷。
    func setPaused(_ paused: Bool) {
        pausableTimer.setPaused(paused)
    }

    private func observePlayback() {
        LyricsEngine.shared.$trackInfo
            .receive(on: DispatchQueue.main)
            .sink { [weak self] info in
                self?.updateProgress(info: info)
            }
            .store(in: &cancellables)

        pausableTimer.start()
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
