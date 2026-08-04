//
//  StandupTimer.swift  ·  item type: standupTimer
//  站会计时器：浮层内用进度环做倒计时（默认 15 分钟），提供开始/暂停/重置控制，
//  到点闪烁提醒。纯本地。属性：durationMin（总时长分钟）。
//

import Cocoa

class StandupTimerItem: TBPopoverItem {
    private let totalSeconds: Double
    private var remaining: Double
    private var running = false
    private var timer: Timer?
    private weak var ring: TBRingView?
    private weak var timeLabel: NSTextField?

    init(identifier: NSTouchBarItem.Identifier, durationMin: Double) {
        self.totalSeconds = max(1, durationMin) * 60
        self.remaining = totalSeconds
        super.init(identifier: identifier)
        configureButton(title: localized("站会", "Standup"), symbol: "timer", tint: TB.coral)
    }
    required init?(coder: NSCoder) { return nil }

    deinit {
        timer?.invalidate()
    }

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.97, accent: TB.coral)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        let ring = TBRingView(frame: NSRect(x: close.frame.maxX + 10, y: (card.bounds.height - 24) / 2, width: 24, height: 24))
        ring.tint = TB.coral
        card.addSubview(ring)
        self.ring = ring
        let label = NSTextField(labelWithString: Self.fmt(remaining))
        label.font = .monospacedDigitSystemFont(ofSize: 13, weight: .bold)
        label.textColor = TB.textPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: ring.trailingAnchor, constant: 10),
        ])
        timeLabel = label
        refresh()
        let start = TBOverlay.pillButton(title: localized("开始", "Start"), tag: 0, target: self, action: #selector(control(_:)), tint: TB.mint)
        let pause = TBOverlay.pillButton(title: localized("暂停", "Pause"), tag: 1, target: self, action: #selector(control(_:)), tint: TB.gold)
        let reset = TBOverlay.pillButton(title: localized("重置", "Reset"), tag: 2, target: self, action: #selector(control(_:)), tint: TB.sky)
        TBOverlay.buttonRow(in: card, buttons: [start, pause, reset], afterClose: close, centered: true)
        return root
    }

    @objc private func control(_ sender: NSButton) {
        HapticFeedback.instance.tap(type: .weak)
        switch sender.tag {
        case 0:
            running = true
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.tick() }
        case 1:
            running = false
            timer?.invalidate()
        default:
            running = false
            timer?.invalidate()
            remaining = totalSeconds
            refresh()
        }
    }

    private func tick() {
        guard running else { return }
        remaining -= 0.5
        if remaining <= 0 {
            remaining = 0
            running = false
            timer?.invalidate()
            HapticFeedback.instance.tap(type: .strong)
        }
        refresh()
    }

    private func refresh() {
        ring?.progress = CGFloat(1 - remaining / totalSeconds)
        ring?.centerText = remaining <= 0 ? "!" : ""
        ring?.tint = remaining <= 60 ? TB.coral : TB.mint
        timeLabel?.stringValue = remaining <= 0 ? localized("时间到", "time up") : Self.fmt(remaining)
    }

    override func closeOverlay() {
        timer?.invalidate()
        timer = nil
        super.closeOverlay()
    }

    private static func fmt(_ seconds: Double) -> String {
        let s = Int(seconds.rounded(.up))
        return "\(s / 60):\(String(format: "%02d", s % 60))"
    }
}
