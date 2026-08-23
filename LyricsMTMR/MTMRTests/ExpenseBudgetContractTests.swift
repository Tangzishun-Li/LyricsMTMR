//
//  ExpenseBudgetContractTests.swift
//  LyricsMTMRTests
//
//  R58-c（G6/G7）：savings.json 四键消费契约 + ⚠ 超支规则。
//  契约出处：docs/轨道文本_R58_UI态持久化与Phase2.md §6——
//  - 四键 monthlyBudget/savingsGoal/currency/overspendAlert 是 ExpenseTabView
//    saveToJSON 的既有写入，键名冻结；消费者 SavingsGoalItem 只补读取不改名；
//  - 月预算超支时 value 加 ⚠ 前缀，overspendAlert=false 关闭；
//  - currency 作为金额单位后缀渲染，缺省 "¥"；
//  - BeeCount 凭据不可达/失败 → 静默回退（nil），不拖垮主显示。
//  纯函数断言（parseBudget / ExpenseBudget 判定），不触网、不碰真实存储。
//
import XCTest
@testable import LyricsMTMR

class ExpenseBudgetContractTests: XCTestCase {

    // MARK: - 四键解析契约

    func testParseBudgetReadsAllFourKeys() {
        // 与 ExpenseTabView.saveToJSON 写盘格式一致（prettyPrinted JSON）。
        let json = """
        {"monthlyBudget":5000,"savingsGoal":10000,"currency":"CNY","overspendAlert":true,
         "savings":{"name":"旅行基金","saved":3000,"goal":10000}}
        """.data(using: .utf8)!
        let dict = (try? JSONSerialization.jsonObject(with: json)) as? [String: Any] ?? [:]

        let b = SavingsGoalItem.parseBudget(from: dict)
        XCTAssertEqual(b.monthlyBudget, 5000, "monthlyBudget 键必须解析为 Double")
        XCTAssertEqual(b.savingsGoal, 10000, "savingsGoal 键必须解析为 Double")
        XCTAssertEqual(b.currency, "CNY", "currency 键必须解析为 String")
        XCTAssertEqual(b.overspendAlert, true, "overspendAlert 键必须解析为 Bool")
    }

    func testParseBudgetMissingKeysStayNil() {
        // 存量 savings.json 只有 savings 子树（R57 前格式）：四键缺省一律 nil，
        // 消费端回退既有显示语义，不得臆造默认值。
        let b = SavingsGoalItem.parseBudget(from: ["savings": ["name": "x", "saved": 1, "goal": 2]])
        XCTAssertNil(b.monthlyBudget)
        XCTAssertNil(b.savingsGoal)
        XCTAssertNil(b.currency)
        XCTAssertNil(b.overspendAlert)
        XCTAssertEqual(b.currencySuffix, "¥", "currency 缺键 → 默认后缀 ¥（§6 契约）")
    }

    func testParseBudgetIntWrittenNumbersStillParse() {
        // JSONSerialization 整数写盘场景（如外部工具覆写 5000 而非 5000.0）：
        // NSNumber 桥接下 Double 兼容读取。
        let dict: [String: Any] = ["monthlyBudget": 5000, "savingsGoal": 800,
                                   "currency": "USD", "overspendAlert": false]
        let b = SavingsGoalItem.parseBudget(from: dict)
        XCTAssertEqual(b.monthlyBudget, 5000)
        XCTAssertEqual(b.savingsGoal, 800)
        XCTAssertEqual(b.currencySuffix, "$", "USD 渲染为 $ 符号后缀")
        XCTAssertEqual(b.overspendAlert, false)
    }

    // MARK: - ⚠ 超支规则契约

    func testOverspendWarningRule() {
        var b = ExpenseBudget.default
        b.monthlyBudget = 1000
        b.overspendAlert = true
        XCTAssertTrue(b.isOverspent(savedThisMonth: 1200), "超预算且开关开 → ⚠（加前缀）")
        XCTAssertFalse(b.isOverspent(savedThisMonth: 999), "未超预算不加 ⚠")

        b.overspendAlert = false
        XCTAssertFalse(b.isOverspent(savedThisMonth: 1200),
                       "overspendAlert=false 必须关闭 ⚠ 前缀（即使已超支）")
    }

    func testSavingsGoalKeyDrivesProgressAndFallback() {
        var b = ExpenseBudget.default
        XCTAssertEqual(b.percent(saved: 3000, legacyGoal: 10000), 30,
                       "无 savingsGoal 键回退既有 saved/goal 子树口径（存量语义不变）")
        XCTAssertNil(b.progressRatio(savedThisMonth: 3000),
                     "无 savingsGoal 键 progressRatio 为 nil → 进度条走回退分支")

        b.savingsGoal = 6000
        XCTAssertEqual(b.effectiveGoal(fallback: 10000), 6000, "savingsGoal 键优先作为目标")
        XCTAssertEqual(b.progressRatio(savedThisMonth: 3000), 0.5, "进度条按 本月已存/savingsGoal 计算")
        XCTAssertEqual(b.percent(saved: 9000, legacyGoal: 10000), 100,
                       "比例夹到 [0,1]（超目标封顶 100%）")
    }
}
