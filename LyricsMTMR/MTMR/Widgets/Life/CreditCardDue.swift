//
//  CreditCardDue.swift  ·  item type: creditCardDue
//  信用卡还款倒计时：读取本地 creditcards.json，展示最近一期账单的卡名、剩余天数与金额，
//  临期（≤3天）变珊瑚色提醒。首次启动自动播种示例。属性：dataPath（可空=默认）、refreshInterval。
//

import Cocoa

private struct TBCard: Codable { let name: String; let due: String; let amount: Double }
private struct TBCardFile: Codable { var creditcards: [TBCard] }

class CreditCardDueItem: TBPollItem {
    private let dataPath: String
    private var name = "…"
    private var days = 0
    private var amount = 0.0
    private static let filename = "creditcards.json"
    private static let sample = "{\"creditcards\":[{\"name\":\"\(localized("招商", "CMB"))\",\"due\":\"2026-08-10\",\"amount\":1200},{\"name\":\"\(localized("交行", "BCM"))\",\"due\":\"2026-08-25\",\"amount\":860}]}"

    init(identifier: NSTouchBarItem.Identifier, refreshInterval: Double, dataPath: String) {
        self.dataPath = dataPath
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "creditcard.fill", tint: TB.sky,
                   label: localized("还款", "Card"), width: 156)
        TBStore.seed(filename: Self.filename, sample: Self.sample)
    }
    required init?(coder: NSCoder) { return nil }

    override func compute() {
        let path = dataPath.isEmpty ? appSupportDirectory.appending("/\(Self.filename)") : (dataPath as NSString).expandingTildeInPath
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let file = try? JSONDecoder().decode(TBCardFile.self, from: data) else {
            name = localized("无数据", "no data"); return
        }
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let today = Calendar.current.startOfDay(for: Date())
        var nearest: TBCard?
        var nearestDays = Int.max
        for card in file.creditcards {
            guard let date = fmt.date(from: card.due) else { continue }
            let d = Calendar.current.dateComponents([.day], from: today, to: Calendar.current.startOfDay(for: date)).day ?? 0
            if d >= 0, d < nearestDays { nearestDays = d; nearest = card }
        }
        if let nearest = nearest { name = nearest.name; days = nearestDays; amount = nearest.amount }
        else { name = localized("无账单", "none"); days = 0 }
    }

    override func apply() {
        metric.value = name
        metric.subValue = localized("\(days)天 ¥\(Int(amount))", "\(days)d ¥\(Int(amount))")
        metric.valueColor = days <= 3 ? TB.coral : TB.textPrimary
        metric.iconTint = days <= 3 ? TB.coral : TB.sky
        metric.progress = CGFloat(max(0, min(1, 1 - Double(days) / 30.0)))
        metric.progressTint = days <= 3 ? TB.coral : TB.sky
    }
}
