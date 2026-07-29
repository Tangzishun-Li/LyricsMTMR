//
//  NoiseMeter.swift  ·  item type: noiseMeter
//  环境噪音检测：通过 AVAudioEngine 采集麦克风，实时估算分贝（dB）并以火花线展示。
//  需要麦克风权限；未授权或无设备时显示「需要权限」。属性：refreshInterval。
//

import Cocoa
import AVFoundation

class NoiseMeterItem: TBPollItem {
    private let engine = AVAudioEngine()
    private var level: Float = -160
    private var running = false
    private var history: [CGFloat] = []

    init(identifier: NSTouchBarItem.Identifier, refreshInterval: Double) {
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "mic.fill", tint: TB.purple,
                   label: localized("噪音", "dB"), width: 150)
        metric.progressTint = TB.purple
        startEngine()
    }
    required init?(coder: NSCoder) { return nil }
    deinit { engine.stop() }

    private func startEngine() {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { return }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let channel = buffer.floatChannelData?[0] else { return }
            let frames = Int(buffer.frameLength)
            guard frames > 0 else { return }
            var sum: Float = 0
            for i in 0..<frames { sum += channel[i] * channel[i] }
            let rms = sqrtf(sum / Float(frames))
            let db = 20 * log10f(max(rms, 0.000001))
            self?.level = db
        }
        do {
            try engine.start()
            running = true
        } catch {
            running = false
        }
    }

    override func compute() {
        guard running else { return }
        let normalized = CGFloat(max(0, min(1, (level + 80) / 80)))
        history.append(normalized)
        if history.count > 24 { history.removeFirst(history.count - 24) }
    }

    override func apply() {
        guard running else {
            metric.value = localized("需要权限", "need mic")
            metric.valueColor = TB.coral
            metric.subValue = nil
            return
        }
        let db = Int(max(0, level + 80))
        metric.value = "\(db) dB"
        metric.subValue = Self.judge(level)
        metric.valueColor = level > -30 ? TB.coral : (level > -45 ? TB.gold : TB.mint)
        metric.spark = history
    }

    private static func judge(_ db: Float) -> String {
        switch db {
        case ..<(-50): return localized("安静", "quiet")
        case ..<(-35): return localized("适中", "normal")
        default: return localized("偏吵", "loud")
        }
    }
}
