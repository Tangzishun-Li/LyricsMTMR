//
//  ApiLatency.swift  ·  item type: apiLatency
//  API 延迟监控：对自定义端点发起请求并测量往返耗时（毫秒），
//  按延迟高低以绿/黄/红配色提示健康度。
//  属性：endpoint（目标 URL，留空用默认）、refreshInterval。
//

import Cocoa

class ApiLatencyItem: TBPollItem {
    private let endpoint: String
    private var latencyMs: Double?
    private var history: [CGFloat] = []

    init(identifier: NSTouchBarItem.Identifier, endpoint: String, refreshInterval: Double) {
        self.endpoint = endpoint.isEmpty ? "https://www.apple.com/library/test/success.html" : endpoint
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "gauge.with.needle", tint: TB.mint,
                   label: localized("延迟", "PING"), width: 120)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func compute() {
        let start = Date().timeIntervalSince1970
        let data = TBNet.get(endpoint, timeout: 5)
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
            metric.subValue = nil
            return
        }
        metric.value = String(format: "%.0fms", latencyMs)
        metric.valueColor = latencyMs < 200 ? TB.mint : (latencyMs < 500 ? TB.gold : TB.coral)
        metric.subValue = nil
        metric.spark = history
    }
}
