//
//  BilibiliFeed.swift  ·  item type: bilibiliFeed
//  B 站增强：显示关注 UP 主最新视频/未读动态数。
//  Cookie 存 SecretsManager（.bilibiliCookie），无 Cookie 时显示未配置。
//  属性：refreshInterval。
//

import Cocoa

class BilibiliFeedItem: TBPollItem {
    private var unreadCount = 0
    private var configured = true
    private var latestTitle = ""
    /// Round 45: fetch failure flips this; apply() shows a failure state
    /// instead of a misleading "0" — "no new dynamics" must not be
    /// indistinguishable from "network dead".
    private var fetchFailed = false

    init(identifier: NSTouchBarItem.Identifier, refreshInterval: Double) {
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "play.tv", tint: TB.sky,
                   label: "B站", width: 128)
    }
    required init?(coder: NSCoder) { return nil }

    override func compute() {
        fetchFailed = false
        let cookie = SecretsManager.shared.retrieve(.bilibiliCookie)
        guard !cookie.isEmpty else {
            configured = false
            unreadCount = 0
            latestTitle = ""
            return
        }
        configured = true

        let headers = [
            "Cookie": cookie,
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            "Referer": "https://www.bilibili.com",
        ]

        // Fetch dynamic feed (followed UP hosts)
        guard let json = TBNet.json("https://api.bilibili.com/x/polymer/web-dynamic/v1/feed/all?type=all&page=1", headers: headers) as? [String: Any],
              let data = json["data"] as? [String: Any],
              let items = data["items"] as? [[String: Any]] else {
            fetchFailed = true
            latestTitle = localized("加载失败", "load failed")
            return
        }

        unreadCount = items.count
        if let first = items.first {
            let modules = first["modules"] as? [String: Any]
            let author = (modules?["module_author"] as? [String: Any])?["name"] as? String ?? ""
            let dynamic = modules?["module_dynamic"] as? [String: Any]
            let major = dynamic?["major"] as? [String: Any]
            let archive = major?["archive"] as? [String: Any]
            let title = archive?["title"] as? String ?? localized("新动态", "new")
            latestTitle = author.isEmpty ? title : "\(author): \(title)"
        }
    }

    override func apply() {
        if !configured {
            metric.value = localized("未配置", "N/A")
            metric.subValue = "Cookie"
            metric.valueColor = TB.textTertiary
            metric.iconTint = TB.textTertiary
            return
        }
        // Failure state before the count: a dead network must look dead, not 0.
        if fetchFailed {
            metric.value = "—"
            metric.subValue = latestTitle
            metric.valueColor = TB.coral
            metric.iconTint = TB.coral
            return
        }
        metric.value = "\(unreadCount)"
        metric.subValue = latestTitle.count > 12 ? String(latestTitle.prefix(12)) + "…" : latestTitle
        metric.valueColor = unreadCount > 0 ? TB.textPrimary : TB.textSecondary
        metric.iconTint = TB.sky
    }
}
