//
//  DeepseekBalanceBarItem.swift
//  LyricsMTMR
//
//  Displays DeepSeek API balance/usage information.
//

import Cocoa
import Foundation

class DeepseekBalanceBarItem: CustomButtonTouchBarItem, TBPollPausable {
    private let apiKey: String
    private let displayMode: String
    private let showRemaining: Bool
    private let refreshInterval: TimeInterval
    /// 余额刷新定时器（round 19：隐藏期间整体暂停，恢复后立即刷新一次；仅 apiKey 非空时启停，与原实现一致）。
    private lazy var pausableTimer = TBPausableTimer(interval: refreshInterval, tolerance: refreshInterval * 0.1, immediateFireOnResume: true) { [weak self] in
        self?.refreshBalance()
    }
    private var balanceData: String = "--"

    init(identifier: NSTouchBarItem.Identifier, apiKey: String, displayMode: String, showRemaining: Bool, refreshInterval: Double) {
        // JSON 配置优先；留空则回退到「设置 → 服务」中填写的 key
        self.apiKey = apiKey.isEmpty ? SecretsManager.shared.retrieve(.deepseekAPIKey) : apiKey
        self.displayMode = displayMode
        self.showRemaining = showRemaining
        self.refreshInterval = max(refreshInterval, 60)

        super.init(identifier: identifier, title: "DeepSeek")

        isBordered = false
        refreshBalance()

        if !apiKey.isEmpty {
            pausableTimer.start()
        }
    }

    required init?(coder: NSCoder) { return nil }

    /// 隐藏（黑名单/exitTouchbar）时暂停余额轮询；显示时恢复。未配置 key 时无定时器，行为同原实现。
    func setPaused(_ paused: Bool) {
        guard !apiKey.isEmpty else { return }
        pausableTimer.setPaused(paused)
    }

    private func refreshBalance() {
        guard !apiKey.isEmpty else {
            DispatchQueue.main.async { [weak self] in
                self?.title = "DS: --"
            }
            return
        }

        fetchBalance { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let balance):
                    self?.balanceData = balance
                    self?.title = "DS: \(balance)"
                case .failure:
                    self?.title = "DS: Error"
                }
            }
        }
    }

    private func fetchBalance(completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "https://api.deepseek.com/user/balance") else {
            completion(.failure(NSError(domain: "DeepseekBalance", code: -1)))
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let balanceInfos = json["balance_infos"] as? [[String: Any]] else {
                completion(.failure(NSError(domain: "DeepseekBalance", code: -2)))
                return
            }

            if let first = balanceInfos.first,
               let balance = first["total_balance"] as? String,
               let currency = first["currency"] as? String {
                completion(.success("\(balance) \(currency)"))
            } else {
                completion(.failure(NSError(domain: "DeepseekBalance", code: -3)))
            }
        }.resume()
    }
}
