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
    private var tapInstalled = false

    /// round 24 收官审计：采集暂停门。AVAudioEngine 麦克风 tap 与 bar 显隐
    /// 零关联（原实现仅 deinit 停引擎）——隐藏期（黑名单 app / exitTouchbar）
    /// 麦克风持续采集、隐私指示灯常亮，与 round 21 AudioSpectrum 采集链同
    /// 类（事件驱动源在隐藏期持续产生事件）；本卡纳入暂停：隐藏期停引擎
    /// （零回调 + 隐私灯熄灭），恢复时重启引擎 + 基类立即补刷。
    /// round 23 播种：隐藏期重建时 init 不启动采集（GPS/麦克风不亮）。
    private let micPauseGate = TBPauseGate(startPaused: TouchBarVisibilityState.shared.isBarHidden)

    init(identifier: NSTouchBarItem.Identifier, refreshInterval: Double) {
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "mic.fill", tint: TB.purple,
                   label: localized("噪音", "dB"), width: 150)
        metric.progressTint = TB.purple
        if !micPauseGate.isPaused {
            startEngine()
        }
    }
    required init?(coder: NSCoder) { return nil }
    deinit { engine.stop() }

    /// 启动麦克风采集。tap 仅安装一次（引擎 stop/start 复用同一 tap——
    /// 重复 installTap 会抛异常）；引擎重启不重弹 TCC 授权（授权持久化，
    /// 同 round 21 论证）。internal：单测注入点——计数子类 override 计数，
    /// 不触碰真实 AVFoundation 硬件。
    func startEngine() {
        guard !running else { return }
        if !tapInstalled {
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
            tapInstalled = true
        }
        do {
            try engine.start()
            running = true
        } catch {
            running = false
        }
    }

    /// 停止麦克风采集（隐私指示灯熄灭）。幂等；tap 保留，start 复用。
    /// internal：单测注入点。
    func stopEngine() {
        guard running else { return }
        engine.stop()
        running = false
    }

    /// round 24：隐藏暂停——override 基类 setPaused 融合采集链启停。
    /// 先按 gate 变更启停引擎（重复广播幂等），再交基类（compute 循环
    /// 暂停/恢复 + 恢复立即补刷）。广播来自主线程，启停即主线程。
    override func setPaused(_ paused: Bool) {
        if micPauseGate.setPaused(paused) {
            if paused {
                stopEngine()
            } else {
                startEngine()
            }
        }
        super.setPaused(paused)
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
