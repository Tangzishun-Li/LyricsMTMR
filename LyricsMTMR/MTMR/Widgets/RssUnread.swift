//
//  RssUnread.swift  ·  item type: rssUnread
//  RSS 未读数：统计 Feedly / Inoreader 的未读条目总数并显示角标式数字。
//  需要在「设置 → 服务」里选择提供商并配置 API Key；未配置时显示未配置并回退 mock。
//  属性：provider（可空=用服务里的提供商）、refreshInterval。
//

import Cocoa

class RssUnreadItem: TBPollItem {
    private let provider: String
    private var unread = 0
    private var configured = true

    init(identifier: NSTouchBarItem.Identifier, provider: String, refreshInterval: Double) {
        self.provider = provider
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "dot.radiowaves.left.and.right", tint: TB.gold,
                   label: "RSS", width: 128)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func compute() {
        let useProvider = provider.isEmpty ? AppSettings.rssProvider : provider
        let key = AppSettings.rssAPIKey
        guard !key.isEmpty else {
            configured = false
            unread = 12   // mock，便于无 Key 环境测试
            return
        }
        configured = true
        if useProvider.lowercased().contains("inoreader") {
            guard let json = TBNet.json("https://api.inoreader.com/api/0/unread-count", headers: ["Authorization": "Bearer \(key)"]),
                  let items = (json as? [String: Any])?["unreadcounts"] as? [[String: Any]] else { unread = 0; return }
            unread = items.reduce(0) { $0 + (($1["count"] as? Int) ?? 0) }
        } else {
            guard let json = TBNet.json("https://cloud.feedly.com/v3/markers/counts", headers: ["Authorization": "Bearer \(key)"]),
                  let items = (json as? [String: Any])?["unreadcounts"] as? [[String: Any]] else { unread = 0; return }
            unread = items.reduce(0) { $0 + (($1["count"] as? Int) ?? 0) }
        }
    }

    override func apply() {
        metric.value = "\(unread)"
        metric.subValue = configured ? localized("未读", "unread") : "mock"
        metric.valueColor = unread > 0 ? TB.textPrimary : TB.textSecondary
        metric.iconTint = configured ? TB.gold : TB.textTertiary
    }
}
