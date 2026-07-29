//
//  MeetingCountdown.swift  ·  item type: meetingCountdown
//  下一个会议倒计时：读取系统日历（EventKit）未来 8 小时内最近的事件，展示标题与开始倒计时；
//  进行中则显示「会议中」。需要日历权限；未授权显示「需要权限」。无专属属性。
//

import Cocoa
import EventKit

class MeetingCountdownItem: TBPollItem {
    private var title = "…"
    private var countdown = ""
    private var tint = TB.gold

    init(identifier: NSTouchBarItem.Identifier, refreshInterval: Double) {
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "person.3.fill", tint: TB.gold,
                   label: localized("会议", "Meet"), width: 168)
        TBEvents.requestAccess()
    }
    required init?(coder: NSCoder) { return nil }

    override func compute() {
        guard TBEvents.authorized else {
            title = localized("需要权限", "need access")
            countdown = localized("日历", "calendar")
            tint = TB.coral
            return
        }
        let now = Date()
        let events = TBEvents.events(from: now.addingTimeInterval(-6 * 3600), to: now.addingTimeInterval(8 * 3600))
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
        guard let next = events.first(where: { $0.endDate > now }) else {
            title = localized("无会议", "no meeting")
            countdown = "8h"
            tint = TB.textTertiary
            return
        }
        title = String((next.title ?? localized("会议", "Meeting")).prefix(10))
        if next.startDate <= now {
            countdown = localized("进行中", "now")
            tint = TB.coral
        } else {
            countdown = Self.format(next.startDate.timeIntervalSince(now))
            tint = next.startDate.timeIntervalSince(now) < 900 ? TB.coral : TB.gold
        }
    }

    override func apply() {
        metric.value = title
        metric.subValue = countdown
        metric.valueColor = TB.textPrimary
        metric.iconTint = tint
    }

    private static func format(_ seconds: TimeInterval) -> String {
        let s = Int(max(0, seconds))
        if s >= 3600 { return "\(s / 3600)h\(s % 3600 / 60)m" }
        return "\(s / 60)m"
    }
}
