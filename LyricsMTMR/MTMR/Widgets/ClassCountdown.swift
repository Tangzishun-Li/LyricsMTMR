//
//  ClassCountdown.swift  ·  item type: classCountdown
//  课程表倒计时：读取本地 classes.json（含上课时间与星期），展示今天下一节课的名称、教室与开始倒计时。
//  首次启动自动播种示例。属性：dataPath（可空=默认）。
//

import Cocoa

private struct TBClass: Codable { let name: String; let room: String; let time: String; let days: [Int] }
private struct TBClassFile: Codable { var classes: [TBClass] }

class ClassCountdownItem: TBPollItem {
    private let dataPath: String
    private var title = "…"
    private var sub = ""
    private var tint = TB.sky
    private static let filename = "classes.json"
    private static let sample = "{\"classes\":[{\"name\":\"\u{9ad8}\u{6570}\",\"room\":\"A301\",\"time\":\"08:00\",\"days\":[1,3,5]},{\"name\":\"\u{82f1}\u{8bed}\",\"room\":\"B202\",\"time\":\"14:00\",\"days\":[1,2,3,4,5]}]}"

    init(identifier: NSTouchBarItem.Identifier, refreshInterval: Double, dataPath: String) {
        self.dataPath = dataPath
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "graduationcap.fill", tint: TB.sky,
                   label: localized("下节课", "Class"), width: 168)
        TBStore.seed(filename: Self.filename, sample: Self.sample)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func compute() {
        let path = dataPath.isEmpty ? appSupportDirectory.appending("/\(Self.filename)") : (dataPath as NSString).expandingTildeInPath
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let file = try? JSONDecoder().decode(TBClassFile.self, from: data) else {
            title = localized("无课表", "no data"); sub = ""; return
        }
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let monBased = ((weekday + 5) % 7) + 1
        let timeFmt = DateFormatter(); timeFmt.dateFormat = "HH:mm"
        var best: (TBClass, Date)?
        for cls in file.classes where cls.days.contains(monBased) {
            guard let classTime = timeFmt.date(from: cls.time) else { continue }
            let parts = calendar.dateComponents([.hour, .minute], from: classTime)
            guard let target = calendar.date(bySettingHour: parts.hour ?? 0, minute: parts.minute ?? 0, second: 0, of: now) else { continue }
            if target > now, best == nil || target < best!.1 { best = (cls, target) }
        }
        if let (cls, target) = best {
            title = "\(cls.name) · \(cls.room)"
            sub = Self.format(target.timeIntervalSince(now))
            tint = target.timeIntervalSince(now) < 600 ? TB.coral : TB.sky
        } else {
            title = localized("今天没课", "no class")
            sub = ""
            tint = TB.mint
        }
    }

    override func apply() {
        metric.value = title
        metric.subValue = sub
        metric.valueColor = TB.textPrimary
        metric.iconTint = tint
    }

    private static func format(_ seconds: TimeInterval) -> String {
        let s = Int(max(0, seconds))
        if s >= 3600 { return "\(s / 3600)h\(s % 3600 / 60)m" }
        return "\(s / 60)m"
    }
}
