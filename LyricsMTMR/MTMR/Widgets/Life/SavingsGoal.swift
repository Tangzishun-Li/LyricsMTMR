//
//  SavingsGoal.swift  ·  item type: savingsGoal
//  储蓄目标进度条：读取本地 savings.json，展示目标名称、已存/目标金额与完成度进度条。
//  首次启动自动播种示例。属性：dataPath（可空=默认）、refreshInterval。
//

import Cocoa

private struct TBSavings: Codable { let name: String; let saved: Double; let goal: Double }
private struct TBSavingsFile: Codable { var savings: TBSavings }

class SavingsGoalItem: TBPollItem {
    private let dataPath: String
    private var name = "…"
    private var saved = 0.0
    private var goal = 1.0
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
    }

    override func apply() {
        let ratio = max(0, min(1, saved / goal))
        metric.value = "\(Int(ratio * 100))%"
        metric.subValue = localized("¥\(Int(saved))/\(Int(goal))", "¥\(Int(saved))/\(Int(goal))")
        metric.progress = CGFloat(ratio)
        metric.progressTint = ratio >= 1 ? TB.gold : TB.mint
        metric.iconTint = ratio >= 1 ? TB.gold : TB.mint
        metric.valueColor = ratio >= 1 ? TB.gold : TB.textPrimary
    }
}
