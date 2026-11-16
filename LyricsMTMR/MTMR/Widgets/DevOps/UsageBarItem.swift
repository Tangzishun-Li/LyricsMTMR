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
    /// 计划板第 6 条：迁移后 items.json 只保留引用，密钥在凭据存储里。
    let apiKeyRef: String?

    private enum CodingKeys: String, CodingKey {
        case provider
        case apiKey = "api_key"
        case baseURL = "base_url"
        case apiKeyRef = "api_key_ref"
    }

    /// 显式 key 优先，其次按 `api_key_ref` 从凭据存储取。
    var resolvedAPIKey: String {
        if !apiKey.isEmpty { return apiKey }
        guard let ref = apiKeyRef, !ref.isEmpty else { return "" }
        return PresetCredentialStoreFactory.shared.retrieve(ref)
    }
}

struct LimitInfo {
    var title: String       // e.g. "5小时限额"
    var percentage: Double  // 0.0 - 1.0
    var resetInterval: TimeInterval // seconds until reset
    var resetAt: Date       // next reset timestamp
}

// MARK: - UsageProvider Protocol

protocol UsageProvider {
    var providerName: String { get }
    var icon: NSImage? { get }
    
    func fetchUsage(completion: @escaping (ProviderUsage?) -> Void)
}

// MARK: - Base Implementation

extension UsageProvider {
    var icon: NSImage? {
        return nil
    }
}

// MARK: - DeepSeek Provider

class DeepSeekUsageProvider: UsageProvider {
    let providerName = "deepseek"
    private let apiKey: String
    private let baseURL: String
    
    var icon: NSImage? {
        return NSImage(named: NSImage.Name("deepseek-icon"))
    }
    
    init(apiKey: String, baseURL: String?) {
        self.apiKey = apiKey.isEmpty ? SecretsManager.shared.retrieve(.deepseekAPIKey) : apiKey
        self.baseURL = baseURL ?? "https://api.deepseek.com"
    }
    
    func fetchUsage(completion: @escaping (ProviderUsage?) -> Void) {
        guard !apiKey.isEmpty else {
            completion(nil)
            return
        }
        
        let urlStr = "\(baseURL)/user/balance"
        guard let url = URL(string: urlStr) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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
                    provider: self.providerName,
                    fiveHourLimit: nil,
                    weeklyLimit: weeklyLimit,
                    icon: self.icon
                )
                completion(usage)
            } catch {
                completion(nil)
            }
        }.resume()
    }
}

// MARK: - OpenAI Compatible Provider

class OpenAICompatibleUsageProvider: UsageProvider {
    let providerName: String
    private let apiKey: String
    private let baseURL: String
    private let billingEndpoint: String
    
    var icon: NSImage? {
        return NSImage(named: NSImage.Name("openai-icon"))
    }
    
    init(providerName: String, apiKey: String, baseURL: String, billingEndpoint: String?) {
        self.providerName = providerName
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.billingEndpoint = billingEndpoint ?? "/v1/dashboard/billing/usage"
    }
    
    func fetchUsage(completion: @escaping (ProviderUsage?) -> Void) {
        guard !apiKey.isEmpty else {
            completion(nil)
            return
        }
        
        let urlStr = "\(baseURL)\(billingEndpoint)"
        guard let url = URL(string: urlStr) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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
                
                // OpenAI 兼容格式：total_usage, hard_limit_usd
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
                    provider: self.providerName,
                    fiveHourLimit: nil,
                    weeklyLimit: weeklyLimit,
                    icon: self.icon
                )
                completion(usage)
            } catch {
                completion(nil)
            }
        }.resume()
    }
}

// MARK: - Longcat Provider (OpenAI Compatible)

class LongcatUsageProvider: OpenAICompatibleUsageProvider {
    override var icon: NSImage? {
        return NSImage(named: NSImage.Name("longcat-icon"))
    }
    
    init(apiKey: String, baseURL: String?) {
        super.init(
            providerName: "longcat",
            apiKey: apiKey,
            baseURL: baseURL ?? "https://api.longcat.chat",
            billingEndpoint: "/v1/dashboard/billing/usage"
        )
    }
}

// MARK: - Bailian Provider (阿里云 DashScope)

class BailianUsageProvider: UsageProvider {
    let providerName = "bailian"
    private let apiKey: String
    private let baseURL: String
    
    var icon: NSImage? {
        return NSImage(named: NSImage.Name("bailian-icon"))
    }
    
    init(apiKey: String, baseURL: String?) {
        self.apiKey = apiKey
        self.baseURL = baseURL ?? "https://dashscope.aliyuncs.com"
    }
    
    func fetchUsage(completion: @escaping (ProviderUsage?) -> Void) {
        guard !apiKey.isEmpty else {
            completion(nil)
            return
        }
        
        let urlStr = "\(baseURL)/api/v1/runners/quota"
        guard let url = URL(string: urlStr) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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
                    provider: self.providerName,
                    fiveHourLimit: nil,
                    weeklyLimit: weeklyLimit,
                    icon: self.icon
                )
                completion(usage)
            } catch {
                completion(nil)
            }
        }.resume()
    }
}

// MARK: - MIMO Provider (假设兼容 OpenAI)

class MIMOUsageProvider: OpenAICompatibleUsageProvider {
    override var icon: NSImage? {
        return NSImage(named: NSImage.Name("mimo-icon"))
    }
    
    init(apiKey: String, baseURL: String?) {
        super.init(
            providerName: "mimo",
            apiKey: apiKey,
            baseURL: baseURL ?? "https://api.mimo.ai",
            billingEndpoint: "/v1/dashboard/billing/usage"
        )
    }
}

// MARK: - Provider Factory

class UsageProviderFactory {
    static func createProvider(from config: ProviderConfig) -> UsageProvider? {
        switch config.provider.lowercased() {
        case "deepseek":
            return DeepSeekUsageProvider(apiKey: config.resolvedAPIKey, baseURL: config.baseURL)
        case "longcat":
            return LongcatUsageProvider(apiKey: config.resolvedAPIKey, baseURL: config.baseURL)
        case "bailian":
            return BailianUsageProvider(apiKey: config.resolvedAPIKey, baseURL: config.baseURL)
        case "mimo":
            return MIMOUsageProvider(apiKey: config.resolvedAPIKey, baseURL: config.baseURL)
        case "openai", "openai-compat":
            // 通用 OpenAI 兼容提供商
            return OpenAICompatibleUsageProvider(
                providerName: config.provider,
                apiKey: config.resolvedAPIKey,
                baseURL: config.baseURL ?? "https://api.openai.com",
                billingEndpoint: "/v1/dashboard/billing/usage"
            )
        default:
            // 尝试作为 OpenAI 兼容提供商处理
            if let baseURL = config.baseURL, !baseURL.isEmpty {
                return OpenAICompatibleUsageProvider(
                    providerName: config.provider,
                    apiKey: config.resolvedAPIKey,
                    baseURL: baseURL,
                    billingEndpoint: "/v1/dashboard/billing/usage"
                )
            }
            return nil
        }
    }
}

struct ProviderUsage {
    let provider: String
    let fiveHourLimit: LimitInfo?
    let weeklyLimit: LimitInfo?
    let icon: NSImage?
}

// MARK: - UsageBarItem

class UsageBarItem: CustomButtonTouchBarItem, TBPollPausable {
    private let providers: [ProviderConfig]
    private let refreshInterval: TimeInterval
    private let displayMode: String   // "compact" | "expanded"
    private let widgetWidth: CGFloat

    private var usageData: [ProviderUsage] = []
    private var currentProviderIndex: Int = 0
    private var isExpanded: Bool = false
    /// 用量刷新定时器（round 19：隐藏期间整体暂停，恢复后立即刷新一次避免陈旧显示）。
    private lazy var pausableTimer = TBPausableTimer(interval: refreshInterval, tolerance: refreshInterval * 0.1, immediateFireOnResume: true) { [weak self] in
        self?.refreshData()
    }

    private static let providerIcons: [String: String] = [
        "deepseek": "deepseek-icon",
        "longcat": "longcat-icon",
        "bailian": "bailian-icon",
        "mimo": "mimo-icon",
        "openai": "openai-icon",
        "openai-compat": "openai-icon"
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
        pausableTimer.start()
    }

    required init?(coder _: NSCoder) { return nil }

    /// 隐藏（黑名单/exitTouchbar）时暂停用量轮询；显示时恢复。
    func setPaused(_ paused: Bool) {
        pausableTimer.setPaused(paused)
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
            guard let self = self, !self.pausableTimer.isPaused else { return }
            self.usageData = fetched
            self.updateDisplay()
        }
    }

    private func fetchUsage(for config: ProviderConfig, completion: @escaping (ProviderUsage?) -> Void) {
        guard let provider = UsageProviderFactory.createProvider(from: config) else {
            completion(nil)
            return
        }
        
        provider.fetchUsage { usage in
            completion(usage)
        }
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
        if let providerIcon = usage.icon {
            providerIcon.size = NSSize(width: 16, height: 16)
            image = providerIcon
        } else if let iconName = UsageBarItem.providerIcons[usage.provider],
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
