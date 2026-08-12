import XCTest
@testable import LyricsMTMR

/// 第 15 轮子任务 A：HolidayCountdown 纯逻辑（HolidayCountdownLogic）单元测试。
/// 数据源复用 StockBarItem.aShareHolidays 单一数据源（不复制日期表），
/// 覆盖：窗口推导 / 假期名映射 / 天数计算 / 跨年边界（2026→2027）/
/// 当天在假期内 / 数据表边界（2025 年前、2027-10-07 后）/ 空集合降级。
/// 所有日期按 Asia/Shanghai 时区构造（与 StockBarItem 交易日历同口径）。
class HolidayCountdownTests: XCTestCase {

    /// 北京时间（Asia/Shanghai）日历。
    private var bjCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return cal
    }

    /// 构造北京时间某日 00:00。
    private func bj(_ year: Int, _ month: Int, _ day: Int) -> Date {
        bjCalendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// 真实数据窗口（每次测试独立推导，防止测试间状态污染）。
    private func realWindows() -> [HolidayCountdownLogic.Window] {
        HolidayCountdownLogic.makeWindows(dates: StockBarItem.aShareHolidays, calendar: bjCalendar)
    }

    // MARK: - 窗口推导（真实数据）

    func testWindowsFromRealData2026() {
        let windows = realWindows().filter { bjCalendar.component(.year, from: $0.start) == 2026 }
        XCTAssertEqual(windows.count, 7, "2026 应有 7 个假期窗口")
        XCTAssertEqual(windows.map(\.name), ["元旦", "春节", "清明", "劳动节", "端午", "中秋", "国庆节"])
        XCTAssertEqual(windows.map { len($0) }, [3, 9, 3, 5, 3, 3, 7],
                       "2026 窗口长度：元旦3/春节9/清明3/劳动5/端午3/中秋3/国庆7")
    }

    func testWindowsFromRealData2027() {
        let windows = realWindows().filter { bjCalendar.component(.year, from: $0.start) == 2027 }
        XCTAssertEqual(windows.count, 7, "2027 应有 7 个假期窗口")
        XCTAssertEqual(windows.map(\.name), ["元旦", "春节", "清明", "劳动节", "端午", "中秋", "国庆节"])
        XCTAssertEqual(windows.map { len($0) }, [3, 8, 3, 5, 3, 3, 7],
                       "2027 窗口长度：元旦3/春节8/清明3/劳动5/端午3/中秋3/国庆7")
    }

    func testAllHolidayDatesCoveredByWindows() {
        // 表内每一天都必须落在某个窗口内（零丢失、零虚构），且窗口严格升序
        let windows = realWindows()
        let covered = windows.reduce(0) { $0 + len($1) }
        XCTAssertEqual(covered, StockBarItem.aShareHolidays.count, "窗口覆盖天数应等于表内日期总数")
        for i in 1..<windows.count {
            XCTAssertLessThan(windows[i - 1].start, windows[i].start, "窗口应按首日升序")
        }
        XCTAssertEqual(windows.first?.start, bj(2026, 1, 1))
        XCTAssertEqual(windows.last?.end, bj(2027, 10, 7))
    }

    // MARK: - 窗口推导（合成数据）

    func testConsecutiveDatesMergeIntoOneWindow() {
        let dates: Set<String> = ["2026-09-25", "2026-09-26", "2026-09-27"]
        let windows = HolidayCountdownLogic.makeWindows(dates: dates, calendar: bjCalendar)
        XCTAssertEqual(windows.count, 1, "连续日期应合并为同一窗口")
        XCTAssertEqual(windows.first?.name, "中秋")
        XCTAssertEqual(windows.first?.start, bj(2026, 9, 25))
        XCTAssertEqual(windows.first?.end, bj(2026, 9, 27))
    }

    func testGappedDatesStaySeparateWindows() {
        let dates: Set<String> = ["2026-01-01", "2026-01-03"]
        let windows = HolidayCountdownLogic.makeWindows(dates: dates, calendar: bjCalendar)
        XCTAssertEqual(windows.count, 2, "不连续的日期不应合并")
    }

    func testEmptySetYieldsNoWindows() {
        let windows = HolidayCountdownLogic.makeWindows(dates: [], calendar: bjCalendar)
        XCTAssertTrue(windows.isEmpty)
        XCTAssertNil(HolidayCountdownLogic.nextHoliday(from: bj(2026, 5, 6), in: windows, calendar: bjCalendar))
        XCTAssertNil(HolidayCountdownLogic.window(containing: bj(2026, 5, 6), in: windows, calendar: bjCalendar))
    }

    // MARK: - 假期名映射

    func testHolidayNameMapping() {
        let cases: [(month: Int, day: Int, expected: String)] = [
            (1, 1, "元旦"), (1, 3, "元旦"), (1, 28, "春节"),   // 1 月上旬=元旦，下旬=春节（未来年份）
            (2, 5, "春节"), (2, 15, "春节"),
            (4, 4, "清明"), (4, 5, "清明"),
            (5, 1, "劳动节"), (5, 5, "劳动节"),
            (6, 19, "端午"), (6, 7, "端午"),
            (9, 25, "中秋"), (9, 15, "中秋"),
            (10, 1, "国庆节"), (10, 7, "国庆节"),
            (3, 8, "节假日"), (7, 1, "节假日"), (11, 11, "节假日"),  // 未知组合回退
        ]
        for c in cases {
            XCTAssertEqual(HolidayCountdownLogic.holidayName(startMonth: c.month, startDay: c.day),
                           c.expected, "month=\(c.month) day=\(c.day)")
        }
    }

    // MARK: - 下一个假期（天数计算）

    func testNextHolidayBasic() {
        // 2026-05-06（劳动节后首日）→ 端午 2026-06-19，44 天
        let windows = realWindows()
        guard let next = HolidayCountdownLogic.nextHoliday(from: bj(2026, 5, 6), in: windows, calendar: bjCalendar) else {
            return XCTFail("应找到下一假期")
        }
        XCTAssertEqual(next.window.name, "端午")
        XCTAssertEqual(next.window.start, bj(2026, 6, 19))
        XCTAssertEqual(next.daysUntil, 44)
    }

    func testNextHolidayDayBefore() {
        // 2026-02-14（春节前一日，恰为调休补班日）→ 春节，1 天
        let windows = realWindows()
        let next = HolidayCountdownLogic.nextHoliday(from: bj(2026, 2, 14), in: windows, calendar: bjCalendar)
        XCTAssertEqual(next?.window.name, "春节")
        XCTAssertEqual(next?.daysUntil, 1)
    }

    func testNextHolidayCrossYear() {
        // 跨年边界：2026-10-08（国庆后首日）→ 2027 元旦，85 天
        let windows = realWindows()
        let next = HolidayCountdownLogic.nextHoliday(from: bj(2026, 10, 8), in: windows, calendar: bjCalendar)
        XCTAssertEqual(next?.window.name, "元旦")
        XCTAssertEqual(next?.window.start, bj(2027, 1, 1))
        XCTAssertEqual(next?.daysUntil, 85)
    }

    func testNextHolidayBeforeAllData() {
        // 数据表之前：2025-12-31 → 2026 元旦，1 天
        let windows = realWindows()
        let next = HolidayCountdownLogic.nextHoliday(from: bj(2025, 12, 31), in: windows, calendar: bjCalendar)
        XCTAssertEqual(next?.window.name, "元旦")
        XCTAssertEqual(next?.daysUntil, 1)
    }

    func testNextHolidayAfterLastDataIsNil() {
        // 数据表尽头（2027-10-07 之后）：无后续假期 → nil（widget 降级显示「无假期」）
        let windows = realWindows()
        XCTAssertNil(HolidayCountdownLogic.nextHoliday(from: bj(2027, 10, 8), in: windows, calendar: bjCalendar))
        XCTAssertNil(HolidayCountdownLogic.window(containing: bj(2027, 10, 8), in: windows, calendar: bjCalendar))
    }

    // MARK: - 当天在假期内

    func testInHolidayDayIndex() {
        // 春节窗口 2026-02-15~02-23：02-17 为第 3 天
        let windows = realWindows()
        let hit = HolidayCountdownLogic.window(containing: bj(2026, 2, 17), in: windows, calendar: bjCalendar)
        XCTAssertEqual(hit?.window.name, "春节")
        XCTAssertEqual(hit?.dayIndex, 3)
    }

    func testInHolidayLastDay() {
        // 02-23 为春节最后一天：第 9 天
        let windows = realWindows()
        let hit = HolidayCountdownLogic.window(containing: bj(2026, 2, 23), in: windows, calendar: bjCalendar)
        XCTAssertEqual(hit?.window.name, "春节")
        XCTAssertEqual(hit?.dayIndex, 9)
    }

    func testHolidayStartDayIsDayOne() {
        // 2026-10-01 国庆首日：第 1 天（且 nextHoliday 不应把当天窗口当作「下一个」）
        let windows = realWindows()
        let hit = HolidayCountdownLogic.window(containing: bj(2026, 10, 1), in: windows, calendar: bjCalendar)
        XCTAssertEqual(hit?.window.name, "国庆节")
        XCTAssertEqual(hit?.dayIndex, 1)
        let next = HolidayCountdownLogic.nextHoliday(from: bj(2026, 10, 1), in: windows, calendar: bjCalendar)
        XCTAssertEqual(next?.window.name, "元旦", "假期首日当天，下一假期应为之后的窗口")
        XCTAssertEqual(next?.daysUntil, 92)
    }

    func testDayAfterHolidayEndNotInHoliday() {
        // 2026-02-24：春节已结束 → 不在任何窗口；下一假期 = 清明 2026-04-04，39 天
        let windows = realWindows()
        XCTAssertNil(HolidayCountdownLogic.window(containing: bj(2026, 2, 24), in: windows, calendar: bjCalendar))
        let next = HolidayCountdownLogic.nextHoliday(from: bj(2026, 2, 24), in: windows, calendar: bjCalendar)
        XCTAssertEqual(next?.window.name, "清明")
        XCTAssertEqual(next?.daysUntil, 39)
    }

    // MARK: - 工具

    /// 窗口天数（闭区间长度）。
    private func len(_ w: HolidayCountdownLogic.Window) -> Int {
        bjCalendar.dateComponents([.day], from: w.start, to: w.end).day! + 1
    }
}
