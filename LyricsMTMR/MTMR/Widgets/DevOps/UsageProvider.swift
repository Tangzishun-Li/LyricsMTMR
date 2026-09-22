//
//  UsageProvider.swift
//  LyricsMTMR
//
//  Protocol for AI service usage providers.
//

import Cocoa
import Foundation

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
                    provider: providerName,
                    fiveHourLimit: nil,
                    weeklyLimit: weeklyLimit,
                    icon: icon
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
                    provider: providerName,
                    fiveHourLimit: nil,
                    weeklyLimit: weeklyLimit,
                    icon: icon
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
                    provider: providerName,
                    fiveHourLimit: nil,
                    weeklyLimit: weeklyLimit,
                    icon: icon
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
            return DeepSeekUsageProvider(apiKey: config.apiKey, baseURL: config.baseURL)
        case "longcat":
            return LongcatUsageProvider(apiKey: config.apiKey, baseURL: config.baseURL)
        case "bailian":
            return BailianUsageProvider(apiKey: config.apiKey, baseURL: config.baseURL)
        case "mimo":
            return MIMOUsageProvider(apiKey: config.apiKey, baseURL: config.baseURL)
        case "openai", "openai-compat":
            // 通用 OpenAI 兼容提供商
            return OpenAICompatibleUsageProvider(
                providerName: config.provider,
                apiKey: config.apiKey,
                baseURL: config.baseURL ?? "https://api.openai.com",
                billingEndpoint: "/v1/dashboard/billing/usage"
            )
        default:
            // 尝试作为 OpenAI 兼容提供商处理
            if let baseURL = config.baseURL, !baseURL.isEmpty {
                return OpenAICompatibleUsageProvider(
                    providerName: config.provider,
                    apiKey: config.apiKey,
                    baseURL: baseURL,
                    billingEndpoint: "/v1/dashboard/billing/usage"
                )
            }
            return nil
        }
    }
}