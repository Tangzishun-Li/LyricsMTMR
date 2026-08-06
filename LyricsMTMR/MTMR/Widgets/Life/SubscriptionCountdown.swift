//
//  SubscriptionCountdown.swift  ·  item type: subscriptionCountdown
//  订阅续费倒计时：读取本地 subscriptions.json，按剩余天数从近到远排序，
//  展示第 index 个（0 起）订阅的名称与剩余天数；临期（≤3天）变珊瑚色提醒。
//  多个组件可用不同 index 并排展示接下来要续费的几项。
//  首次启动自动播种示例。属性：dataPath（可空=默认）、index（0 起，默认 0）、
//  tint（mint/coral/sky/gold/purple/pink，可空=粉）。
//

import Cocoa

private struct TBSubscription: Codable { let name: String; let price: Double; let renewDate: String }
private struct TBSubscriptionFile: Codable { var subscriptions: [TBSubscription] }

class SubscriptionCountdownItem: TBPollItem {
    private let dataPath: String
    private let index: Int
    private let tint: NSColor
    private var name = "…"
    private var days = 0
    private var price = 0.0
    private static let filename = "subscriptions.json"
    private static let sample = "{\"subscriptions\":[{\"name\":\"Netflix\",\"price\":60,\"renewDate\":\"2026-08-08\"},{\"name\":\"iCloud\",\"price\":21,\"renewDate\":\"2026-08-20\"},{\"name\":\"Spotify\",\"price\":58,\"renewDate\":\"2026-09-01\"},{\"name\":\"Bilibili\",\"price\":25,\"renewDate\":\"2026-09-15\"}]}"

    init(identifier: NSTouchBarItem.Identifier, refreshInterval: Double, dataPath: String, index: Int = 0, tint: String = "") {
        self.dataPath = dataPath
        self.index = max(0, index)
        self.tint = TB.tint(named: tint, fallback: TB.pink)
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "repeat.circle.fill", tint: self.tint,
                   label: localized("订阅", "Sub"), width: 156)
        TBStore.seed(filename: Self.filename, sample: Self.sample)
    }
    required init?(coder: NSCoder) { return nil }

    override func compute() {
        let path = dataPath.isEmpty ? appSupportDirectory.appending("/\(Self.filename)") : (dataPath as NSString).expandingTildeInPath
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let file = try? JSONDecoder().decode(TBSubscriptionFile.self, from: data) else {
            name = localized("无数据", "no data"); return
        }
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let now = Date()
        // Upcoming subs sorted nearest-first; `index` picks which one to show.
        var upcoming: [(sub: TBSubscription, days: Int)] = []
        for sub in file.subscriptions {
            guard let date = fmt.date(from: sub.renewDate) else { continue }
            let d = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: now), to: Calendar.current.startOfDay(for: date)).day ?? 0
            if d >= 0 { upcoming.append((sub, d)) }
        }
        upcoming.sort { $0.days < $1.days }
        if index < upcoming.count {
            let pick = upcoming[index]
            name = pick.sub.name; days = pick.days; price = pick.sub.price
        } else {
            name = localized("无更多", "no more"); days = 0; price = 0
        }
    }

    override func apply() {
        metric.value = "\(name)"
        metric.subValue = localized("\(days)天 ¥\(Int(price))", "\(days)d")
        metric.valueColor = days <= 3 ? TB.coral : TB.textPrimary
        metric.iconTint = days <= 3 ? TB.coral : tint
        metric.progress = CGFloat(max(0, min(1, 1 - Double(days) / 30.0)))
        metric.progressTint = days <= 3 ? TB.coral : tint
    }
}
