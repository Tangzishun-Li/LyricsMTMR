//
//  BreathingGuide.swift  ·  item type: breathingGuide
//  呼吸训练：浮层内用进度环引导 4-7-8（吸气-屏息-呼气）节奏，实时显示当前阶段与倒计时。
//  纯本地动画，无网络。属性：pattern（如 "4-7-8"，三段秒数）。
//

import Cocoa

class BreathingGuideItem: TBPopoverItem {
    private let phases: [(name: String, seconds: Double, tint: NSColor)]
    private weak var ring: TBRingView?
    private weak var phaseLabel: NSTextField?
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

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.97, accent: TB.mint)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        let ring = TBRingView(frame: NSRect(x: close.frame.maxX + 10, y: (card.bounds.height - 24) / 2, width: 24, height: 24))
        ring.tint = TB.mint
        ring.centerText = "4"
        card.addSubview(ring)
        self.ring = ring
        let label = NSTextField(labelWithString: localized("吸气", "Inhale"))
        label.font = .systemFont(ofSize: 13, weight: .bold)
        label.textColor = TB.mint
        label.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: ring.trailingAnchor, constant: 12),
        ])
        phaseLabel = label
        elapsed = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in self?.tick() }
        return root
    }

    private func tick() {
        elapsed += 0.05
        if elapsed >= total { elapsed = 0 }
        var cursor: Double = 0
        for phase in phases {
            if elapsed < cursor + phase.seconds {
                let inPhase = elapsed - cursor
                let remaining = Int(ceil(phase.seconds - inPhase))
                ring?.tint = phase.tint
                ring?.centerText = "\(remaining)"
                ring?.progress = CGFloat(inPhase / phase.seconds)
                phaseLabel?.stringValue = phase.name
                phaseLabel?.textColor = phase.tint
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
