//
//  CurrencyBarItem.swift
//  MTMR
//
//  Created by Daniel Apatin on 18.04.2018.
//  Copyright © 2018 Anton Palgunov. All rights reserved.
//

import Cocoa
import CoreLocation

class CurrencyBarItem: CustomButtonTouchBarItem {
    private let activity: NSBackgroundActivityScheduler
    private var prefix: String
    private var postfix: String
    private var from: String
    private var to: String
    private var decimal: Int
    private var oldValue: Float32!
    private var full: Bool = false

    private let currencies = [
        "USD": "$",
        "EUR": "€",
        "RUB": "₽",
        "JPY": "¥",
        "GBP": "₤",
        "CAD": "$",
        "KRW": "₩",
        "CNY": "¥",
        "AUD": "$",
        "BRL": "R$",
        "IDR": "Rp",
        "MXN": "$",
        "SGD": "$",
        "BTC": "฿",
        "LTC": "Ł",
        "ETH": "Ξ",
        "SOL": "◎",
        "DOT": "●",
        "DOGE": "Ð",
        "XMR": "ɱ",
        "ADA": "₳",
        "PLN": "zł",
        "UAH": "₴",
    ]
    private let decimals = [
        "USD": 4,
        "EUR": 4,
        "RUB": 2,
        "JPY": 2,
        "GBP": 4,
        "CAD": 4,
        "KRW": 4,
        "CNY": 4,
        "AUD": 4,
        "BRL": 4,
        "IDR": 1,
        "MXN": 2,
        "SGD": 4,
        "CHF": 4,
        "BTC": 3,
        "LTC": 2,
        "ETH": 2,
        "DOT": 3,
        "DOGE": 4,
        "ADA": 3,
        "USDT": 3
    ]

    init(identifier: NSTouchBarItem.Identifier, interval: TimeInterval, from: String, to: String, full: Bool) {
        activity = NSBackgroundActivityScheduler(identifier: "\(identifier.rawValue).updatecheck")
        activity.interval = interval
        self.from = from
        self.to = to
        self.full = full

        if let prefix = currencies[from] {
            self.prefix = prefix
        } else {
            prefix = from
        }

        if let postfix = currencies[to] {
            self.postfix = postfix
        } else {
            postfix = to
        }

        
        if let decimal = decimals[to] {
            self.decimal = decimal
        } else {
            decimal = 2
        }
        
        
        super.init(identifier: identifier, title: "⏳")

        activity.repeats = true
        activity.qualityOfService = .utility
        activity.schedule { (completion: NSBackgroundActivityScheduler.CompletionHandler) in
            self.updateCurrency()
            completion(NSBackgroundActivityScheduler.Result.finished)
        }
        updateCurrency()
    }

    required init?(coder _: NSCoder) { return nil }

    // MARK: - 纯逻辑（round14 提取，可单元测试）

    /// 从 Coinbase 汇率响应 JSON 中解析目标币种汇率（`data.rates[<to>]`）。
    /// 结构缺失/币种不存在/值为非字符串/JSON 非法时返回 nil（不抛错、不崩溃）。
    static func parseRate(from data: Data, to: String) -> Float32? {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let dataDict = json["data"] as? [String: Any],
              let rates = dataDict["rates"] as? [String: Any],
              let raw = rates[to] as? String,
              let value = Float32(raw) else { return nil }
        return value
    }

    /// 将汇率值格式化为显示标题：
    /// full 模式「前缀+后缀‣四舍五入到 decimal 位」；否则「前缀+两位小数」。
    static func formatTitle(prefix: String, postfix: String, value: Float32, decimal: Int, full: Bool) -> String {
        if full {
            let rounded = (value * pow(10, Float(decimal))).rounded() / pow(10, Float(decimal))
            return String(format: "%@%@‣%@", prefix, postfix, String(rounded))
        } else {
            return String(format: "%@%.2f", prefix, value)
        }
    }

    @objc func updateCurrency() {
        guard let url = URL(string: "https://api.coinbase.com/v2/exchange-rates?currency=\(from)") else {
            showErrorState()
            return
        }

        let task = URLSession.shared.dataTask(with: URLRequest(url: url)) { [weak self] data, _, error in
            guard let self = self else { return }
            if error != nil {
                showErrorState()
                return
            }
            guard let data = data, let value = CurrencyBarItem.parseRate(from: data, to: self.to) else {
                showErrorState()
                return
            }
            DispatchQueue.main.async {
                self.setCurrency(value: value)
            }
        }

        task.resume()
    }

    func setCurrency(value: Float32) {
        var color = NSColor.white

        if let oldValue = self.oldValue {
            if oldValue < value {
                color = NSColor.green
            } else if oldValue > value {
                color = NSColor.red
            }
        }

        oldValue = value
        let title = CurrencyBarItem.formatTitle(prefix: prefix, postfix: postfix, value: value, decimal: decimal, full: full)

        let regularFont = attributedTitle.attribute(.font, at: 0, effectiveRange: nil) as? NSFont ?? NSFont.systemFont(ofSize: 15)
        let newTitle = NSMutableAttributedString(string: title as String, attributes: [.foregroundColor: color, .font: regularFont, .baselineOffset: 1])
        newTitle.setAlignment(.center, range: NSRange(location: 0, length: title.count))
        attributedTitle = newTitle
    }

    /// 请求失败/解析失败时的优雅降级：显示 ⚠︎ 错误态（不崩溃、不残留误导旧值）。
    private func showErrorState() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let regularFont = self.attributedTitle.attribute(.font, at: 0, effectiveRange: nil) as? NSFont ?? NSFont.systemFont(ofSize: 15)
            let newTitle = NSMutableAttributedString(string: "⚠︎", attributes: [.foregroundColor: NSColor.systemOrange, .font: regularFont, .baselineOffset: 1])
            newTitle.setAlignment(.center, range: NSRange(location: 0, length: newTitle.length))
            self.attributedTitle = newTitle
        }
    }
    
    deinit {
        activity.invalidate()
    }
}
