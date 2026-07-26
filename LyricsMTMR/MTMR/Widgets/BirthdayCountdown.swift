//
//  BirthdayCountdown.swift  ·  item type: birthdayCountdown
//  生日/纪念日倒计时：读取本地 birthdays.json（MM-DD 日期），展示最近一个的名字与剩余天数，
//  当天变金色高亮。首次启动自动播种示例。属性：dataPath（可空=默认）。
//

import Cocoa

private struct TBBirthday: Codable { let name: String; let date: String }
private struct TBBirthdayFile: Codable { var birthdays: [TBBirthday] }

class BirthdayCountdownItem: TBPollItem {
    private let dataPath: String
    private var name = "…"
    private var days = 0
    private static let filename = "birthdays.json"
    private static let sample = "{\"birthdays\":[{\"name\":\"\u{5988}\u{5988}\",\"date\":\"08-03\"},{\"name\":\"\u{5c0f}\u{660e}\",\"date\":\"12-01\"}]}"

    init(identifier: NSTouchBarItem.Identifier, refreshInterval: Double, dataPath: String) {
        self.dataPath = dataPath
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "gift.fill", tint: TB.pink,
                   label: localized("生日", "Bday"), width: 150)
        TBStore.seed(filename: Self.filename, sample: Self.sample)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func compute() {
        let path = dataPath.isEmpty ? appSupportDirectory.appending("/\(Self.filename)") : (dataPath as NSString).expandingTildeInPath
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let file = try? JSONDecoder().decode(TBBirthdayFile.self, from: data) else {
            name = localized("无数据", "no data"); return
        }
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let fmt = DateFormatter(); fmt.dateFormat = "MM-dd"
        var nearestName = ""
        var nearestDays = Int.max
        for entry in file.birthdays {
            guard let date = fmt.date(from: entry.date) else { continue }
            let parts = calendar.dateComponents([.month, .day], from: date)
            var target = calendar.date(from: DateComponents(year: year, month: parts.month, day: parts.day)) ?? now
            if target < calendar.startOfDay(for: now) {
                target = calendar.date(byAdding: .year, value: 1, to: target) ?? target
            }
            let d = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: target).day ?? 0
            if d < nearestDays { nearestDays = d; nearestName = entry.name }
        }
        name = nearestName.isEmpty ? localized("无", "none") : nearestName
        days = nearestDays
    }

    override func apply() {
        metric.value = name
        metric.subValue = days == 0 ? localized("今天", "today") : localized("\(days) 天", "\(days)d")
        metric.valueColor = days == 0 ? TB.gold : TB.textPrimary
        metric.iconTint = days <= 7 ? TB.gold : TB.pink
    }
}
