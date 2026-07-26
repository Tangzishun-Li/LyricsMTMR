//
//  ReadTimer.swift  ·  item type: readTimer
//  阅读计时：浮层内一键开始/暂停本次阅读计时，累计今日阅读时长（进程级），用进度环展示。
//  纯本地，无属性。
//

import Cocoa

class ReadTimerItem: TBPopoverItem {
    private weak var ring: TBRingView?
    private weak var timeLabel: NSTextField?
    private var timer: Timer?
    private var running = false
    private static var accumulated: TimeInterval = 0

    override init(identifier: NSTouchBarItem.Identifier) {
        super.init(identifier: identifier)
        configureButton(title: localized("阅读计时", "ReadTimer"), symbol: "book.pages.fill", tint: TB.mint)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.6, accent: TB.mint)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        let ring = TBRingView(frame: NSRect(x: close.frame.maxX + 10, y: (card.bounds.height - 24) / 2, width: 24, height: 24))
        ring.tint = TB.mint
        card.addSubview(ring)
        self.ring = ring
        let label = NSTextField(labelWithString: Self.fmt(Self.accumulated))
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
        let toggle = TBOverlay.pillButton(title: running ? localized("暂停", "Pause") : localized("开始", "Start"), tag: 0, target: self, action: #selector(toggle), tint: TB.mint)
        let reset = TBOverlay.pillButton(title: localized("归零", "Reset"), tag: 1, target: self, action: #selector(reset), tint: TB.sky)
        TBOverlay.buttonRow(in: card, buttons: [toggle, reset], afterClose: close)
        return root
    }

    @objc private func toggle() {
        HapticFeedback.instance.tap(type: .weak)
        running.toggle()
        timer?.invalidate()
        if running {
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Self.accumulated += 1
                self?.refresh()
            }
        }
    }

    @objc private func reset() {
        HapticFeedback.instance.tap(type: .weak)
        Self.accumulated = 0
        refresh()
    }

    private func refresh() {
        let minutes = Self.accumulated / 60
        ring?.progress = CGFloat((minutes.truncatingRemainder(dividingBy: 60)) / 60)
        ring?.tint = running ? TB.mint : TB.gold
        timeLabel?.stringValue = Self.fmt(Self.accumulated)
    }

    override func closeOverlay() {
        timer?.invalidate()
        timer = nil
        super.closeOverlay()
    }

    private static func fmt(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        return "\(s / 3600):\(String(format: "%02d", (s % 3600) / 60)):\(String(format: "%02d", s % 60))"
    }
}
