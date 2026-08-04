//
//  AudioSpectrumBarItem.swift
//  LyricsMTMR
//
//  Real-time audio spectrum visualizer for the Touch Bar.
//  Two sources feed the bars:
//   1. Mic capture (AVAudioEngine tap + vDSP FFT) for ambient sound.
//   2. A music-driven synthesis: whenever LyricsEngine reports playback,
//      bass-weighted animated bars are generated (seeded by playback time),
//      because macOS cannot tap system audio without a loopback device.
//  The synth takes priority while music plays so the bars always dance.
//

import Cocoa
import AVFoundation
import Accelerate

// MARK: - Spectrum Renderer View

private class SpectrumView: NSView {
    var levels: [CGFloat] = [] {
        didSet { needsDisplay = true }
    }

    var barColor: NSColor = NSColor(srgbRed: 0.36, green: 0.85, blue: 0.63, alpha: 1.0)
    var peakColor: NSColor = NSColor(srgbRed: 1.00, green: 0.56, blue: 0.34, alpha: 1.0)
    var barCount: Int = 16

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

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

// MARK: - AudioSpectrumBarItem

class AudioSpectrumBarItem: NSCustomTouchBarItem {

    private let spectrumView = SpectrumView(frame: NSRect(x: 0, y: 0, width: 120, height: 30))
    private var timer: Timer?

    private let fftSize = 1024
    private let barCount: Int
    private var audioEngine: AVAudioEngine?
    private var tapInstalled = false

    private var fftSetup: FFTSetup?
    private var smoothedLevels: [CGFloat] = []
    private var displayTimer: Timer?
    private var micActive = false
    private var lastMicUpdate: TimeInterval = 0

    init(identifier: NSTouchBarItem.Identifier, barCount: Int = 16) {
        self.barCount = barCount
        super.init(identifier: identifier)
        spectrumView.barCount = barCount
        spectrumView.wantsLayer = true
        spectrumView.layer?.backgroundColor = NSColor.clear.cgColor
        view = spectrumView

        smoothedLevels = Array(repeating: 0, count: barCount)
        fftSetup = vDSP_create_fftsetup(vDSP_Length(log2(Float(fftSize))), FFTRadix(kFFTRadix2))

        startCapture()
        startDisplayTimer()
    }

    required init?(coder: NSCoder) { return nil }


    deinit {
        stopCapture()
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
        }
    }

    // MARK: - Audio Capture

    private func startCapture() {
        // The mic path is optional — a missing device or denied permission
        // must never break the widget; the synth timer covers the display.
        let error = MTMRTryOrError { [weak self] in
            guard let self = self else { return }
            let engine = AVAudioEngine()
            let inputNode = engine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { return }
            inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(self.fftSize), format: format) { [weak self] buffer, _ in
                self?.processAudioBuffer(buffer)
            }
            engine.prepare()
            do {
                try engine.start()
                self.audioEngine = engine
                self.tapInstalled = true
                self.micActive = true
            } catch {
                AppLog.error("AudioSpectrum: cannot start engine: \(error)")
            }
        }
        if let error = error {
            AppLog.error("AudioSpectrum: capture setup threw: \(error.localizedDescription)")
        }
    }

    private func stopCapture() {
        displayTimer?.invalidate()
        displayTimer = nil
        timer?.invalidate()
        timer = nil
        if tapInstalled, let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        audioEngine = nil
        tapInstalled = false
        micActive = false
    }

    // MARK: - FFT Processing

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount >= fftSize else { return }
        lastMicUpdate = Date().timeIntervalSince1970

        var realPart = [Float](repeating: 0, count: fftSize / 2)
        var imagPart = [Float](repeating: 0, count: fftSize / 2)

        var windowed = [Float](repeating: 0, count: fftSize)
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(channelData, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

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
                    self?.updateLevels(levels)
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
            bars[i] = CGFloat(normalized)
        }
        return bars
    }

    private func updateLevels(_ newLevels: [CGFloat]) {
        let smoothing: CGFloat = 0.3
        for i in 0..<barCount {
            let target = i < newLevels.count ? newLevels[i] : 0
            let current = smoothedLevels[i]
            if target > current {
                smoothedLevels[i] = current + (target - current) * 0.7
            } else {
                smoothedLevels[i] = current + (target - current) * smoothing
            }
        }
        spectrumView.levels = smoothedLevels
    }

    // MARK: - Fallback (animated idle bars when no mic access)

    // MARK: - Display timer (music-driven synthesis)

    private func startDisplayTimer() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.displayTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                let info = LyricsEngine.shared.trackInfo
                if info.playbackState == .playing {
                    // Music playing → synth bars always win (the mic cannot
                    // hear system audio, so real FFT would sit still).
                    self.updateLevels(self.syntheticLevels(seed: info.playbackTime))
                    return
                }
                if self.micActive, Date().timeIntervalSince1970 - self.lastMicUpdate < 0.3 {
                    return // mic tap is actively feeding levels
                }
                self.updateLevels(Array(repeating: 0.03, count: self.barCount))
            }
        }
    }

    /// Bass-weighted pseudo-spectrum, seeded by playback position so the
    /// motion tracks the song instead of the wall clock.
    private func syntheticLevels(seed: TimeInterval) -> [CGFloat] {
        let t = seed > 0 ? seed : Date().timeIntervalSince1970
        var levels = [CGFloat](repeating: 0, count: barCount)
        let frame = Int(t * 25)
        for i in 0..<barCount {
            let f = Double(i) / Double(barCount)
            let bassWeight = max(0.35, 1.0 - f * 1.4)
            let w1 = 0.5 + 0.5 * sin(t * 2.2 + Double(i) * 0.55)
            let w2 = 0.5 + 0.5 * sin(t * 3.7 + Double(i) * 1.35)
            let n = Self.pseudoRandom(frame: frame, salt: i)
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
