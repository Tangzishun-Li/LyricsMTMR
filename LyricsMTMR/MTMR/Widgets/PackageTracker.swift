//
//  PackageTracker.swift  ·  item type: packageTracker
//  快递追踪：调用快递100查询接口，展示包裹最新物流状态与时间。
//  需要在「设置 → 服务」填入 Kuaidi100 的 key / customer；未配置时显示内置 mock 状态。
//  属性：company（快递公司编码，如 shunfeng）、trackingNumber（单号）、refreshInterval。
//

import Cocoa
import CryptoKit

class PackageTrackerItem: TBPollItem {
    private let company: String
    private let trackingNumber: String
    private var statusText = "…"
    private var subText = ""
    private var tint = TB.gold

    init(identifier: NSTouchBarItem.Identifier, refreshInterval: Double, company: String, trackingNumber: String) {
        self.company = company
        self.trackingNumber = trackingNumber
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "shippingbox.fill", tint: TB.gold,
                   label: localized("快递", "PKG"), width: 168)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func compute() {
        let key = AppSettings.kuaidi100Key
        let customer = AppSettings.kuaidi100Customer
        guard !key.isEmpty, !customer.isEmpty, !trackingNumber.isEmpty else {
            statusText = localized("未配置·mock", "no key·mock")
            subText = localized("派件中 [测试]", "out for delivery [mock]")
            tint = TB.textTertiary
            return
        }
        let param = "{\"com\":\"\(company)\",\"num\":\"\(trackingNumber)\",\"phone\":\"\",\"from\":\"\",\"to\":\"\",\"resultv2\":\"1\"}"
        let plain = param + key + customer
        let sign = Insecure.MD5.hash(data: Data(plain.utf8)).map { String(format: "%02hhx", $0) }.joined().uppercased()
        let body = "customer=\(customer)&key=\(key)&sign=\(sign)&param=\(Self.urlEncode(param))"
        guard let data = Self.formPost("https://poll.kuaidi100.com/poll/query.do", body: body),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            statusText = localized("查询失败", "query failed")
            subText = ""
            tint = TB.coral
            return
        }
        let state = (json["state"] as? String) ?? ""
        let latest = ((json["data"] as? [[String: Any]])?.first?["context"] as? String) ?? ""
        statusText = Self.stateName(state)
        subText = String(latest.prefix(18))
        tint = state == "3" ? TB.mint : TB.gold
    }

    override func apply() {
        metric.value = statusText
        metric.subValue = subText
        metric.valueColor = tint
        metric.iconTint = tint
    }

    private static func stateName(_ state: String) -> String {
        switch state {
        case "0": return localized("在途", "in transit")
        case "1": return localized("揽收", "picked up")
        case "2": return localized("疑难", "issue")
        case "3": return localized("签收", "delivered")
        case "5": return localized("派件", "delivering")
        case "6": return localized("退回", "returned")
        default: return localized("查询中", "querying")
        }
    }

    private static func urlEncode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? s
    }

    private static func formPost(_ urlString: String, body: String) -> Data? {
        guard let url = URL(string: urlString) else { return nil }
        var req = URLRequest(url: url, timeoutInterval: 8)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = body.data(using: .utf8)
        var result: Data?
        let semaphore = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: req) { data, _, _ in result = data; semaphore.signal() }.resume()
        _ = semaphore.wait(timeout: .now() + 9)
        return result
    }
}
