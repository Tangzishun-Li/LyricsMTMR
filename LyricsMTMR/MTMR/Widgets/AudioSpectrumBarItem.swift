//
//  AudioSpectrumBarItem.swift
//  LyricsMTMR
//
//  Real-time audio spectrum visualizer for the Touch Bar.
//
//  Sources (JSON `source` overrides; otherwise Settings → 工具 → 音量律动):
//    system — captures the actual playback audio of the whole system via
//             ScreenCaptureKit (macOS 13+, needs the Screen Recording
//             permission; without it the widget asks for the permission
//             instead of silently switching sources)
//    mic    — ambient capture through AVAudioEngine
//    auto   — try system first; when it is unavailable the bass-weighted
//             synth keeps dancing while LyricsEngine reports playback.
//             The mic is deliberately skipped: it only hears the room,
//             not the music, and reads as "bars frozen" with headphones.
//  When no source is feeding but LyricsEngine reports playback, a
//  bass-weighted synth animation keeps the bars dancing.
//

import Cocoa
import AVFoundation
import Accelerate
import ScreenCaptureKit

// MARK: - Settings

/// Spectrum tuning, editable in Settings → 工具 → 音量律动.
enum TBSpectrumSettings {
    static let sourceKey  = "com.lyricsmtmr.spectrum.source"    // auto | system | mic
    static let lowGainKey  = "com.lyricsmtmr.spectrum.lowGain"  // 0...2
    static let midGainKey  = "com.lyricsmtmr.spectrum.midGain"  // 0...2
    static let highGainKey = "com.lyricsmtmr.spectrum.highGain" // 0...2
    static let releaseKey  = "com.lyricsmtmr.spectrum.release"  // legacy single-band
    static let lowReleaseKey  = "com.lyricsmtmr.spectrum.lowRelease"  // 0.05...0.95
    static let midReleaseKey  = "com.lyricsmtmr.spectrum.midRelease"
    static let highReleaseKey = "com.lyricsmtmr.spectrum.highRelease"

    static var source: String { UserDefaults.standard.string(forKey: sourceKey) ?? "auto" }
    static var lowGain: Double  { read(lowGainKey,  fallback: 1.00) }
    static var midGain: Double  { read(midGainKey,  fallback: 1.15) }
    static var highGain: Double { read(highGainKey, fallback: 0.90) }
    static var lowRelease: Double  { read(lowReleaseKey,  fallback: 0.55) }
    static var midRelease: Double  { read(midReleaseKey,  fallback: 0.32) }
    static var highRelease: Double { read(highReleaseKey, fallback: 0.45) }

    /// Per-band release (damping), split into thirds like the gains.
    static func release(forBand index: Int, of count: Int) -> Double {
        let third = max(1, count / 3)
        if index < third { return lowRelease }
        if index < third * 2 { return midRelease }
        return highRelease
    }

    private static func read(_ key: String, fallback: Double) -> Double {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: key) != nil else { return fallback }
        return defaults.double(forKey: key)
    }
}

// MARK: - Spectrum Renderer View

private class SpectrumView: NSView {
    var levels: [CGFloat] = [] {
        didSet { needsDisplay = true }
    }

    /// Short helper drawn centered while no source is feeding (e.g. the
    /// Screen Recording permission is missing). Tapping opens settings.
    var hint: String? {
        didSet { needsDisplay = true }
    }
    var onTap: (() -> Void)?

    var barColor: NSColor = NSColor(srgbRed: 0.36, green: 0.85, blue: 0.63, alpha: 1.0)
    var peakColor: NSColor = NSColor(srgbRed: 1.00, green: 0.56, blue: 0.34, alpha: 1.0)
    var barCount: Int = 16

    /// First touch on the Touch Bar must reach the view directly, otherwise
    /// the hint tap (open Screen Recording permission pane) is swallowed.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseUp(with event: NSEvent) {
        if hint != nil { onTap?() } else { super.mouseUp(with: event) }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        if let hint = hint {
            // Idle hint instead of flat bars: one short line, tappable.
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9, weight: .semibold),
                .foregroundColor: NSColor(srgbRed: 1.00, green: 0.72, blue: 0.30, alpha: 1.0)
            ]
            let text = hint as NSString
            let size = text.size(withAttributes: attrs)
            text.draw(at: NSPoint(x: (bounds.width - size.width) / 2,
                                  y: (bounds.height - size.height) / 2), withAttributes: attrs)
            return
        }

        let width = bounds.width
        let height = bounds.height
        let gap: CGFloat = 1.5
        let barWidth = (width - gap * CGFloat(barCount - 1)) / CGFloat(barCount)

        for i in 0..<barCount {
            let level = i < levels.count ? levels[i] : 0
            let barHeight = max(2, level * height)
            let x = CGFloat(i) * (barWidth + gap)

            let rect = CGRect(x: x, y: 0, width: barWidth, height: barHeight)
            let path = CGPath(roundedRect: rect, cornerWidth: barWidth / 3, cornerHeight: barWidth / 3, transform: nil)

            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [barColor.withAlphaComponent(0.5).cgColor, barColor.cgColor] as CFArray,
                locations: [0, 1]
            )!

            ctx.saveGState()
            ctx.addPath(path)
            ctx.clip()
            ctx.drawLinearGradient(gradient, start: CGPoint(x: x, y: 0), end: CGPoint(x: x, y: barHeight), options: [])
            ctx.restoreGState()

            if level > 0.7 {
                let peakRect = CGRect(x: x, y: barHeight - 2, width: barWidth, height: 2)
                ctx.setFillColor(peakColor.cgColor)
                ctx.fill(peakRect)
            }
        }
    }
}

// MARK: - System audio capture (ScreenCaptureKit, macOS 13+)

/// Streams the mixed output of the whole display (i.e. whatever the Mac is
/// playing) as PCM chunks. Requires the Screen Recording permission; when it
/// is missing the shareable-content query fails and `onFailed` fires so the
/// widget can fall back to the microphone.
@available(macOS 13.0, *)
private final class SystemAudioTap: NSObject, SCStreamDelegate, SCStreamOutput {
    var onSamples: (([Float]) -> Void)?
    var onFailed: (() -> Void)?

    private var stream: SCStream?
    private var failed = false
    private let queue = DispatchQueue(label: "com.lyricsmtmr.spectrum.systemaudio")

    func start() {
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
                guard let display = content.displays.first else { return self.fail() }
                let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
                let config = SCStreamConfiguration()
                config.capturesAudio = true
                config.sampleRate = 48_000
                config.channelCount = 1
                let stream = SCStream(filter: filter, configuration: config, delegate: self)
                try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: self.queue)
                try await stream.startCapture()
                self.stream = stream
            } catch {
                AppLog.error("AudioSpectrum: system audio capture unavailable: \(error.localizedDescription)")
                self.fail()
            }
        }
    }

    func stop() {
        if let stream = stream {
            try? stream.removeStreamOutput(self, type: .audio)
            try? stream.stopCapture()
        }
        stream = nil
    }

    private func fail() {
        guard !failed else { return }
        failed = true
        DispatchQueue.main.async { self.onFailed?() }
    }

    // MARK: SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, CMSampleBufferDataIsReady(sampleBuffer),
              let formatDescription = sampleBuffer.formatDescription else { return }
        let format = AVAudioFormat(cmAudioFormatDescription: formatDescription)
        let frameCount = AVAudioFrameCount(sampleBuffer.numSamples)
        // This SDK exposes no AudioBufferList accessor on CMSampleBuffer, so
        // read the CMBlockBuffer directly. SCStream audio is deinterleaved
        // float32, i.e. channel 0 occupies the first `frameCount` floats.
        guard frameCount > 0, format.commonFormat == .pcmFormatFloat32,
              let blockBuffer = sampleBuffer.dataBuffer else { return }
        var totalLength = 0
        var rawPointer: UnsafeMutablePointer<Int8>?
        let status = CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0,
                                                 lengthAtOffsetOut: nil,
                                                 totalLengthOut: &totalLength,
                                                 dataPointerOut: &rawPointer)
        guard status == kCMBlockBufferNoErr, let raw = rawPointer else { return }
        let availableFloats = totalLength / MemoryLayout<Float>.size
        let count = min(Int(frameCount), availableFloats)
        guard count > 0 else { return }
        let samples = raw.withMemoryRebound(to: Float.self, capacity: availableFloats) { pointer in
            Array(UnsafeBufferPointer(start: pointer, count: count))
        }
        onSamples?(samples)
    }

    // MARK: SCStreamDelegate

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        AppLog.error("AudioSpectrum: system audio stream stopped: \(error.localizedDescription)")
        fail()
    }
}

// MARK: - AudioSpectrumBarItem

class AudioSpectrumBarItem: NSCustomTouchBarItem {

    private let spectrumView = SpectrumView(frame: NSRect(x: 0, y: 0, width: 120, height: 30))

    private let fftSize = 1024
    private let barCount: Int
    private var requestedSource: String
    private var lastAppliedSource: String = ""
    private let settingsDriven: Bool
    private var defaultsObserver: NSObjectProtocol?

    private var audioEngine: AVAudioEngine?
    private var tapInstalled = false
    private var micActive = false

    private var systemTap: AnyObject?   // SystemAudioTap when available
    private var systemFailed = false
    private var rolling = [Float]()     // rolling window of system-audio samples
    private var lastAudibleSystem: TimeInterval = 0

    private var fftSetup: FFTSetup?
    private var smoothedLevels: [CGFloat] = []
    private var displayTimer: Timer?
    private var lastRealFeed: TimeInterval = 0
    private var lastAudibleMic: TimeInterval = 0

    init(identifier: NSTouchBarItem.Identifier, barCount: Int = 16, source: String = "") {
        self.barCount = max(4, barCount)
        // JSON `source` wins; otherwise the user setting; default auto.
        self.settingsDriven = source.isEmpty
        self.requestedSource = source.isEmpty ? TBSpectrumSettings.source : source
        super.init(identifier: identifier)
        spectrumView.barCount = self.barCount
        spectrumView.wantsLayer = true
        spectrumView.layer?.backgroundColor = NSColor.clear.cgColor
        view = spectrumView

        smoothedLevels = Array(repeating: 0, count: self.barCount)
        fftSetup = vDSP_create_fftsetup(vDSP_Length(log2(Float(fftSize))), FFTRadix(kFFTRadix2))
        rolling.reserveCapacity(fftSize * 2)

        spectrumView.onTap = { [weak self] in
            guard let self = self, self.spectrumView.hint != nil else { return }
            HapticFeedback.instance.tap(type: .medium)
            // Straight to the Screen Recording privacy pane so granting the
            // permission is one toggle away.
            let urls = [
                URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture"),
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
            ]
            for case let url? in urls {
                if NSWorkspace.shared.open(url) { break }
            }
        }

        startCapture()
        startDisplayTimer()

        // Settings-driven widgets follow 设置 → 工具 → 音量律动 live,
        // no app restart needed. JSON-pinned sources never switch.
        if settingsDriven {
            defaultsObserver = NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification, object: nil, queue: .main
            ) { [weak self] _ in
                self?.applySettingsSourceChange()
            }
        }
    }

    required init?(coder: NSCoder) { return nil }

    deinit {
        if let observer = defaultsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        displayTimer?.invalidate()
        displayTimer = nil
        stopSystem()
        stopMic()
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
        }
    }

    // MARK: - Source selection

    private func applySettingsSourceChange() {
        guard settingsDriven else { return }
        let source = TBSpectrumSettings.source
        guard source != lastAppliedSource else { return }
        requestedSource = source
        stopSystem()
        stopMic()
        lastRealFeed = 0
        startCapture()
    }

    private func startCapture() {
        lastAppliedSource = requestedSource
        switch requestedSource {
        case "mic":
            startMic()
        case "system":
            // Explicit system source: never silently swap to the mic when the
            // Screen Recording permission is missing — the synth fallback
            // covers playback instead, and the on-bar hint points the user
            // at the permission pane.
            startSystem()
        default:
            // auto = system → synth. The mic is intentionally out of the
            // chain: with headphones it hears nothing, and without them it
            // only hears the room — the bars look frozen while music plays.
            startSystem()
        }
    }

    private func startSystem() {
        guard #available(macOS 13.0, *) else { return }
        lastAudibleSystem = 0
        let tap = SystemAudioTap()
        tap.onSamples = { [weak self] samples in
            self?.ingestSystemSamples(samples)
        }
        tap.onFailed = { [weak self] in
            guard let self = self else { return }
            self.stopSystem()
            self.systemFailed = true
            // Permission missing (or SCK unavailable): tell the user instead
            // of dying silently. The synth keeps the widget alive meanwhile,
            // and tapping the hint opens the permission pane.
            self.spectrumView.hint = localized("需录屏权限 · 点按开启", "Screen Recording needed · tap")
            AppLog.error("AudioSpectrum: system audio unavailable — showing permission hint")
        }
        systemTap = tap
        tap.start()
    }

    private func stopSystem() {
        if #available(macOS 13.0, *), let tap = systemTap as? SystemAudioTap {
            tap.stop()
        }
        systemTap = nil
    }

    private func startMic() {
        // The mic path is optional — a missing device or denied permission
        // must never break the widget; the synth timer covers the display.
        let error = MTMRTryOrError { [weak self] in
            guard let self = self else { return }
            let engine = AVAudioEngine()
            let inputNode = engine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { return }
            inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(self.fftSize), format: format) { [weak self] buffer, _ in
                self?.processMicBuffer(buffer)
            }
            engine.prepare()
            do {
                try engine.start()
                self.audioEngine = engine
                self.tapInstalled = true
                self.micActive = true
            } catch {
                AppLog.error("AudioSpectrum: cannot start mic engine: \(error)")
            }
        }
        if let error = error {
            AppLog.error("AudioSpectrum: mic capture setup threw: \(error.localizedDescription)")
        }
    }

    private func stopMic() {
        if tapInstalled, let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        audioEngine = nil
        tapInstalled = false
        micActive = false
    }

    // MARK: - Sample ingestion

    /// Below this RMS (~-66 dBFS) a system-audio buffer counts as silence.
    /// The SCK tap happily streams buffers of pure zeros while nothing plays;
    /// feeding those would keep `lastRealFeed` fresh forever and block the
    /// synth fallback — the exact "bars frozen while music plays" bug.
    private static let systemNoiseGate: Float = 0.0005

    /// System audio arrives in small chunks; accumulate into a rolling window
    /// and run the FFT with 50 % overlap for a smooth, dense response.
    private func ingestSystemSamples(_ samples: [Float]) {
        var rms: Float = 0
        samples.withUnsafeBufferPointer { buffer in
            if let base = buffer.baseAddress {
                vDSP_rmsqv(base, 1, &rms, vDSP_Length(samples.count))
            }
        }
        guard rms > Self.systemNoiseGate else {
            // Stream is alive but silent: keep the tap open and let
            // `lastRealFeed` go stale — the display timer's synth covers the
            // quiet stretch, and the first audible buffer instantly restores
            // the real spectrum.
            return
        }
        lastAudibleSystem = Date().timeIntervalSince1970
        rolling.append(contentsOf: samples)
        while rolling.count >= fftSize {
            let window = Array(rolling.prefix(fftSize))
            rolling.removeFirst(fftSize / 2)
            processWindow(window)
        }
        if rolling.count > fftSize * 2 {
            rolling.removeFirst(rolling.count - fftSize)
        }
    }

    private func processMicBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount >= fftSize else { return }

        // Noise gate: with headphones on the mic hears nothing, and feeding
        // those silent buffers would freeze the bars at zero forever. Skip
        // them instead so the display timer's synth fallback can take over.
        var rms: Float = 0
        vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(frameCount))
        guard rms > Self.micNoiseGate else { return }

        lastAudibleMic = Date().timeIntervalSince1970
        processWindow(Array(UnsafeBufferPointer(start: channelData, count: fftSize)))
    }

    /// Below this RMS (~-54 dBFS) mic input counts as silence.
    private static let micNoiseGate: Float = 0.002

    // MARK: - FFT Processing

    private func processWindow(_ windowed: [Float]) {
        var windowed = windowed
        var realPart = [Float](repeating: 0, count: fftSize / 2)
        var imagPart = [Float](repeating: 0, count: fftSize / 2)

        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(windowed, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

        realPart.withUnsafeMutableBufferPointer { realBuf in
            imagPart.withUnsafeMutableBufferPointer { imagBuf in
                var splitComplex = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)
                windowed.withUnsafeBytes { rawBuf in
                    let typedBuf = rawBuf.bindMemory(to: DSPComplex.self)
                    vDSP_ctoz(typedBuf.baseAddress!, 2, &splitComplex, 1, vDSP_Length(fftSize / 2))
                }

                if let setup = self.fftSetup {
                    vDSP_fft_zrip(setup, &splitComplex, 1, vDSP_Length(log2(Float(self.fftSize))), FFTDirection(FFT_FORWARD))
                }

                var magnitudes = [Float](repeating: 0, count: fftSize / 2)
                vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))

                var normalizedMagnitudes = [Float](repeating: 0, count: fftSize / 2)
                var one: Float = 1.0
                vDSP_vdbcon(magnitudes, 1, &one, &normalizedMagnitudes, 1, vDSP_Length(fftSize / 2), 0)

                let levels = self.mapToBars(magnitudes: normalizedMagnitudes)

                DispatchQueue.main.async { [weak self] in
                    self?.feedLevels(levels)
                }
            }
        }
    }

    private func mapToBars(magnitudes: [Float]) -> [CGFloat] {
        let halfSize = fftSize / 2
        var bars = [CGFloat](repeating: 0, count: barCount)

        for i in 0..<barCount {
            let lowBin = Int(pow(Float(halfSize), Float(i) / Float(barCount)))
            let highBin = Int(pow(Float(halfSize), Float(i + 1) / Float(barCount)))
            let clampedHigh = min(highBin, halfSize - 1)
            let clampedLow = min(lowBin, clampedHigh)

            guard clampedHigh > clampedLow else { continue }

            var sum: Float = 0
            for bin in clampedLow..<clampedHigh {
                sum += magnitudes[bin]
            }
            let avg = sum / Float(clampedHigh - clampedLow)
            let normalized = max(0, min(1, (avg + 80) / 80))
            let gained = Double(normalized) * Self.gain(forBand: i, of: barCount)
            bars[i] = CGFloat(min(1.0, gained))
        }
        return bars
    }

    /// Per-band gain (low / mid / high thirds), user-tunable in settings.
    private static func gain(forBand index: Int, of count: Int) -> Double {
        let third = max(1, count / 3)
        if index < third { return TBSpectrumSettings.lowGain }
        if index < third * 2 { return TBSpectrumSettings.midGain }
        return TBSpectrumSettings.highGain
    }

    // MARK: - Level smoothing

    /// Real audio feed: fast attack, user-tuned release (damping).
    private func feedLevels(_ newLevels: [CGFloat]) {
        lastRealFeed = Date().timeIntervalSince1970
        if spectrumView.hint != nil { spectrumView.hint = nil }
        smooth(toward: newLevels, attack: 0.7) { band in
            CGFloat(max(0.05, min(0.95, TBSpectrumSettings.release(forBand: band, of: self.barCount))))
        }
    }

    private func smooth(toward targets: [CGFloat], attack: CGFloat, releaseFor: (Int) -> CGFloat) {
        for i in 0..<barCount {
            let target = i < targets.count ? targets[i] : 0
            let current = smoothedLevels[i]
            let rate = target > current ? attack : releaseFor(i)
            smoothedLevels[i] = current + (target - current) * rate
        }
        spectrumView.levels = smoothedLevels
    }

    private func smooth(toward targets: [CGFloat], attack: CGFloat, release: CGFloat) {
        smooth(toward: targets, attack: attack, releaseFor: { _ in release })
    }

    // MARK: - Display timer (synth fallback while music plays)

    private func startDisplayTimer() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.displayTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                let now = Date().timeIntervalSince1970
                // A live audible source (system tap, or mic above the noise
                // gate) drives the bars directly.
                if now - self.lastRealFeed < 0.25 { return }
                // The mic is live and was audible moments ago — give the real
                // feed a grace period so quiet passages don't flicker to synth.
                if self.micActive, now - self.lastAudibleMic < 1.2 { return }
                let info = LyricsEngine.shared.trackInfo
                if info.playbackState == .playing {
                    self.smooth(toward: Self.syntheticLevels(seed: info.playbackTime, count: self.barCount),
                                attack: 0.5, release: 0.4)
                } else {
                    self.smooth(toward: Array(repeating: 0.02, count: self.barCount),
                                attack: 0.2, release: 0.2)
                }
            }
        }
    }

    /// Bass-weighted pseudo-spectrum, seeded by playback position so the
    /// motion tracks the song instead of the wall clock.
    private static func syntheticLevels(seed: TimeInterval, count: Int) -> [CGFloat] {
        let t = seed > 0 ? seed : Date().timeIntervalSince1970
        var levels = [CGFloat](repeating: 0, count: count)
        let frame = Int(t * 25)
        for i in 0..<count {
            let f = Double(i) / Double(count)
            let bassWeight = max(0.35, 1.0 - f * 1.4)
            let w1 = 0.5 + 0.5 * sin(t * 2.2 + Double(i) * 0.55)
            let w2 = 0.5 + 0.5 * sin(t * 3.7 + Double(i) * 1.35)
            let n = pseudoRandom(frame: frame, salt: i)
            let v = (0.18 + 0.66 * (0.45 * w1 + 0.30 * w2 + 0.25 * n)) * bassWeight
            levels[i] = CGFloat(min(1.0, v))
        }
        return levels
    }

    private static func pseudoRandom(frame: Int, salt: Int) -> Double {
        var x = UInt64(bitPattern: Int64(frame)) &* 0x9E3779B97F4A7C15
        x &+= UInt64(salt &+ 1) &* 0xC2B2AE3D27D4EB4F
        x ^= x >> 33
        x &*= 0xFF51AFD7ED558CCD
        x ^= x >> 33
        return Double(x % 1000) / 1000
    }
}
