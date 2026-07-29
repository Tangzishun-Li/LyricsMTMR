//
//  SlackUnread.swift  ·  item type: slackUnread
//  Slack 未读/会话概览：在「设置 → 服务」填入 Slack Bot Token 后，调用 conversations.list
//  统计会话数并估算未读；未配置时显示内置 mock。属性：channels（关注的频道，逗号分隔，可空）、refreshInterval。
//

import Cocoa

class SlackUnreadItem: TBPollItem {
    private let channels: [String]
    private var value = "…"
    private var sub = ""
    private var tint = TB.purple

    init(identifier: NSTouchBarItem.Identifier, refreshInterval: Double, channels: String) {
        self.channels = channels.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "number.square.fill", tint: TB.purple,
                   label: "Slack", width: 140)
    }
    required init?(coder: NSCoder) { return nil }

    override func compute() {
        let token = SecretsManager.shared.retrieve(.slackBotToken)
        guard !token.isEmpty else {
            value = localized("未配置", "no token")
            sub = "mock · 3"
            tint = TB.textTertiary
            return
        }
        let url = "https://slack.com/api/conversations.list?exclude_archived=true&limit=200"
        guard let json = TBNet.json(url, headers: ["Authorization": "Bearer \(token)"]) as? [String: Any],
              (json["ok"] as? Bool) == true,
              let list = json["channels"] as? [[String: Any]] else {
            value = localized("请求失败", "api error")
            sub = ""
            tint = TB.coral
            return
        }
        let total = list.count
        let focused = channels.isEmpty ? total : list.filter { channels.contains(($0["name"] as? String) ?? "") }.count
        value = "\(focused)"
        sub = localized("共 \(total) 频道", "of \(total)")
        tint = TB.purple
    }

    override func apply() {
        metric.value = value
        metric.subValue = sub
        metric.valueColor = TB.textPrimary
        metric.iconTint = tint
    }
}
