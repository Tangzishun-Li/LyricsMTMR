//
//  UsageBarItem.swift
//  LyricsMTMR
//
//  Usage monitor for AI service providers (DeepSeek, Longcat, 百炼平台).
//

import Cocoa
import Foundation

// MARK: - Data Models

struct ProviderConfig: Decodable {
    let provider: String   // "deepseek" | "longcat" | "bailian"
    let apiKey: String
    let baseURL: String?   // optional, for custom endpoints

    private enum CodingKeys: String, CodingKey {
        case provider
        case apiKey = "api_key"
        case baseURL = "base_url"
    }
}

struct LimitInfo {
    var title: String       // e.g. "5小时限额"
    var percentage: Double  // 0.0 - 1.0
    var resetInterval: TimeInterval // seconds until reset
    var resetAt: Date       // next reset timestamp
}

struct ProviderUsage {
    let provider: String
    let fiveHourLimit: LimitInfo?
    let weeklyLimit: LimitInfo?
    let icon: NSImage?
}

// MARK: - UsageBarItem

class UsageBarItem: CustomButtonTouchBarItem {
    private let providers: [ProviderConfig]
    private let refreshInterval: TimeInterval
    private let displayMode: String   // "compact" | "expanded"
    private let widgetWidth: CGFloat

    private var usageData: [ProviderUsage] = []
    private var currentProviderIndex: Int = 0
    private var isExpanded: Bool = false
    private var refreshTimer: Timer?

    private static let providerIcons: [String: String] = [
        "deepseek": "deepseek-icon",
        "longcat": "longcat-icon",
        "bailian": "bailian-icon"
    ]

    init(identifier: NSTouchBarItem.Identifier, providers: [ProviderConfig], interval: TimeInterval, displayMode: String, widgetWidth: CGFloat) {
        self.providers = providers
        self.refreshInterval = max(interval, 60)
        self.displayMode = displayMode
        self.widgetWidth = widgetWidth

        super.init(identifier: identifier, title: " ")

        isBordered = false
        setWidth(value: widgetWidth)

        actions.append(ItemAction(trigger: .singleTap) { [weak self] in
            self?.toggleExpansion()
        })

        refreshData()
        scheduleRefresh()
    }

    required init?(coder _: NSCoder) { return nil }

    deinit {
        refreshTimer?.invalidate()
    }

    // MARK: - Timer

    private func scheduleRefresh() {
        DispatchQueue.main.async { [weak self] in
            self?.refreshTimer?.invalidate()
            self?.refreshTimer = Timer.scheduledTimer(withTimeInterval: self?.refreshInterval ?? 300, repeats: true) { [weak self] _ in
                self?.refreshData()
            }
        }
    }

    // MARK: - Data Fetching

    private func refreshData() {
        guard !providers.isEmpty else {
            title = "未配置用量"
            return
        }

        let group = DispatchGroup()
        var fetched: [ProviderUsage] = []

        for config in providers {
            group.enter()
            fetchUsage(for: config) { usage in
                if let usage = usage {
                    fetched.append(usage)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.usageData = fetched
            self.updateDisplay()
        }
    }

    private func fetchUsage(for config: ProviderConfig, completion: @escaping (ProviderUsage?) -> Void) {
        switch config.provider.lowercased() {
        case "deepseek":
            fetchDeepSeekUsage(config: config, completion: completion)
        case "longcat":
            fetchLongcatUsage(config: config, completion: completion)
        case "bailian":
            fetchBailianUsage(config: config, completion: completion)
        default:
            completion(nil)
        }
    }

    // MARK: - DeepSeek API

    private func fetchDeepSeekUsage(config: ProviderConfig, completion: @escaping (ProviderUsage?) -> Void) {
        let base = config.baseURL ?? "https://api.deepseek.com"
        let urlStr = "\(base)/user/balance"
        guard let url = URL(string: urlStr) else {
            completion(nil)
            return
        }

        // JSON 配置优先；留空则回退到「设置 → 服务」中填写的 key
        let resolvedKey = config.apiKey.isEmpty ? SecretsManager.shared.retrieve(.deepseekAPIKey) : config.apiKey
        guard !resolvedKey.isEmpty else { completion(nil); return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(resolvedKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }

            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let balanceInfoList = json["balance_infos"] as? [[String: Any]] else {
                    completion(nil)
                    return
                }

                // DeepSeek 提供总额度信息，但无 5h/周限额
                // 用总额度作为周限额显示，5h 限额不适用
                var totalBalance: Double = 0
                var totalTotal: Double = 0

                for info in balanceInfoList {
                    if let balance = info["total_balance"] as? String, let b = Double(balance) {
                        totalBalance += b
                    }
                    if let total = info["total_amount"] as? String, let t = Double(total) {
                        totalTotal += t
                    } else if let total = info["total_amount"] as? Double {
                        totalTotal += total
                    }
                }

                let percentage = totalTotal > 0 ? min(totalBalance / totalTotal, 1.0) : 0

                let weeklyLimit = LimitInfo(
                    title: "总额度",
                    percentage: percentage,
                    resetInterval: 7 * 24 * 3600,
                    resetAt: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
                )

                let usage = ProviderUsage(
                    provider: config.provider,
                    fiveHourLimit: nil,
                    weeklyLimit: weeklyLimit,
                    icon: nil
                )
                completion(usage)
            } catch {
                completion(nil)
            }
        }.resume()
    }

    // MARK: - Longcat API

    private func fetchLongcatUsage(config: ProviderConfig, completion: @escaping (ProviderUsage?) -> Void) {
        let base = config.baseURL ?? "https://api.longcat.chat"
        let urlStr = "\(base)/v1/dashboard/billing/usage"
        guard let url = URL(string: urlStr) else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }

            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    completion(nil)
                    return
                }

                // Longcat 兼容 OpenAI 风格的用量接口
                let totalUsed = (json["total_usage"] as? Double) ?? 0
                let totalLimit = (json["hard_limit_usd"] as? Double) ?? 0
                let percentage = totalLimit > 0 ? min(totalUsed / totalLimit, 1.0) : 0

                let weeklyLimit = LimitInfo(
                    title: "周限额",
                    percentage: percentage,
                    resetInterval: 7 * 24 * 3600,
                    resetAt: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
                )

                let usage = ProviderUsage(
                    provider: config.provider,
                    fiveHourLimit: nil,
                    weeklyLimit: weeklyLimit,
                    icon: nil
                )
                completion(usage)
            } catch {
                completion(nil)
            }
        }.resume()
    }

    // MARK: - 百炼平台 API

    private func fetchBailianUsage(config: ProviderConfig, completion: @escaping (ProviderUsage?) -> Void) {
        // 百炼平台用量 API (阿里云 DashScope)
        let base = config.baseURL ?? "https://dashscope.aliyuncs.com"
        let urlStr = "\(base)/api/v1/runners/quota"
        guard let url = URL(string: urlStr) else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }

            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let dataDict = json["data"] as? [String: Any] else {
                    completion(nil)
                    return
                }

                // 百炼平台 token plan 限额
                let used = (dataDict["used"] as? Double) ?? 0
                let total = (dataDict["total"] as? Double) ?? 0
                let percentage = total > 0 ? min(used / total, 1.0) : 0

                let weeklyLimit = LimitInfo(
                    title: "周限额",
                    percentage: percentage,
                    resetInterval: 7 * 24 * 3600,
                    resetAt: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
                )

                let usage = ProviderUsage(
                    provider: config.provider,
                    fiveHourLimit: nil,
                    weeklyLimit: weeklyLimit,
                    icon: nil
                )
                completion(usage)
            } catch {
                completion(nil)
            }
        }.resume()
    }

    // MARK: - Display

    private func toggleExpansion() {
        isExpanded.toggle()
        // 切换宽度：compact -> expanded
        let newWidth: CGFloat = isExpanded ? widgetWidth * 1.8 : widgetWidth
        setWidth(value: newWidth)
        updateDisplay()
    }

    private func updateDisplay() {
        guard !usageData.isEmpty, currentProviderIndex < usageData.count else {
            title = "用量"
            image = nil
            return
        }

        let usage = usageData[currentProviderIndex]

        if isExpanded {
            renderExpanded(usage: usage)
        } else {
            renderCompact(usage: usage)
        }
    }

    private func renderCompact(usage: ProviderUsage) {
        // 紧凑模式：显示图标 + 限额文字 + 百分数
        let weekly = usage.weeklyLimit

        let pctStr: String
        if let w = weekly {
            pctStr = String(format: "%.0f%%", w.percentage * 100)
        } else {
            pctStr = "--"
        }

        // 构建富文本
        let text = NSMutableAttributedString()

        // 百分数
        let pctAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: NSFont.systemFont(ofSize: 14, weight: .medium)
        ]
        text.append(NSAttributedString(string: pctStr, attributes: pctAttrs))

        // 周限额标题
        if let w = weekly {
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.systemGray,
                .font: NSFont.systemFont(ofSize: 9)
            ]
            text.append(NSAttributedString(string: "\n\(w.title)", attributes: titleAttrs))
        }

        text.setAlignment(.center, range: NSRange(location: 0, length: text.length))

        attributedTitle = text

        // 左侧图标
        if let iconName = UsageBarItem.providerIcons[usage.provider],
           let iconImage = NSImage(named: NSImage.Name(iconName)) {
            iconImage.size = NSSize(width: 16, height: 16)
            image = iconImage
        } else {
            image = nil
        }
        attributedTitle = text
    }

    private func renderExpanded(usage: ProviderUsage) {
        // 展开模式：5小时限额和7天限额并排显示，附带刷新时间
        let fiveH = usage.fiveHourLimit
        let weekly = usage.weeklyLimit

        let text = NSMutableAttributedString()

        // 5小时限额
        if let fh = fiveH {
            text.append(formatLimit(title: fh.title, percentage: fh.percentage, resetAt: fh.resetAt))
            text.append(NSAttributedString(string: "  "))
        }

        // 7天限额
        if let w = weekly {
            text.append(formatLimit(title: w.title, percentage: w.percentage, resetAt: w.resetAt))
        }

        text.setAlignment(.center, range: NSRange(location: 0, length: text.length))
        attributedTitle = text
    }

    private func formatLimit(title: String, percentage: Double, resetAt: Date) -> NSAttributedString {
        let result = NSMutableAttributedString()

        // 标题
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: NSFont.systemFont(ofSize: 11, weight: .medium)
        ]
        result.append(NSAttributedString(string: "\(title)\n", attributes: titleAttrs))

        // 百分数
        let pctAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: percentage > 0.8 ? NSColor.systemOrange : NSColor.systemGreen,
            .font: NSFont.systemFont(ofSize: 13, weight: .bold)
        ]
        result.append(NSAttributedString(string: String(format: "%.0f%%", percentage * 100), attributes: pctAttrs))

        // 刷新时间
        let timeRemaining = resetAt.timeIntervalSince(Date())
        let timeStr = formatTimeRemaining(timeRemaining)
        let timeAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.systemGray,
            .font: NSFont.systemFont(ofSize: 9)
        ]
        result.append(NSAttributedString(string: "\n\(timeStr)", attributes: timeAttrs))

        return result
    }

    private func formatTimeRemaining(_ interval: TimeInterval) -> String {
        if interval <= 0 {
            return "即将刷新"
        }
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours >= 24 {
            let days = hours / 24
            return "\(days)d\(hours % 24)h 后刷新"
        } else if hours > 0 {
            return "\(hours)h\(minutes)m 后刷新"
        } else {
            return "\(minutes)m 后刷新"
        }
    }
}
