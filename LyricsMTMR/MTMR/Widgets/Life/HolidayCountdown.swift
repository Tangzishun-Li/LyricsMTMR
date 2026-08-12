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
        var name: String    // 两遍式：先空名建窗，窗口成型后统一判定
        let start: Date
        var end: Date       // 并窗合并时扩展
    }

    /// 由 "yyyy-MM-dd" 日期集合推导假期窗口：连续日期合并为同一窗口，结果按首日升序。
    /// 非法键（无法解析为日期）静默跳过；空集合返回空数组。
    /// 假期名在窗口**完整成型后**统一判定（两遍式）：名字依赖整窗特征（是否含 1/1、10/1），
    /// 单遍边合并边取名会把「窗口是否跨月/是否含锚点」这类信息提前丢失。
    static func makeWindows(dates: Set<String>, calendar: Calendar) -> [Window] {
        var result: [Window] = []
        for key in dates.sorted() {
            guard let date = Self.date(fromKey: key, calendar: calendar) else { continue }
            if var last = result.last, Self.isNextDay(date, after: last.end, calendar: calendar) {
                last.end = date
                result[result.count - 1] = last
            } else {
                result.append(Window(name: "", start: date, end: date))
            }
        }
        for i in result.indices {
            result[i].name = Self.holidayName(window: result[i], calendar: calendar)
        }
        return result
    }

    /// 假期名判定（**窗口特征**，第 18 轮健壮化）：基于窗口日期集合的特征而非仅首日月份，
    /// 对跨月/重叠窗口（未来年份随 aShareHolidays 年度维护加入）健壮。判定优先级自上而下
    /// 首个命中：
    /// 1. 窗口含 1/1 → 元旦——覆盖 12/30、12/31 开始的跨年窗口（如国办 2023-12-30~2024-01-01），
    ///    旧「首日月份」映射对 (12,_) 首日会误回退「节假日」；
    /// 2. 窗口含 10/1 → 国庆节——10/1 为国庆锚点；中秋+国庆合并窗口（如 2020-10-01~10-08）亦以
    ///    国庆命名，旧映射无法区分 10 月首日的中秋与国庆；
    /// 3. 首日 12 月 → 元旦——12 月末跨年窗口双保险（国办历年无其他 12 月法定假期）；
    /// 4. 首日 10 月 → 中秋——中秋落 10 月初的独立窗口（如 2028-10-03 中秋，窗口 10/3~10/5，
    ///    未含 10/1 故不命中 2），旧映射会误判「国庆节」；
    /// 5. 首日 2 月 → 春节；
    /// 6. 首日 4 月 → 清明；首日 5 月 → 劳动节；首日 6 月 → 端午；
    /// 7. 首日 9 月 → 中秋；
    /// 8. 首日 1 月下旬（≥1/20）→ 春节——春节最早除夕约 1/20（正月初一最早 1/21），
    ///    元旦窗口至多 1/1~1/3，两者间隔安全，用日期边界而非「(1,...3) vs (1,_)」隐含惯例；
    /// 9. 其余 → 节假日——含 1 月中旬空档（元旦窗口后、春节最早前）与未知月份，宁缺毋滥不猜测。
    /// 元旦/清明/劳动/国庆按公历固定；春节/端午/中秋为农历，随 aShareHolidays 年度维护同步核对
    /// （2026/2027 现有数据映射结果 100% 不变，见 HolidayCountdownTests）。
    static func holidayName(window: Window, calendar: Calendar) -> String {
        let start = calendar.startOfDay(for: window.start)
        let end = calendar.startOfDay(for: window.end)
        let startMonth = calendar.component(.month, from: start)
        let startDay = calendar.component(.day, from: start)
        let containsJan1 = Self.contains(month: 1, day: 1, from: start, to: end, calendar: calendar)
        let containsOct1 = Self.contains(month: 10, day: 1, from: start, to: end, calendar: calendar)

        if containsJan1 { return "元旦" }
        if containsOct1 { return "国庆节" }
        switch (startMonth, startDay) {
        case (12, _):    return "元旦"
        case (10, _):    return "中秋"
        case (2, _):     return "春节"
        case (4, _):     return "清明"
        case (5, _):     return "劳动节"
        case (6, _):     return "端午"
        case (9, _):     return "中秋"
        case (1, 20...): return "春节"
        default:         return "节假日"
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

    /// 窗口（start...end 闭区间，均已对齐到当日 00:00）内是否包含某月某日。
    /// 窗口最长约 10 天，逐日扫描代价可忽略；跨年/跨月窗口（如 12/30~1/1）天然正确。
    private static func contains(month: Int, day: Int, from start: Date, to end: Date, calendar: Calendar) -> Bool {
        var cursor = start
        while cursor <= end {
            if calendar.component(.month, from: cursor) == month,
               calendar.component(.day, from: cursor) == day {
                return true
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { return false }
            cursor = next
        }
        return false
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
