//
//  DailyQuote.swift  ·  item type: dailyQuote
//  每日一言：调用 hitokoto 免费接口获取一句短句展示在 Touch Bar 上。无需 API Key。
//  属性：refreshInterval。
//

import Cocoa

class DailyQuoteItem: TBPollItem {
    private var quote = "…"
    private var source = ""

    init(identifier: NSTouchBarItem.Identifier, refreshInterval: Double) {
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "quote.opening", tint: TB.purple,
                   label: localized("一言", "Quote"), width: 220)
    }
    required init?(coder: NSCoder) { return nil }

    override func compute() {
        guard let json = TBNet.json("https://v1.hitokoto.cn/?c=a&c=b&c=d&c=k") as? [String: Any],
              let text = json["hitokoto"] as? String else {
            quote = localized("离线：心有所向，方能行远", "offline quote")
            source = "mock"
            return
        }
        quote = text
        source = (json["from"] as? String) ?? ""
    }

    override func apply() {
        // 完整文案交给 TBMetricView 按可用宽度自动省略号截断，避免硬截断后仍挤压重叠
        metric.value = quote
        metric.subValue = source.isEmpty ? nil : source
        metric.valueColor = TB.textPrimary
    }
}
