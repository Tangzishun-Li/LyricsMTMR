//
//  SubscriptionCountdown.swift  ·  item type: subscriptionCountdown
//  订阅续费倒计时：读取本地 subscriptions.json，展示最近一个订阅的名称与剩余天数，
//  临期（≤3天）变珊瑚色提醒。首次启动自动播种示例。属性：dataPath（可空=默认）。
//

import Cocoa

private struct TBSubscription: Codable { let name: String; let price: Double; let renewDate: String }
private struct TBSubscriptionFile: Codable { var subscriptions: [TBSubscription] }

class SubscriptionCountdownItem: TBPollItem {
    private let dataPath: String
    private var name = "…"
    private var days = 0
    private var price = 0.0
    private static let filename = "subscriptions.json"
    private static let sample = "{\"subscriptions\":[{\"name\":\"Netflix\",\"price\":60,\"renewDate\":\"2026-08-03\"},{\"name\":\"iCloud\",\"price\":21,\"renewDate\":\"2026-08-20\"}]}"

    init(identifier: NSTouchBarItem.Identifier, refreshInterval: Double, dataPath: String) {
        self.dataPath = dataPath
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "repeat.circle.fill", tint: TB.pink,
                   label: localized("订阅", "Sub"), width: 156)
        TBStore.seed(filename: Self.filename, sample: Self.sample)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func compute() {
        let path = dataPath.isEmpty ? appSupportDirectory.appending("/\(Self.filename)") : (dataPath as NSString).expandingTildeInPath
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let file = try? JSONDecoder().decode(TBSubscriptionFile.self, from: data) else {
            name = localized("无数据", "no data"); return
        }
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let now = Date()
        var nearest: TBSubscription?
        var nearestDays = Int.max
        for sub in file.subscriptions {
            guard let date = fmt.date(from: sub.renewDate) else { continue }
            let d = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: now), to: Calendar.current.startOfDay(for: date)).day ?? 0
            if d >= 0, d < nearestDays { nearestDays = d; nearest = sub }
        }
        if let nearest = nearest { name = nearest.name; days = nearestDays; price = nearest.price }
        else { name = localized("无临期", "none due"); days = 0 }
    }

    override func apply() {
        metric.value = "\(name)"
        metric.subValue = localized("\(days)天 ¥\(Int(price))", "\(days)d")
        metric.valueColor = days <= 3 ? TB.coral : TB.textPrimary
        metric.iconTint = days <= 3 ? TB.coral : TB.pink
        metric.progress = CGFloat(max(0, min(1, 1 - Double(days) / 30.0)))
        metric.progressTint = days <= 3 ? TB.coral : TB.pink
    }
}
