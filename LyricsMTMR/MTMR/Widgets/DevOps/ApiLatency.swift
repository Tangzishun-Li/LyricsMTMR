//
//  ApiLatency.swift  ·  item type: apiLatency
//  API 延迟监控：对自定义端点发起请求并测量往返耗时（毫秒），
//  按延迟高低以绿/黄/红配色提示健康度。
//  顶栏标签显示「<域名> 延迟」，一眼看清测的是哪条链路。
//  属性：endpoint（目标 URL，留空用默认）、refreshInterval。
//  设置 → 工具 → 延迟测试 里可覆盖 endpoint，并可开启「绕过系统代理」，
//  测出真实直连延迟而不是代理通道的延迟。
//

import Cocoa

class ApiLatencyItem: TBPollItem {
    static let endpointOverrideKey = "com.lyricsmtmr.apilatency.endpoint"
    static let bypassProxyKey = "com.lyricsmtmr.apilatency.bypassProxy"

    private let endpoint: String
    private let bypassProxy: Bool
    private var latencyMs: Double?
    private var history: [CGFloat] = []

    /// Dedicated session with an empty proxy dictionary = always direct-connect.
    private static let directSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.connectionProxyDictionary = [:]
        config.timeoutIntervalForRequest = 5
        return URLSession(configuration: config)
    }()

    init(identifier: NSTouchBarItem.Identifier, endpoint: String, refreshInterval: Double) {
        let defaults = UserDefaults.standard
        let override = defaults.string(forKey: Self.endpointOverrideKey) ?? ""
        self.endpoint = override.isEmpty
            ? (endpoint.isEmpty ? "https://www.apple.com/library/test/success.html" : endpoint)
            : override
        self.bypassProxy = defaults.bool(forKey: Self.bypassProxyKey)
        // Label names *what* is being pinged: "github.com 延迟".
        var label = localized("延迟", "PING")
        if let host = URL(string: self.endpoint)?.host, !host.isEmpty {
            var short = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
            if short.hasPrefix("api.") { short = String(short.dropFirst(4)) }
            label = localized("\(short) 延迟", "\(short) ping")
        }
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "gauge.with.needle", tint: TB.mint,
                   label: label, width: 120)
    }
    required init?(coder: NSCoder) { return nil }

    override func compute() {
        let start = Date().timeIntervalSince1970
        let data = bypassProxy ? Self.directGet(endpoint, timeout: 5) : TBNet.get(endpoint, timeout: 5)
        let elapsed = (Date().timeIntervalSince1970 - start) * 1000
        latencyMs = data == nil ? nil : elapsed
        if let latencyMs = latencyMs {
            history.append(CGFloat(latencyMs))
            if history.count > 24 { history.removeFirst(history.count - 24) }
        }
    }

    override func apply() {
        guard let latencyMs = latencyMs else {
            metric.value = localized("超时", "timeout")
            metric.valueColor = TB.coral
            metric.subValue = modeLabel
            return
        }
        metric.value = String(format: "%.0fms", latencyMs)
        metric.valueColor = latencyMs < 200 ? TB.mint : (latencyMs < 500 ? TB.gold : TB.coral)
        // 标明这条延迟走的是直连还是系统代理，免得数字来源不明
        metric.subValue = modeLabel
        metric.spark = history
    }

    private var modeLabel: String {
        bypassProxy ? localized("直连", "direct") : localized("代理", "proxy")
    }

    private static func directGet(_ urlString: String, timeout: TimeInterval) -> Data? {
        guard let url = URL(string: urlString) else { return nil }
        var result: Data?
        let semaphore = DispatchSemaphore(value: 0)
        directSession.dataTask(with: URLRequest(url: url, timeoutInterval: timeout)) { data, _, _ in
            result = data
            semaphore.signal()
        }.resume()
        _ = semaphore.wait(timeout: .now() + timeout + 1)
        return result
    }
}
