//
//  TravelCountdown.swift  ·  item type: travelCountdown
//  航班/高铁倒计时：读取系统日历（EventKit）未来 72 小时内含出行关键词的事件，
//  展示最近一程的标题与剩余时间。需要日历权限；未授权显示「需要权限」。属性：calendarFilter（额外关键词，可空）。
//

import Cocoa
import EventKit

class TravelCountdownItem: TBPollItem {
    private let extraKeywords: [String]
    private var title = "…"
    private var countdown = ""
    private var tint = TB.sky
    private static let baseKeywords = ["航班", "高铁", "火车", "机票", "登机", "起飞", "flight", "train", "机场", "候车"]

    init(identifier: NSTouchBarItem.Identifier, refreshInterval: Double, calendarFilter: String) {
        self.extraKeywords = calendarFilter.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "airplane.departure", tint: TB.sky,
                   label: localized("出行", "Travel"), width: 168)
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
        let events = TBEvents.events(from: now, to: now.addingTimeInterval(72 * 3600))
        let keywords = Self.baseKeywords + extraKeywords
        let matched = events.filter { event in
            let text = (event.title ?? "").lowercased()
            return keywords.contains { text.contains($0) }
        }.sorted { $0.startDate < $1.startDate }
        guard let next = matched.first else {
            title = localized("无行程", "no trip")
            countdown = "72h"
            tint = TB.textTertiary
            return
        }
        title = String((next.title ?? "").prefix(10))
        countdown = Self.format(next.startDate.timeIntervalSince(now))
        tint = next.startDate.timeIntervalSince(now) < 3 * 3600 ? TB.coral : TB.sky
    }

    override func apply() {
        metric.value = title
        metric.subValue = countdown
        metric.valueColor = TB.textPrimary
        metric.iconTint = tint
    }

    private static func format(_ seconds: TimeInterval) -> String {
        let s = Int(max(0, seconds))
        if s >= 86400 { return "\(s / 86400)d\(s % 86400 / 3600)h" }
        if s >= 3600 { return "\(s / 3600)h\(s % 3600 / 60)m" }
        return "\(s / 60)m"
    }
}
