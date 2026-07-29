//
//  PostureReminder.swift  ·  item type: postureReminder
//  久坐提醒：从启动开始累计久坐时长，到达设定分钟数后弹出珊瑚色「站起来活动」提醒，
//  持续约 20 秒后自动进入下一轮计数。属性：intervalMin（提醒间隔分钟）。
//

import Cocoa

class PostureReminderItem: TBPollItem {
    private let intervalSeconds: Double
    private let startDate = Date()
    private var alerting = false
    private var alertStart: TimeInterval = 0

    init(identifier: NSTouchBarItem.Identifier, refreshInterval: Double, intervalMin: Double) {
        self.intervalSeconds = max(1, intervalMin) * 60
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "figure.stand", tint: TB.mint,
                   label: localized("久坐", "Posture"), width: 150)
        metric.progressTint = TB.mint
    }
    required init?(coder: NSCoder) { return nil }

    override func compute() {
        let elapsed = Date().timeIntervalSince(startDate)
        if alerting {
            if elapsed - alertStart > 20 { alerting = false }
        } else if elapsed >= intervalSeconds {
            alerting = true
            alertStart = elapsed
        }
    }

    override func apply() {
        let elapsed = Date().timeIntervalSince(startDate)
        if alerting {
            metric.value = localized("站起来!", "Stand up!")
            metric.subValue = localized("活动一下", "move around")
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
