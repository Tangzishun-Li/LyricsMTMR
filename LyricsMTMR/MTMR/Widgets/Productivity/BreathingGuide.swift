//
//  BreathingGuide.swift  ·  item type: breathingGuide
//  呼吸训练：浮层整条变成一根「呼吸条」——吸气时中央光柱缓缓向两侧展开，
//  屏息时保持并轻微呼吸式明暗起伏，呼气时收回；阶段名与剩余秒数叠加在光柱中央。
//  纯本地动画，无网络。属性：pattern（如 "4-7-8"，三段秒数）。
//

import Cocoa

/// Full-width breathing lane: dark track + centered pill that expands and
/// contracts with each phase, tinted per phase.
private class BreathingLaneView: NSView {
    var phase: Int = 0          // 0 inhale · 1 hold · 2 exhale
    var progress: CGFloat = 0   // 0...1 within the current phase
    var tint: NSColor = TB.mint
    var phaseName: String = ""
    var seconds: String = ""

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    required init?(coder: NSCoder) { return nil }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let track = bounds

        // Dark rounded track.
        let trackPath = CGPath(roundedRect: track, cornerWidth: track.height / 2, cornerHeight: track.height / 2, transform: nil)
        ctx.addPath(trackPath)
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.35).cgColor)
        ctx.fillPath()

        // Breath pill width: inhale grows 12%→86%, hold stays, exhale shrinks.
        let eased = progress * progress * (3 - 2 * progress)
        let minF: CGFloat = 0.12, maxF: CGFloat = 0.86
        let fraction: CGFloat
        switch phase {
        case 0:  fraction = minF + (maxF - minF) * eased
        case 1:  fraction = maxF
        default: fraction = maxF - (maxF - minF) * eased
        }
        // Gentle shimmer while holding the breath.
        var alpha: CGFloat = 1
        if phase == 1 {
            alpha = 0.70 + 0.30 * CGFloat(abs(sin(Double(progress) * .pi * 2)))
        }

        let width = track.width * fraction
        let pill = CGRect(x: track.midX - width / 2, y: track.minY + 1.5, width: width, height: track.height - 3)
        let pillPath = CGPath(roundedRect: pill, cornerWidth: pill.height / 2, cornerHeight: pill.height / 2, transform: nil)
        ctx.saveGState()
        ctx.addPath(pillPath)
        ctx.clip()
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [tint.withAlphaComponent(0.42 * alpha).cgColor, tint.withAlphaComponent(0.22 * alpha).cgColor] as CFArray,
                                  locations: [0, 1])!
        ctx.drawLinearGradient(gradient, start: CGPoint(x: pill.minX, y: pill.maxY), end: CGPoint(x: pill.minX, y: pill.minY), options: [])
        ctx.restoreGState()
        ctx.addPath(pillPath)
        ctx.setStrokeColor(tint.withAlphaComponent(0.85 * alpha).cgColor)
        ctx.setLineWidth(1)
        ctx.strokePath()

        // Phase name + remaining seconds centered over the pill.
        let text = "\(phaseName) \(seconds)"
        let attr = TB.attributed(text, size: 12, weight: .bold, color: TB.textPrimary)
        let size = attr.size()
        attr.draw(at: CGPoint(x: track.midX - size.width / 2, y: track.midY - size.height / 2))
    }
}

class BreathingGuideItem: TBPopoverItem {
    private let phases: [(name: String, seconds: Double, tint: NSColor)]
    private weak var lane: BreathingLaneView?
    private var timer: Timer?
    private var elapsed: TimeInterval = 0
    private var total: Double = 19

    init(identifier: NSTouchBarItem.Identifier, pattern: String) {
        let nums = pattern.split(separator: "-").compactMap { Double($0) }
        let inhale = nums.count > 0 ? nums[0] : 4
        let hold = nums.count > 1 ? nums[1] : 7
        let exhale = nums.count > 2 ? nums[2] : 8
        self.phases = [
            (localized("吸气", "Inhale"), inhale, TB.mint),
            (localized("屏息", "Hold"), hold, TB.gold),
            (localized("呼气", "Exhale"), exhale, TB.sky),
        ]
        self.total = inhale + hold + exhale
        super.init(identifier: identifier)
        configureButton(title: localized("呼吸", "Breathe"), symbol: "wind", tint: TB.mint)
    }
    required init?(coder: NSCoder) { return nil }

    deinit {
        timer?.invalidate()
    }

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.97, accent: TB.mint)
        let lane = BreathingLaneView(frame: card.bounds.insetBy(dx: 3, dy: 3))
        lane.autoresizingMask = [.width, .height]
        card.addSubview(lane)
        self.lane = lane
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        elapsed = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in self?.tick() }
        return root
    }

    private func tick() {
        elapsed += 0.05
        if elapsed >= total { elapsed = 0 }
        var cursor: Double = 0
        for (index, phase) in phases.enumerated() {
            if elapsed < cursor + phase.seconds {
                let inPhase = elapsed - cursor
                let remaining = Int(ceil(phase.seconds - inPhase))
                lane?.phase = index
                lane?.tint = phase.tint
                lane?.phaseName = phase.name
                lane?.seconds = "\(remaining)"
                lane?.progress = CGFloat(inPhase / phase.seconds)
                return
            }
            cursor += phase.seconds
        }
    }

    override func closeOverlay() {
        timer?.invalidate()
        timer = nil
        super.closeOverlay()
    }
}
