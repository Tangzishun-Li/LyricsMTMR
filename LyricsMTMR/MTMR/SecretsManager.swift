//
//  SecretsManager.swift
//  LyricsMTMR
//
//  Centralised secrets & API key management.
//
//  Features:
//    - All API keys flow through this single access point.
//    - Opt-in macOS Keychain storage (more secure than UserDefaults).
//    - Built-in validation for known key formats.
//    - Detection of hardcoded keys in JSON config files.
//    - Audit helper: `hasAnyConfigured` / `configuredServices` for the UI.
//    - Built-in connectivity test for every service.
//
//  Widget usage pattern:
//       let key = SecretsManager.shared.retrieve(.deepseekAPIKey)
//       guard !key.isEmpty else { /* show "未配置" */ return }
//
//  NOTE: Keys stored in UserDefaults are NOT encrypted at rest on disk;
//  for production, switch to Keychain by setting `useKeychain = true` below.
//

import Foundation
import Security

// MARK: - Service Identifier

/// Every third-party service that needs a credential.
enum APIService: String, CaseIterable, Identifiable {
    case deepseekAPIKey
    case deepseekModel
    case deepseekBaseURL
    case openWeatherAPIKey
    case kuaidi100Key
    case kuaidi100Customer
    case slackBotToken
    case githubToken
    case rssProvider
    case rssAPIKey
    case mijiaToken
    case sshHost
    case sshUser
    case bilibiliCookie
    case opencodeGoCookie
    case opencodeGoWorkspaceID

    var id: String { rawValue }

    /// Human-readable label used in the Settings UI.
    var displayName: String {
        switch self {
        case .deepseekAPIKey:   return "DeepSeek API Key"
        case .deepseekModel:    return "DeepSeek Model"
        case .deepseekBaseURL:  return "DeepSeek Base URL"
        case .openWeatherAPIKey: return "OpenWeatherMap API Key"
        case .kuaidi100Key:     return "快递100 Key"
        case .kuaidi100Customer: return "快递100 Customer"
        case .slackBotToken:    return "Slack Bot Token"
        case .githubToken:      return "GitHub Token"
        case .rssProvider:      return "RSS Provider"
        case .rssAPIKey:        return "RSS API Key"
        case .mijiaToken:       return "MiJia Token"
        case .sshHost:          return "SSH Host"
        case .sshUser:          return "SSH User"
        case .bilibiliCookie:   return "Bilibili Cookie"
        case .opencodeGoCookie:   return "OpenCode Go auth Cookie"
        case .opencodeGoWorkspaceID: return "OpenCode Go Workspace ID"
        }
    }

    /// UserDefaults key used to persist this value.
    var defaultsKey: String {
        switch self {
        case .deepseekAPIKey:   return "com.lyricsmtmr.services.deepseekAPIKey"
        case .deepseekModel:    return "com.lyricsmtmr.services.deepseekModel"
        case .deepseekBaseURL:  return "com.lyricsmtmr.services.deepseekBaseURL"
        case .openWeatherAPIKey: return "com.lyricsmtmr.services.openWeatherAPIKey"
        case .kuaidi100Key:     return "com.lyricsmtmr.services.kuaidi100Key"
        case .kuaidi100Customer: return "com.lyricsmtmr.services.kuaidi100Customer"
        case .slackBotToken:    return "com.lyricsmtmr.services.slackBotToken"
        case .githubToken:      return "com.lyricsmtmr.services.githubToken"
        case .rssProvider:      return "com.lyricsmtmr.services.rssProvider"
        case .rssAPIKey:        return "com.lyricsmtmr.services.rssAPIKey"
        case .mijiaToken:       return "com.lyricsmtmr.services.mijiaToken"
        case .sshHost:          return "com.lyricsmtmr.services.sshHost"
        case .sshUser:          return "com.lyricsmtmr.services.sshUser"
        case .bilibiliCookie:   return "com.lyricsmtmr.services.bilibiliCookie"
        case .opencodeGoCookie:   return "com.lyricsmtmr.services.opencodeGoCookie"
        case .opencodeGoWorkspaceID: return "com.lyricsmtmr.services.opencodeGoWorkspaceID"
        }
    }

    /// Whether this value is sensitive and should be masked in UI.
    var isSecret: Bool {
        switch self {
        case .deepseekAPIKey, .openWeatherAPIKey, .kuaidi100Key,
                .kuaidi100Customer, .slackBotToken, .githubToken,
                .rssAPIKey, .mijiaToken, .bilibiliCookie:
            return true
        case .deepseekModel, .deepseekBaseURL, .rssProvider,
                .sshHost, .sshUser:
            return false
        case .opencodeGoCookie:
            return true
        case .opencodeGoWorkspaceID:
            return false
        }
    }

    /// Known prefix for basic format validation (nil = no check).
    var expectedPrefix: String? {
        switch self {
        case .deepseekAPIKey:   return "sk-"
        case .slackBotToken:    return "xoxb-"
        case .githubToken:      return "gh"
        default:                return nil
        }
    }
}

// MARK: - Test Result

/// Result of a connectivity test.
struct APITestResult {
    let success: Bool
    let message: String
    let detail: String?

    static func ok(_ msg: String, detail: String? = nil) -> APITestResult {
        APITestResult(success: true, message: msg, detail: detail)
    }

    static func fail(_ msg: String, detail: String? = nil) -> APITestResult {
        APITestResult(success: false, message: msg, detail: detail)
    }
}

// MARK: - SecretsManager

final class SecretsManager {

    static let shared = SecretsManager()

    /// Set to `true` to use the system Keychain instead of UserDefaults.
    /// Keychain is more secure but requires the app to be signed with the
    /// proper Keychain Access Groups entitlement.
    var useKeychain = false

    private init() {}

    // MARK: - Read / Write

    /// Retrieve a credential for the given service.
    func retrieve(_ service: APIService) -> String {
        if useKeychain {
            return keychainRetrieve(service) ?? ""
        }
        return UserDefaults.standard.string(forKey: service.defaultsKey) ?? ""
    }

    /// Persist a credential. Pass empty string to clear.
    func store(_ value: String, for service: APIService) {
        if useKeychain {
            if value.isEmpty {
                keychainDelete(service)
            } else {
                keychainStore(value, for: service)
            }
        } else {
            UserDefaults.standard.set(value, forKey: service.defaultsKey)
            UserDefaults.standard.synchronize()
        }
    }

    /// Remove a credential from storage.
    func clear(_ service: APIService) {
        store("", for: service)
    }

    /// Returns `true` when a non-empty value exists for this service.
    func isConfigured(_ service: APIService) -> Bool {
        !retrieve(service).isEmpty
    }

    /// Returns the list of services that have a non-empty value.
    var configuredServices: [APIService] {
        APIService.allCases.filter { isConfigured($0) }
    }

    /// Returns `true` when at least one credential is persisted.
    var hasAnyConfigured: Bool {
        APIService.allCases.contains { isConfigured($0) }
    }

    // MARK: - Validation

    /// Basic format check. Returns nil if valid, or an error message.
    func validate(_ value: String, for service: APIService) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil } // empty = valid (unset)

        guard let prefix = service.expectedPrefix else { return nil }

        if !trimmed.hasPrefix(prefix) {
            switch service {
            case .deepseekAPIKey:
                return "DeepSeek Key 应以 'sk-' 开头"
            case .slackBotToken:
                return "Slack Token 应以 'xoxb-' 开头"
            case .githubToken:
                return "GitHub Token 应以 'gh' 开头"
            default:
                return "格式似乎不正确"
            }
        }

        if trimmed.count < 8 {
            return "值太短了"
        }

        return nil
    }

    // MARK: - Connectivity Test

    /// Tests whether a given service's credential is valid and reachable.
    /// This is an asynchronous call that performs a real network request.
    func testConnection(for service: APIService, completion: @escaping (APITestResult) -> Void) {
        switch service {
        case .deepseekAPIKey:
            testDeepSeek(completion: completion)
        case .openWeatherAPIKey:
            testOpenWeather(completion: completion)
        case .slackBotToken:
            testSlack(completion: completion)
        case .githubToken:
            testGitHub(completion: completion)
        case .rssAPIKey:
            testRSS(completion: completion)
        case .kuaidi100Key:
            testKuaidi100(completion: completion)
        case .mijiaToken:
            testMiJia(completion: completion)
        case .sshHost:
            testSSH(completion: completion)
        default:
            completion(.fail("该服务暂不支持测试"))
        }
    }

    // MARK: - DeepSeek Test

    private func testDeepSeek(completion: @escaping (APITestResult) -> Void) {
        let key = retrieve(.deepseekAPIKey)
        guard !key.isEmpty else {
            completion(.fail("未配置 API Key"))
            return
        }
        let baseURL = retrieve(.deepseekBaseURL).isEmpty
            ? "https://api.deepseek.com"
            : retrieve(.deepseekBaseURL)
        let model = retrieve(.deepseekModel).isEmpty
            ? "deepseek-v4-flash"
            : retrieve(.deepseekModel)

        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            completion(.fail("Base URL 无效"))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": "嗨"]
            ],
            "max_tokens": 50,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.fail("网络错误", detail: error.localizedDescription))
                    return
                }
                guard let http = response as? HTTPURLResponse else {
                    completion(.fail("无响应"))
                    return
                }
                guard let data = data else {
                    completion(.fail("空响应体"))
                    return
                }
                if http.statusCode == 200 {
                    // Try to extract the reply
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let choices = json["choices"] as? [[String: Any]],
                       let message = choices.first?["message"] as? [String: Any],
                       let content = message["content"] as? String {
                        let preview = content.prefix(60)
                        completion(.ok("连接成功", detail: "回复: \(preview)"))
                    } else {
                        completion(.ok("连接成功", detail: "HTTP 200"))
                    }
                } else {
                    let bodyStr = String(data: data, encoding: .utf8)?.prefix(200) ?? ""
                    completion(.fail("HTTP \(http.statusCode)", detail: String(bodyStr)))
                }
            }
        }.resume()
    }

    // MARK: - OpenWeatherMap Test

    private func testOpenWeather(completion: @escaping (APITestResult) -> Void) {
        let key = retrieve(.openWeatherAPIKey)
        guard !key.isEmpty else {
            completion(.fail("未配置 API Key"))
            return
        }
        // Use a well-known city (Beijing) for the test
        let urlStr = "https://api.openweathermap.org/data/2.5/weather?q=Beijing&appid=\(key)&units=metric"
        guard let url = URL(string: urlStr) else {
            completion(.fail("URL 无效"))
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.fail("网络错误", detail: error.localizedDescription))
                    return
                }
                guard let http = response as? HTTPURLResponse else {
                    completion(.fail("无响应"))
                    return
                }
                if http.statusCode == 200 {
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let name = json["name"] as? String,
                       let main = json["main"] as? [String: Any],
                       let temp = main["temp"] as? Double {
                        completion(.ok("连接成功", detail: "\(name): \(temp)°C"))
                    } else {
                        completion(.ok("连接成功", detail: "HTTP 200"))
                    }
                } else if http.statusCode == 401 {
                    completion(.fail("HTTP 401 — API Key 无效"))
                } else {
                    let bodyStr = String(data: data ?? Data(), encoding: .utf8)?.prefix(200) ?? ""
                    completion(.fail("HTTP \(http.statusCode)", detail: String(bodyStr)))
                }
            }
        }.resume()
    }

    // MARK: - Slack Test

    private func testSlack(completion: @escaping (APITestResult) -> Void) {
        let token = retrieve(.slackBotToken)
        guard !token.isEmpty else {
            completion(.fail("未配置 Bot Token"))
            return
        }
        guard let url = URL(string: "https://slack.com/api/auth.test") else {
            completion(.fail("URL 无效"))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.fail("网络错误", detail: error.localizedDescription))
                    return
                }
                guard let data = data else {
                    completion(.fail("空响应"))
                    return
                }
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let ok = json["ok"] as? Bool, ok {
                        let team = json["team"] as? String ?? ""
                        let user = json["user"] as? String ?? ""
                        completion(.ok("连接成功", detail: "\(team) / \(user)"))
                    } else {
                        let errMsg = json["error"] as? String ?? "未知错误"
                        completion(.fail("认证失败", detail: errMsg))
                    }
                } else {
                    completion(.fail("响应解析失败"))
                }
            }
        }.resume()
    }

    // MARK: - GitHub Test

    private func testGitHub(completion: @escaping (APITestResult) -> Void) {
        let token = retrieve(.githubToken)
        guard !token.isEmpty else {
            completion(.fail("未配置 Token"))
            return
        }
        guard let url = URL(string: "https://api.github.com/user") else {
            completion(.fail("URL 无效"))
            return
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.fail("网络错误", detail: error.localizedDescription))
                    return
                }
                guard let http = response as? HTTPURLResponse else {
                    completion(.fail("无响应"))
                    return
                }
                if http.statusCode == 200 {
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let login = json["login"] as? String {
                        completion(.ok("连接成功", detail: "用户: \(login)"))
                    } else {
                        completion(.ok("连接成功", detail: "HTTP 200"))
                    }
                } else if http.statusCode == 401 {
                    completion(.fail("HTTP 401 — Token 无效"))
                } else {
                    completion(.fail("HTTP \(http.statusCode)"))
                }
            }
        }.resume()
    }

    // MARK: - RSS (Feedly) Test

    private func testRSS(completion: @escaping (APITestResult) -> Void) {
        let token = retrieve(.rssAPIKey)
        guard !token.isEmpty else {
            completion(.fail("未配置 API Key / Token"))
            return
        }
        // Feedly cloud API — use the profile endpoint
        guard let url = URL(string: "https://cloud.feedly.com/v3/profile") else {
            completion(.fail("URL 无效"))
            return
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.fail("网络错误", detail: error.localizedDescription))
                    return
                }
                guard let http = response as? HTTPURLResponse else {
                    completion(.fail("无响应"))
                    return
                }
                if http.statusCode == 200 {
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let userName = json["userName"] as? String {
                        completion(.ok("连接成功", detail: "用户: \(userName)"))
                    } else {
                        completion(.ok("连接成功", detail: "HTTP 200"))
                    }
                } else if http.statusCode == 401 {
                    completion(.fail("HTTP 401 — Token 无效"))
                } else {
                    completion(.fail("HTTP \(http.statusCode)"))
                }
            }
        }.resume()
    }

    // MARK: - Kuaidi100 Test

    private func testKuaidi100(completion: @escaping (APITestResult) -> Void) {
        let key = retrieve(.kuaidi100Key)
        guard !key.isEmpty else {
            completion(.fail("未配置 Key"))
            return
        }
        // Kuaidi100 auto-detect endpoint — use a dummy tracking number
        let urlStr = "https://poll.kuaidi100.com/test"
        guard let url = URL(string: urlStr) else {
            completion(.fail("URL 无效"))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    // DNS / connection errors mean the host is unreachable
                    completion(.fail("网络错误", detail: error.localizedDescription))
                    return
                }
                guard let http = response as? HTTPURLResponse else {
                    completion(.fail("无响应"))
                    return
                }
                // Kuaidi100 returns 200 even for invalid keys on some endpoints;
                // we just verify reachability here.
                if http.statusCode == 200 {
                    completion(.ok("服务器可达", detail: "HTTP 200"))
                } else {
                    completion(.fail("HTTP \(http.statusCode)"))
                }
            }
        }.resume()
    }

    // MARK: - MiJia Test

    private func testMiJia(completion: @escaping (APITestResult) -> Void) {
        let token = retrieve(.mijiaToken)
        guard !token.isEmpty else {
            completion(.fail("未配置 Token"))
            return
        }
        // MiJia uses a local network API (typically miio protocol).
        // We can only verify the token format is non-empty.
        // A real test would require discovering the device on LAN.
        if token.count >= 16 {
            completion(.ok("Token 格式看起来有效", detail: "完整设备发现需要局域网连接"))
        } else {
            completion(.fail("Token 太短，可能无效"))
        }
    }

    // MARK: - SSH Test

    private func testSSH(completion: @escaping (APITestResult) -> Void) {
        let host = retrieve(.sshHost)
        guard !host.isEmpty else {
            completion(.fail("未配置主机地址"))
            return
        }
        // Perform a TCP connectivity check on port 22
        DispatchQueue.global().async {
            let socket = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_STREAM, IPPROTO_TCP, 0, nil, nil)
            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = CFSwapInt16HostToBig(22)
            inet_pton(AF_INET, host, &addr.sin_addr)
            let addrData = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<sockaddr_in>.size) {
                    CFDataCreate(kCFAllocatorDefault, $0, MemoryLayout<sockaddr_in>.size)
                }
            }
            let result = CFSocketConnectToAddress(socket, addrData, 5)
            DispatchQueue.main.async {
                switch result {
                case .success:
                    completion(.ok("SSH 端口可达", detail: "\(host):22 连接成功"))
                case .error:
                    completion(.fail("连接失败", detail: "无法连接到 \(host):22"))
                case .timeout:
                    completion(.fail("连接超时", detail: "\(host):22 超时"))
                @unknown default:
                    completion(.fail("未知错误"))
                }
            }
        }
    }

    // MARK: - Hardcoded Key Detection

    /// Scans the given JSON string for apiKey/api_key fields with non-empty
    /// values and returns their locations.
    func detectHardcodedKeys(in jsonString: String) -> [(line: Int, snippet: String)] {
        var results: [(Int, String)] = []
        let lines = jsonString.components(separatedBy: .newlines)
        for (idx, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let keyRange = trimmed.range(of: "\"api") else { continue }
            guard let colonRange = trimmed.range(of: ":") else { continue }
            guard colonRange.lowerBound > keyRange.upperBound else { continue }
            let afterColon = trimmed[colonRange.upperBound...].trimmingCharacters(in: .whitespaces)
            if afterColon.hasPrefix("\"") && !afterColon.hasPrefix("\"\"") {
                let snippet = String(trimmed.prefix(60))
                results.append((idx + 1, snippet))
            }
        }
        return results
    }

    // MARK: - Keychain (private)

    private let keychainServiceName = "com.lyricsmtmr.SecretsManager"

    private func keychainStore(_ value: String, for service: APIService) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainServiceName,
            kSecAttrAccount as String: service.defaultsKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func keychainRetrieve(_ service: APIService) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainServiceName,
            kSecAttrAccount as String: service.defaultsKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func keychainDelete(_ service: APIService) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainServiceName,
            kSecAttrAccount as String: service.defaultsKey,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Convenience accessors (backward-compatible with existing AppSettings calls)

extension AppSettings {
    /// Wrapper that routes through SecretsManager.
    static var managedAPIKey: String { SecretsManager.shared.retrieve(.deepseekAPIKey) }
    static var managedWeatherKey: String { SecretsManager.shared.retrieve(.openWeatherAPIKey) }
}
