//
//  RssUnread.swift  ·  item type: rssUnread
//
//  RSS 未读数角标。支持两种获取方式（在「设置 → RSS」里切换）：
//
//    1. provider — 通过聚合服务 API 读取未读数。
//       支持 Feedly / Inoreader（云端），以及 Miniflux / FreshRSS / BazQux /
//       The Old Reader（自建或商用，走各自 API 或 Google Reader 兼容接口）。
//    2. direct — 不依赖任何账号，直接抓取用户填写的 feed URL，
//       解析 RSS 2.0 / Atom，统计「未读窗口」内（默认 24h）的新条目。
//
//  属性：provider（可空 = 用设置里的提供商）、refreshInterval。
//

import Cocoa
import Foundation

class RssUnreadItem: TBPollItem {
    private let provider: String
    private var unread = 0
    private var configured = true
    private var mode = "provider"
    /// Round 44: any fetch failure (direct feed / provider API) flips this,
    /// and apply() shows a failure state instead of a misleading "0" —
    /// "all read" must not be indistinguishable from "network dead".
    private var fetchFailed = false

    init(identifier: NSTouchBarItem.Identifier, provider: String, refreshInterval: Double) {
        self.provider = provider
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "dot.radiowaves.left.and.right", tint: TB.gold,
                   label: "RSS", width: 128)
    }
    required init?(coder: NSCoder) { return nil }

    override func compute() {
        fetchFailed = false
        mode = AppSettings.rssMode
        if mode == "direct" {
            computeDirect()
        } else {
            computeProvider()
        }
    }

    // MARK: - Direct fetch

    private func computeDirect() {
        let feeds = AppSettings.rssFeeds
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !feeds.isEmpty else {
            configured = false
            unread = 0
            return
        }
        configured = true
        let window = AppSettings.rssUnreadWindowHours
        // Round 46: parallel fan-out. The serial loop (≤ round 45) fetched
        // feeds one after another on the widget's own polling queue — N dead
        // feeds stretched a single cycle by N × (timeout+1s) and froze the
        // badge for that whole time. Dispatching all fetches concurrently
        // bounds the cycle by the slowest single feed instead of the sum.
        // Each fetch keeps its own hard bound (TBNet timeout+1s), so the
        // group wait below can never exceed ~11s at the 10s direct timeout.
        // Failure semantics unchanged: any dead feed still invalidates the
        // badge (fetchFailed = true); a full success sums all counts.
        let group = DispatchGroup()
        let lock = NSLock()
        var total = 0
        var anyFailed = false
        for feed in feeds {
            group.enter()
            DispatchQueue.global().async {
                let count = RSSDirectCounter.unreadCount(feedURL: feed, windowHours: window)
                lock.lock()
                if let count = count {
                    total += count
                } else {
                    anyFailed = true
                }
                lock.unlock()
                group.leave()
            }
        }
        // Safety net: each feed's own bound guarantees the group completes
        // well inside 30s; this only guards against a future regression
        // that removes the per-fetch timeout.
        _ = group.wait(timeout: .now() + 30)
        lock.lock()
        let failed = anyFailed
        let sum = total
        lock.unlock()
        if failed {
            fetchFailed = true
            unread = 0
        } else {
            unread = sum
        }
    }

    // MARK: - Provider fetch

    private func computeProvider() {
        let useProvider = provider.isEmpty ? AppSettings.rssProvider : provider
        let key = SecretsManager.shared.retrieve(.rssAPIKey)
        guard !key.isEmpty else {
            configured = false
            unread = 12   // mock，便于无 Key 环境预览
            return
        }
        configured = true
        let server = AppSettings.rssServerURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if let count = RSSProviderClient.unreadCount(provider: useProvider, token: key, server: server) {
            unread = count
        } else {
            fetchFailed = true
        }
    }

    override func apply() {
        // Failure state first: a dead network must look dead, not "0 unread".
        if fetchFailed {
            metric.value = "—"
            metric.subValue = localized("获取失败", "offline")
            metric.valueColor = TB.coral
            metric.iconTint = TB.coral
            return
        }
        // Optionally collapse the badge when everything is read.
        if configured && unread == 0 && !AppSettings.rssShowBadge {
            metric.value = ""
            metric.subValue = nil
            metric.valueColor = TB.textSecondary
            metric.iconTint = TB.textTertiary
            return
        }
        metric.value = "\(unread)"
        metric.subValue = configured
            ? localized("未读", "unread")
            : (mode == "direct" ? localized("未配置", "not set") : "mock")
        metric.valueColor = unread > 0 ? TB.textPrimary : TB.textSecondary
        metric.iconTint = configured ? TB.gold : TB.textTertiary
    }
}

// MARK: - Provider clients

/// Talks to the various aggregator / self-hosted reader APIs and returns a
/// total unread count. Round 44: returns nil on any fetch/shape failure so
/// the widget can show a failure state instead of a misleading "0" ("all
/// read" must not be indistinguishable from "network dead").
enum RSSProviderClient {

    static func unreadCount(provider: String, token: String, server: String) -> Int? {
        let p = provider.lowercased()
        if p.contains("inoreader") {
            return inoreader(token: token)
        } else if p.contains("miniflux") {
            return miniflux(token: token, server: server)
        } else if p.contains("freshrss") || p.contains("bazqux")
                    || p.contains("oldreader") || p.contains("greader") {
            return googleReader(token: token, server: server)
        } else {
            return feedly(token: token)
        }
    }

    // Feedly cloud — sum of all unreadcounts.
    private static func feedly(token: String) -> Int? {
        guard let json = TBNet.json("https://cloud.feedly.com/v3/markers/counts",
                                    headers: ["Authorization": "Bearer \(token)"]),
              let items = (json as? [String: Any])?["unreadcounts"] as? [[String: Any]] else { return nil }
        return items.reduce(0) { $0 + (($1["count"] as? Int) ?? 0) }
    }

    // Inoreader — sum of all unreadcounts.
    private static func inoreader(token: String) -> Int? {
        guard let json = TBNet.json("https://api.inoreader.com/api/0/unread-count",
                                    headers: ["Authorization": "Bearer \(token)"]),
              let items = (json as? [String: Any])?["unreadcounts"] as? [[String: Any]] else { return nil }
        return items.reduce(0) { $0 + (($1["count"] as? Int) ?? 0) }
    }

    // Miniflux (self-hosted) — /v1/entries?status=unread returns a "total".
    private static func miniflux(token: String, server: String) -> Int? {
        let base = normalized(server, fallback: "http://localhost:8080")
        guard let json = TBNet.json("\(base)/v1/entries?status=unread&limit=1",
                                    headers: ["X-Auth-Token": token]) as? [String: Any],
              let total = json["total"] as? Int else { return nil }
        return total
    }

    // Google Reader compatible API — used by FreshRSS, BazQux, The Old Reader.
    // Server should be the API root, e.g. "https://rss.example.com/api/greader.php"
    // for FreshRSS, "https://www.bazqux.com" for BazQux, "https://theoldreader.com"
    // for The Old Reader.
    private static func googleReader(token: String, server: String) -> Int? {
        let base = normalized(server, fallback: "https://theoldreader.com")
        guard let json = TBNet.json("\(base)/reader/api/0/unread-count?output=json",
                                    headers: ["Authorization": "GoogleLogin auth=\(token)"]),
              let items = (json as? [String: Any])?["unreadcounts"] as? [[String: Any]] else { return nil }
        // Only count real feeds (ids look like "feed/..."), skip label/category rows.
        return items.reduce(0) { sum, entry in
            let id = (entry["id"] as? String) ?? ""
            guard id.hasPrefix("feed/") else { return sum }
            return sum + ((entry["count"] as? Int) ?? 0)
        }
    }

    private static func normalized(_ server: String, fallback: String) -> String {
        var s = server.isEmpty ? fallback : server
        while s.hasSuffix("/") { s.removeLast() }
        return s
    }
}

// MARK: - Direct feed counter

/// Parses a single RSS 2.0 / Atom feed and counts items newer than a cutoff.
/// Used in "direct" mode so no account or third-party service is required.
final class RSSDirectCounter: NSObject, XMLParserDelegate {

    private static let perFeedCap = 999

    private let cutoff: Date
    private var count = 0
    private var inItem = false
    private var currentItemDate: Date?
    private var capturingDate = false
    private var dateBuffer = ""

    private static let dateTags: Set<String> = ["pubdate", "published", "updated", "dc:date", "date"]

    private init(windowHours: Double) {
        self.cutoff = Date().addingTimeInterval(-max(0, windowHours) * 3600)
    }

    static func unreadCount(feedURL: String, windowHours: Double) -> Int? {
        // Round 44: nil = fetch failed (distinct from a legitimately empty
        // feed, which returns 0) so the widget can show a failure state.
        guard let data = TBNet.get(feedURL, timeout: 10) else { return nil }
        let delegate = RSSDirectCounter(windowHours: windowHours)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return min(delegate.count, perFeedCap)
    }

    // MARK: XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        let name = elementName.lowercased()
        if name == "item" || name == "entry" {
            inItem = true
            currentItemDate = nil
        } else if inItem && Self.dateTags.contains(name) {
            capturingDate = true
            dateBuffer = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if capturingDate { dateBuffer += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        let name = elementName.lowercased()
        if capturingDate && Self.dateTags.contains(name) {
            capturingDate = false
            currentItemDate = Self.parseDate(dateBuffer)
        } else if name == "item" || name == "entry" {
            if inItem {
                // No date info → treat as recent so it still surfaces.
                if let d = currentItemDate {
                    if d >= cutoff { count += 1 }
                } else {
                    count += 1
                }
            }
            inItem = false
        }
    }

    // MARK: Date parsing

    private static let formatters: [DateFormatter] = {
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm:ss zzz",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd HH:mm:ss",
        ]
        return formats.map {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = $0
            return df
        }
    }()

    private static func parseDate(_ raw: String) -> Date? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        for f in formatters {
            if let d = f.date(from: s) { return d }
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: s) { return d }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: s)
    }
}
