//
//  PostureReminder.swift  ·  item type: postureReminder
//  久坐提醒：从启动开始累计久坐时长，到达设定分钟数后弹出珊瑚色「站起来活动」提醒，
//  持续约 20 秒后自动进入下一轮计数。
//  交互：提醒中点按 = 已活动，结束提醒并重新计时；倒计时中点按 = 主动休息，重新计时。
//  属性：intervalMin（提醒间隔分钟）。
//

import Cocoa

class PostureReminderItem: TBPollItem {
    private let intervalSeconds: Double
    private var cycleStart = Date()
    private var alerting = false
    private var alertStart = Date()
    private var flashMessage: (text: String, until: Date)?

    init(identifier: NSTouchBarItem.Identifier, refreshInterval: Double, intervalMin: Double) {
        self.intervalSeconds = max(1, intervalMin) * 60
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "figure.stand", tint: TB.mint,
                   label: localized("久坐", "Posture"), width: 150)
        metric.progressTint = TB.mint
        let tap = NSClickGestureRecognizer(target: self, action: #selector(tapped))
        metric.addGestureRecognizer(tap)
    }
    required init?(coder: NSCoder) { return nil }

    @objc private func tapped() {
        HapticFeedback.instance.tap(type: .medium)
        if alerting {
            // 确认已活动：结束提醒，开始新一轮计时
            alerting = false
            cycleStart = Date()
            flashMessage = (localized("已活动 ✓", "nice ✓"), Date().addingTimeInterval(1.8))
        } else {
            // 主动休息：提前重置本轮计时
            cycleStart = Date()
            flashMessage = (localized("已休息，重新计时", "break taken"), Date().addingTimeInterval(1.8))
        }
        apply()
    }

    override func compute() {
        if alerting {
            if Date().timeIntervalSince(alertStart) > 20 {
                // 自动消除后必须重新开始计时，否则会立刻再次触发提醒
                alerting = false
                cycleStart = Date()
            }
        } else if Date().timeIntervalSince(cycleStart) >= intervalSeconds {
            alerting = true
            alertStart = Date()
        }
    }

    override func apply() {
        if let flash = flashMessage {
            if Date() < flash.until {
                metric.value = flash.text
                metric.subValue = nil
                metric.valueColor = TB.mint
                metric.iconTint = TB.mint
                metric.iconName = "figure.stand"
                metric.progress = 0
                metric.progressTint = TB.mint
                return
            }
            flashMessage = nil
        }
        let elapsed = Date().timeIntervalSince(cycleStart)
        if alerting {
            metric.value = localized("站起来!", "Stand up!")
            metric.subValue = localized("点按确认", "tap to dismiss")
            metric.valueColor = TB.coral
            metric.iconTint = TB.coral
            metric.iconName = "figure.walk"
            metric.progress = 1
            metric.progressTint = TB.coral
        } else {
            let remaining = Int(max(0, intervalSeconds - elapsed))
            metric.value = "\(remaining / 60):\(String(format: "%02d", remaining % 60))"
            metric.subValue = localized("后可休息", "to break")
            metric.valueColor = TB.textPrimary
            metric.iconTint = TB.mint
            metric.iconName = "figure.stand"
            metric.progress = CGFloat(min(1, elapsed / intervalSeconds))
            metric.progressTint = TB.mint
        }
    }
}
