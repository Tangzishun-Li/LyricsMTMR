//
//  HolidayCountdown.swift  ·  item type: holidayCountdown
//  节假日倒计时：复用 StockBarItem.aShareHolidays（2026 国办发明电〔2025〕7 号 + 2027 预估）
//  作为**唯一数据源**（不复制日期表，不修改 StockBarItem 语义），展示距下一个法定节假日
//  首日的天数与假期名；假期窗口内显示「X 第 N 天」。窗口推导 / 假期名映射 / 天数计算
//  全部收敛在 HolidayCountdownLogic 纯函数（可单测），widget 仅负责展示。
//  属性：refreshInterval（默认 3600，见 ItemsParsing decode）。
//

import Cocoa

// MARK: - 纯逻辑（可单测）

/// 节假日倒计时纯逻辑：由 aShareHolidays 日期集合推导假期窗口、映射假期名、计算天数。
/// 日期一律按 Asia/Shanghai 时区、粒度到天（与 StockBarItem 交易日历同一时区口径）。
enum HolidayCountdownLogic {

    /// 一个假期窗口：名称 + 首日 + 末日（均为当日 00:00 的 Date，闭区间）。
    struct Window: Equatable {
        let name: String
        let start: Date
        var end: Date   // 并窗合并时扩展
    }

    /// 由 "yyyy-MM-dd" 日期集合推导假期窗口：连续日期合并为同一窗口，结果按首日升序。
    /// 非法键（无法解析为日期）静默跳过；空集合返回空数组。
    static func makeWindows(dates: Set<String>, calendar: Calendar) -> [Window] {
        var result: [Window] = []
        for key in dates.sorted() {
            guard let date = Self.date(fromKey: key, calendar: calendar) else { continue }
            if var last = result.last, Self.isNextDay(date, after: last.end, calendar: calendar) {
                last.end = date
                result[result.count - 1] = last
            } else {
                let name = Self.holidayName(startMonth: calendar.component(.month, from: date),
                                            startDay: calendar.component(.day, from: date))
                result.append(Window(name: name, start: date, end: date))
            }
        }
        return result
    }

    /// 假期名映射：按窗口首日的月份推导（1 月窗口按日期区分元旦/春节）。
    /// 国办历年安排中元旦/春节/清明/劳动节/端午/中秋/国庆的窗口首日固定落在
    /// 1/2/4/5/6/9/10 月；未知组合回退「节假日」。随 aShareHolidays 年度维护同步核对
    /// （2026/2027 数据全部命中，见 HolidayCountdownTests）。
    static func holidayName(startMonth: Int, startDay: Int) -> String {
        switch (startMonth, startDay) {
        case (1, ...3):   return "元旦"
        case (1, _):      return "春节"     // 未来年份春节窗口可能从 1 月下旬开始
        case (2, _):      return "春节"
        case (4, _):      return "清明"
        case (5, _):      return "劳动节"
        case (6, _):      return "端午"
        case (9, _):      return "中秋"
        case (10, _):     return "国庆节"
        default:          return "节假日"
        }
    }

    /// 某天是否落在假期窗口内；是则返回窗口与第几天（首日为第 1 天）。
    static func window(containing date: Date, in windows: [Window], calendar: Calendar) -> (window: Window, dayIndex: Int)? {
        let day = calendar.startOfDay(for: date)
        for w in windows {
            guard day >= w.start && day <= w.end else { continue }
            let idx = calendar.dateComponents([.day], from: w.start, to: day).day ?? 0
            return (w, idx + 1)
        }
        return nil
    }

    /// 今天之后最近的假期（首日严格晚于今天；今天已在假期内则由 window(containing:) 优先处理）。
    /// 返回窗口与距首日的天数（明天放假 = 1）；无后续假期返回 nil。
    static func nextHoliday(from date: Date, in windows: [Window], calendar: Calendar) -> (window: Window, daysUntil: Int)? {
        let day = calendar.startOfDay(for: date)
        for w in windows {
            guard w.start > day else { continue }
            let d = calendar.dateComponents([.day], from: day, to: w.start).day ?? 0
            return (w, d)
        }
        return nil
    }

    // MARK: - 内部工具

    /// "yyyy-MM-dd" → 当日 00:00（按传入日历/时区）。
    private static func date(fromKey key: String, calendar: Calendar) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// date 是否为 other 的次日（同一天粒度）。
    private static func isNextDay(_ date: Date, after other: Date, calendar: Calendar) -> Bool {
        guard let next = calendar.date(byAdding: .day, value: 1, to: other) else { return false }
        return calendar.isDate(date, inSameDayAs: next)
    }
}

// MARK: - Widget

class HolidayCountdownItem: TBPollItem {
    private var name = "…"
    private var sub = ""
    private var imminent = false

    init(identifier: NSTouchBarItem.Identifier, refreshInterval: Double) {
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "calendar", tint: TB.gold,
                   label: localized("假期", "Holiday"), width: 150)
    }
    required init?(coder: NSCoder) { return nil }

    override func compute() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        // 唯一数据源：StockBarItem.aShareHolidays（含 2026 官方 + 2027 预估），
        // 年度维护由 StockBarItem 表的既有机制负责，此处零拷贝。
        let windows = HolidayCountdownLogic.makeWindows(dates: StockBarItem.aShareHolidays, calendar: cal)
        let today = cal.startOfDay(for: Date())

        if let hit = HolidayCountdownLogic.window(containing: today, in: windows, calendar: cal) {
            name = "\(hit.window.name) 第 \(hit.dayIndex) 天"
            sub = localized("假期中", "holiday")
            imminent = true
        } else if let next = HolidayCountdownLogic.nextHoliday(from: today, in: windows, calendar: cal) {
            name = next.window.name
            sub = localized("\(next.daysUntil) 天", "\(next.daysUntil)d")
            imminent = next.daysUntil <= 7
        } else {
            // 数据表只覆盖到 2027-10-07（年度维护待国办通知后补 2028），此后无数据优雅降级
            name = localized("无假期", "none")
            sub = "—"
            imminent = false
        }
    }

    override func apply() {
        metric.value = name
        metric.subValue = sub
        metric.valueColor = imminent ? TB.gold : TB.textPrimary
        metric.iconTint = imminent ? TB.gold : TB.textTertiary
    }
}
