//
//  AudioSpectrumBarItem.swift
//  LyricsMTMR
//
//  Real-time audio spectrum visualizer for the Touch Bar.
//  Uses CoreAudio process tap + vDSP FFT to render animated frequency bars.
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
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        stopCapture()
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
        }
    }

    // MARK: - Audio Capture

    private func startCapture() {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        guard format.sampleRate > 0, format.channelCount > 0 else {
            startFallbackAnimation()
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(fftSize), format: format) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }

        engine.prepare()
        do {
            try engine.start()
            audioEngine = engine
            tapInstalled = true
        } catch {
            AppLog.error("AudioSpectrum: cannot start engine: \(error)")
            startFallbackAnimation()
        }
    }

    private func stopCapture() {
        timer?.invalidate()
        timer = nil
        if tapInstalled, let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        audioEngine = nil
        tapInstalled = false
    }

    // MARK: - FFT Processing

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount >= fftSize else { return }

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

    private func startFallbackAnimation() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                let isPlaying = LyricsEngine.shared.trackInfo.playbackState == .playing
                var levels = [CGFloat](repeating: 0, count: self.barCount)
                for i in 0..<self.barCount {
                    if isPlaying {
                        let phase = Date().timeIntervalSince1970 * 3.0 + Double(i) * 0.5
                        levels[i] = CGFloat(0.3 + 0.25 * sin(phase) + 0.15 * sin(phase * 2.3))
                    } else {
                        levels[i] = 0.05
                    }
                }
                self.updateLevels(levels)
            }
        }
    }
}
