//
//  CurrencyBarItem.swift
//  MTMR
//
//  Created by Daniel Apatin on 18.04.2018.
//  Copyright © 2018 Anton Palgunov. All rights reserved.
//

import Cocoa
import CoreLocation

class CurrencyBarItem: CustomButtonTouchBarItem, TBPollPausable {
    let activity: NSBackgroundActivityScheduler
    private var prefix: String
    private var postfix: String
    private var from: String
    private var to: String
    private var decimal: Int
    private var oldValue: Float32!
    private var full: Bool = false

    /// round 22：隐藏暂停门。NSBackgroundActivityScheduler 无 pause API，
    /// 采取「门控回调」路径——调度器保持存活，但每次触发经 pollTick 过门：
    /// bar 隐藏（黑名单 app / exitTouchbar）期间零网络请求，恢复后调度器
    /// 按原 interval 继续 + setPaused(false) 立即补刷一次。
    /// round 23：init 播种全局隐藏态——重建恰发生在 bar 隐藏期间时 gate
    /// 初始即暂停，init 单次 fetch（updateCurrency）被守卫拦截零请求，
    /// 恢复广播（setPaused(false)）负责补刷。
    private let pollGate = TBPauseGate(startPaused: TouchBarVisibilityState.shared.isBarHidden)

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
        activity.schedule { [weak self] (completion: NSBackgroundActivityScheduler.CompletionHandler) in
            self?.pollTick()
            completion(NSBackgroundActivityScheduler.Result.finished)
        }
        updateCurrency()
    }

    required init?(coder _: NSCoder) { return nil }

    // MARK: - 隐藏暂停（round 22）

    /// 调度器触发入口（background 队列）：bar 隐藏期间过门拦截，
    /// 零网络请求；隐藏期可能已累积多个触发，全部被门挡掉。
    func pollTick() {
        guard !pollGate.isPaused else { return }
        updateCurrency()
    }

    /// 隐藏（黑名单 app / exitTouchbar）时暂停轮询；显示时恢复：
    /// 主线程 hop + 状态复查（同 TBPausableTimer 模式），快速
    /// pause/resume 序列下最后一次状态为准；恢复立即补刷一次，
    /// 随后调度器按原 interval 继续。
    func setPaused(_ paused: Bool) {
        guard pollGate.setPaused(paused) else { return }
        if !paused {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.pollGate.isPaused else { return }
                self.updateCurrency()
            }
        }
    }

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
        // round 22：隐藏期零网络请求——任何入口（调度器/补刷/定位回调）
        // 在 bar 隐藏期间一律拦截，不发 Coinbase 请求。
        guard !pollGate.isPaused else { return }
        guard let url = URL(string: "https://api.coinbase.com/v2/exchange-rates?currency=\(from)") else {
            showErrorState()
            return
        }

        // Round 44: explicit timeout — the 60s session default vs the 10min
        // refresh cadence would leave the rate stale up to a minute.
        let task = URLSession.shared.dataTask(with: URLRequest(url: url, timeoutInterval: 15)) { [weak self] data, _, error in
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
