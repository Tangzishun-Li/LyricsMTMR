//
//  DdlList.swift  ·  item type: ddlList
//  作业 DDL 列表：读取本地 ddls.json，展示最近一个截止任务的标题与剩余天数，
//  48 小时内变珊瑚色告警。首次启动自动播种示例。属性：dataPath（可空=默认）。
//

import Cocoa

private struct TBDdl: Codable { let title: String; let due: String }
private struct TBDdlFile: Codable { var ddls: [TBDdl] }

class DdlListItem: TBPollItem {
    private let dataPath: String
    private var title = "…"
    private var days = 0
    private var hasData = false
    private static let filename = "ddls.json"
    private static let sample = "{\"ddls\":[{\"title\":\"\u{7269}\u{7406}\u{5b9e}\u{9a8c}\u{62a5}\u{544a}\",\"due\":\"2026-07-30\"},{\"title\":\"\u{7ebf}\u{4ee3}\u{4f5c}\u{4e1a}\",\"due\":\"2026-08-05\"}]}"

    init(identifier: NSTouchBarItem.Identifier, refreshInterval: Double, dataPath: String) {
        self.dataPath = dataPath
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "exclamationmark.circle.fill", tint: TB.coral,
                   label: "DDL", width: 160)
        TBStore.seed(filename: Self.filename, sample: Self.sample)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func compute() {
        let path = dataPath.isEmpty ? appSupportDirectory.appending("/\(Self.filename)") : (dataPath as NSString).expandingTildeInPath
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let file = try? JSONDecoder().decode(TBDdlFile.self, from: data) else {
            title = localized("无数据", "no data"); hasData = false; return
        }
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let calendar = Calendar.current
        let now = Date()
        var nearest: TBDdl?
        var nearestDays = Int.max
        for ddl in file.ddls {
            guard let date = fmt.date(from: ddl.due) else { continue }
            let d = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
            if d >= 0, d < nearestDays { nearestDays = d; nearest = ddl }
        }
        if let nearest = nearest { title = nearest.title; days = nearestDays; hasData = true }
        else { title = localized("暂无 DDL", "all clear"); hasData = false }
    }

    override func apply() {
        metric.value = String(title.prefix(12))
        metric.subValue = hasData ? localized("剩 \(days) 天", "\(days)d left") : ""
        metric.valueColor = TB.textPrimary
        metric.iconTint = days <= 2 && hasData ? TB.coral : TB.gold
    }
}
