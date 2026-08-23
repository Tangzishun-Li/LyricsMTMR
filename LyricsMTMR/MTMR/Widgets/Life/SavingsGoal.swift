//
//  SavingsGoal.swift  ·  item type: savingsGoal
//  储蓄目标进度条：读取本地 savings.json，展示目标名称、已存/目标金额与完成度进度条。
//  首次启动自动播种示例。属性：dataPath（可空=默认）、refreshInterval。
//
//  R58-c（G6/G7）消费契约：savings.json 除既有 savings 子树外新增四个同级键
//  （ExpenseTabView saveToJSON 既有写入，键名禁改——存量数据无损红线）：
//    - monthlyBudget: Double  月度预算；本月已存超支时 value 加 ⚠ 前缀
//    - savingsGoal:   Double  储蓄目标；与 savings.goal 同语义时以本键优先渲染进度条
//    - currency:      String  金额单位后缀（默认 "¥"，如 "CNY"/"USD" 由设置页选择）
//    - overspendAlert: Bool   false 时关闭 ⚠ 超支前缀
//  G7：BeeCount 凭据可达（SecretsManager beecountURL/beecountPAT）则拉取今日收支摘要
//  追加在副行；凭据缺失或网络失败静默回退原显示，不得拖垮主显示。
//

import Cocoa

private struct TBSavings: Codable { let name: String; let saved: Double; let goal: Double }
private struct TBSavingsFile: Codable { var savings: TBSavings }

/// savings.json 四个同级预算键的解析结果（R58-c G6 消费契约）。
/// 测试入口：`SavingsGoalItem.parseBudget(from:)` 纯函数断言四键解析与 ⚠ 规则。
struct ExpenseBudget: Equatable {
    var monthlyBudget: Double?
    var savingsGoal: Double?
    var currency: String?
    var overspendAlert: Bool?

    static let `default` = ExpenseBudget(monthlyBudget: nil, savingsGoal: nil,
                                         currency: nil, overspendAlert: nil)

    /// 金额单位后缀：currency 键缺失/空 → "¥"（契约 §6 默认值）。
    /// CNY 等常见 ISO 代码渲染为符号；其余原样作为后缀。
    var currencySuffix: String {
        guard let c = currency?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty else { return "¥" }
        switch c.uppercased() {
        case "CNY": return "¥"
        case "USD": return "$"
        case "MOP": return "MOP"
        default: return c
        }
    }

    /// 月预算超支判定：overspendAlert=false 关闭（不加前缀）；无预算值不判超支；
    /// 本月已存 > monthlyBudget 且开关开启才加 ⚠。
    func isOverspent(savedThisMonth: Double) -> Bool {
        guard overspendAlert != false, let budget = monthlyBudget, budget > 0 else { return false }
        return savedThisMonth > budget
    }

    /// 渲染用目标值：savingsGoal 键优先，缺省回退既有 savings.goal 子树（≥1 防 0 除）。
    func effectiveGoal(fallback: Double) -> Double {
        if let g = savingsGoal, g > 0 { return g }
        return max(1, fallback)
    }

    /// 进度条数值：本月已存 / 目标，夹到 [0,1]；无 savingsGoal 键回 nil（回退既有语义）。
    func progressRatio(savedThisMonth: Double) -> CGFloat? {
        guard let g = savingsGoal, g > 0 else { return nil }
        return CGFloat(max(0, min(1, savedThisMonth / g)))
    }

    /// 百分比 value：优先 savingsGoal 口径，缺省回退既有 saved/goal 子树口径。
    func percent(saved: Double, legacyGoal: Double) -> Int {
        let ratio = progressRatio(savedThisMonth: saved)
            ?? CGFloat(max(0, min(1, saved / effectiveGoal(fallback: legacyGoal))))
        return Int(ratio * 100)
    }
}

class SavingsGoalItem: TBPollItem {
    private let dataPath: String
    private var name = "…"
    private var saved = 0.0
    private var goal = 1.0
    /// G6 四键解析结果（compute() 在后台队列填充，apply() 主线程消费）。
    private var budget: ExpenseBudget = .default
    private var monthSaved = 0.0
    /// G7 BeeCount 今日收支摘要（nil = 不可达/未配置，静默回退原显示）。
    private var beeCountSummary: String?
    private static let filename = "savings.json"
    private static let sample = "{\"savings\":{\"name\":\"\(localized("旅行基金", "Travel"))\",\"saved\":3000,\"goal\":10000}}"

    init(identifier: NSTouchBarItem.Identifier, refreshInterval: Double, dataPath: String) {
        self.dataPath = dataPath
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "banknote.fill", tint: TB.mint,
                   label: localized("储蓄", "Save"), width: 168)
        TBStore.seed(filename: Self.filename, sample: Self.sample)
    }
    required init?(coder: NSCoder) { return nil }

    override func compute() {
        let path = dataPath.isEmpty ? appSupportDirectory.appending("/\(Self.filename)") : (dataPath as NSString).expandingTildeInPath
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let file = try? JSONDecoder().decode(TBSavingsFile.self, from: data) else {
            name = localized("无数据", "no data"); return
        }
        name = file.savings.name
        saved = file.savings.saved
        goal = max(1, file.savings.goal)
        // G6 四键：JSONSerialization 容错读取同级键（Double 兼容 Int 写入，
        // 缺键保持 nil → 回退既有显示语义）。
        let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        budget = Self.parseBudget(from: dict)
        monthSaved = saved
        // G7 BeeCount 摘要：同步拉取（compute 本就跑在后台轮询队列），失败静默置 nil。
        beeCountSummary = SavingsGoalItem.beeCountTodaySummary()
    }

    override func apply() {
        // G6：savingsGoal 键优先作为进度目标；无该键维持既有 saved/goal 子树语义。
        let displayGoal = budget.effectiveGoal(fallback: goal)
        let ratio = budget.progressRatio(savedThisMonth: monthSaved)
            ?? CGFloat(max(0, min(1, saved / displayGoal)))
        metric.progress = CGFloat(ratio)
        var value = "\(budget.percent(saved: saved, legacyGoal: goal))%"
        // G6 ⚠ 规则：月预算超支且 overspendAlert≠false 时加前缀。
        if budget.isOverspent(savedThisMonth: monthSaved) { value = "⚠" + value }
        metric.value = value
        // G6 currency 后缀渲染（默认 ¥）；G7 BeeCount 摘要以「 · 今日」拼进副行，
        // nil（未配置/不可达/失败）时静默回退原显示。
        var subValue = localized("\(budget.currencySuffix)\(Int(saved))/\(budget.currencySuffix)\(Int(displayGoal))",
                                 "\(budget.currencySuffix)\(Int(saved))/\(budget.currencySuffix)\(Int(displayGoal))")
        if let summary = beeCountSummary {
            subValue += localized(" · 今日 \(summary)", " · today \(summary)")
        }
        metric.subValue = subValue
        metric.progressTint = ratio >= 1 ? TB.gold : TB.mint
        metric.iconTint = ratio >= 1 ? TB.gold : TB.mint
        metric.valueColor = ratio >= 1 ? TB.gold : TB.textPrimary
    }

    // MARK: - G6 四键解析（纯函数，供契约测试直接断言）

    /// 从 savings.json 顶层字典解析 monthlyBudget/savingsGoal/currency/overspendAlert。
    /// 键名是既有写入（ExpenseTabView.saveToJSON），禁改；缺键一律 nil（不臆造默认）。
    static func parseBudget(from dict: [String: Any]) -> ExpenseBudget {
        var b = ExpenseBudget.default
        // JSONSerialization 数字统一 NSNumber；Double 兼容 Int 写入（5000 vs 5000.0）。
        if let n = dict["monthlyBudget"] as? NSNumber { b.monthlyBudget = n.doubleValue }
        else if let d = dict["monthlyBudget"] as? Double { b.monthlyBudget = d }
        if let n = dict["savingsGoal"] as? NSNumber { b.savingsGoal = n.doubleValue }
        else if let d = dict["savingsGoal"] as? Double { b.savingsGoal = d }
        if let s = dict["currency"] as? String { b.currency = s }
        if let n = dict["overspendAlert"] as? NSNumber { b.overspendAlert = n.boolValue }
        else if let v = dict["overspendAlert"] as? Bool { b.overspendAlert = v }
        return b
    }

    // MARK: - G7 BeeCount 今日收支摘要

    /// 凭据可达（SecretsManager 先例，UserDefaults/Keychain 双后端由其内部处理）
    /// 则请求 BeeCount-Cloud 当日账目汇总「收 x / 支 y」；任一环节失败返回 nil，
    /// 调用方静默回退原显示——BeeCount 失败绝不拖垮记账主显示。
    static func beeCountTodaySummary(session: URLSession = .shared) -> String? {
        let base = SecretsManager.shared.retrieve(.beecountURL).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let pat = SecretsManager.shared.retrieve(.beecountPAT)
        guard !base.isEmpty, !pat.isEmpty, let url = URL(string: base + "/api/read/day") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(pat)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 8
        let semaphore = DispatchSemaphore(value: 0)
        var summary: String?
        session.dataTask(with: request) { data, response, _ in
            defer { semaphore.signal() }
            guard let http = response as? HTTPURLResponse, http.statusCode == 200, let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            // 字段名容错：income/expense 为主，兼容 note/note2 变体（自托管版本差异）。
            let income = (json["income"] as? NSNumber).map(String.init(describing:))
                ?? (json["note"] as? NSNumber).map(String.init(describing:))
            let expense = (json["expense"] as? NSNumber).map(String.init(describing:))
                ?? (json["note2"] as? NSNumber).map(String.init(describing:))
            guard income != nil || expense != nil else { return }
            summary = "收 \(income ?? "0") / 支 \(expense ?? "0")"
        }.resume()
        // compute() 的串行后台队列允许短暂阻塞；超时按失败处理（静默回退）。
        guard semaphore.wait(timeout: .now() + 10) == .success else { return nil }
        return summary
    }
}
