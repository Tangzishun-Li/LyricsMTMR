import XCTest
@testable import LyricsMTMR

/// 第 15 轮子任务 A：HolidayCountdown 纯逻辑（HolidayCountdownLogic）单元测试。
/// 数据源复用 StockBarItem.aShareHolidays 单一数据源（不复制日期表），
/// 覆盖：窗口推导 / 假期名映射 / 天数计算 / 跨年边界（2026→2027）/
/// 当天在假期内 / 数据表边界（2025 年前、2027-10-07 后）/ 空集合降级。
/// 第 18 轮子任务 A：假期名映射改为**窗口特征判定**（含 1/1→元旦、含 10/1→国庆、
/// 12 月首日→元旦跨年、10 月首日无 10/1→中秋、1 月下旬→春节），新增合成未来年份
/// 特征窗口单测（跨月/重叠），2026/2027 真实数据映射结果 100% 不变。
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

    // MARK: - 假期名映射（第 18 轮起为窗口特征判定）

    func testHolidayNameMapping() {
        // 窗口特征映射表：含 1/1 → 元旦（含 12 月末跨年窗口）；含 10/1 → 国庆节（含中秋+国庆合并）；
        // 12 月首日 → 元旦跨年；10 月首日（未含 10/1）→ 中秋（2028-10-03 中秋同构）；
        // 2 月 → 春节；1 月下旬（≥1/20）→ 春节；4/5/6/9 月 → 清明/劳动节/端午/中秋；
        // 1 月中旬空档与未知月份回退「节假日」。
        let cases: [(window: HolidayCountdownLogic.Window, expected: String)] = [
            (win(2026, 1, 1, 2026, 1, 3), "元旦"),      // 元旦窗口（含 1/1）
            (win(2028, 12, 30, 2029, 1, 1), "元旦"),    // 跨年窗口（12/30 起，含 1/1）
            (win(2026, 1, 28, 2026, 1, 30), "春节"),    // 1 月下旬（未来年份春节最早除夕 ~1/20）
            (win(2026, 2, 5, 2026, 2, 7), "春节"),
            (win(2026, 4, 4, 2026, 4, 6), "清明"),
            (win(2026, 5, 1, 2026, 5, 5), "劳动节"),
            (win(2026, 6, 19, 2026, 6, 21), "端午"),
            (win(2026, 9, 25, 2026, 9, 27), "中秋"),
            (win(2028, 10, 3, 2028, 10, 5), "中秋"),    // 中秋落 10 月初、未含 10/1（不误判国庆）
            (win(2026, 10, 1, 2026, 10, 7), "国庆节"),
            (win(2028, 10, 1, 2028, 10, 8), "国庆节"),  // 中秋+国庆合并窗口（含 10/1 → 国庆命名）
            (win(2028, 12, 29, 2028, 12, 31), "元旦"),  // 12 月末窗口（双保险分支）
            (win(2026, 3, 8, 2026, 3, 8), "节假日"),    // 未知月份回退
            (win(2026, 7, 1, 2026, 7, 1), "节假日"),
            (win(2028, 1, 10, 2028, 1, 11), "节假日"),  // 1 月中旬空档（元旦后、春节最早前）
            (win(2026, 11, 11, 2026, 11, 11), "节假日"),
        ]
        for c in cases {
            XCTAssertEqual(HolidayCountdownLogic.holidayName(window: c.window, calendar: bjCalendar),
                           c.expected, "窗口 \(c.window.start)~\(c.window.end)")
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

    // MARK: - 第 18 轮：跨月/重叠窗口健壮性（合成未来年份特征窗口）

    func testNewYearCrossYearWindowFromDecember30() {
        // 元旦跨年：窗口 12/30 起、跨年含 1/1（国办 2023-12-30~2024-01-01 同构），
        // 旧「首日月份」映射对 (12,_) 首日会误回退「节假日」
        let dates: Set<String> = ["2028-12-30", "2028-12-31", "2029-01-01"]
        let windows = HolidayCountdownLogic.makeWindows(dates: dates, calendar: bjCalendar)
        XCTAssertEqual(windows.count, 1)
        XCTAssertEqual(windows.first?.name, "元旦")
        XCTAssertEqual(windows.first?.start, bj(2028, 12, 30))
        XCTAssertEqual(windows.first?.end, bj(2029, 1, 1))
        // 跨年窗口内天数计算不受影响：1/1 为第 3 天
        XCTAssertEqual(HolidayCountdownLogic.window(containing: bj(2029, 1, 1), in: windows, calendar: bjCalendar)?.dayIndex, 3)
    }

    func testNewYearCrossYearWindowFromDecember31() {
        // 元旦跨年：窗口 12/31 起（国办 2022-12-31~2023-01-02 同构）
        let dates: Set<String> = ["2028-12-31", "2029-01-01", "2029-01-02"]
        let windows = HolidayCountdownLogic.makeWindows(dates: dates, calendar: bjCalendar)
        XCTAssertEqual(windows.count, 1)
        XCTAssertEqual(windows.first?.name, "元旦")
        XCTAssertEqual(windows.first?.start, bj(2028, 12, 31))
        XCTAssertEqual(windows.first?.end, bj(2029, 1, 2))
    }

    func testMidAutumnWindowStartingInOctober() {
        // 中秋落 10 月初（2028-10-03 中秋）：独立窗口 10/3~10/5，不得误判「国庆节」
        let dates: Set<String> = ["2028-10-03", "2028-10-04", "2028-10-05"]
        let windows = HolidayCountdownLogic.makeWindows(dates: dates, calendar: bjCalendar)
        XCTAssertEqual(windows.count, 1)
        XCTAssertEqual(windows.first?.name, "中秋")
        XCTAssertEqual(windows.first?.start, bj(2028, 10, 3))
        XCTAssertEqual(windows.first?.end, bj(2028, 10, 5))
    }

    func testNationalDayWindowStartingInOctober() {
        // 国庆 10/1 起 7 天（2026/2027 同构的未来年份）：含 10/1 → 国庆节
        let dates = Set((1...7).map { String(format: "2028-10-%02d", $0) })
        let windows = HolidayCountdownLogic.makeWindows(dates: dates, calendar: bjCalendar)
        XCTAssertEqual(windows.count, 1)
        XCTAssertEqual(windows.first?.name, "国庆节")
        XCTAssertEqual(windows.first?.start, bj(2028, 10, 1))
        XCTAssertEqual(windows.first?.end, bj(2028, 10, 7))
    }

    func testMergedMidAutumnNationalDayWindow() {
        // 中秋+国庆合并窗口（2020-10-01~10-08 结构）：含 10/1 → 以国庆命名
        let dates = Set((1...8).map { String(format: "2028-10-%02d", $0) })
        let windows = HolidayCountdownLogic.makeWindows(dates: dates, calendar: bjCalendar)
        XCTAssertEqual(windows.count, 1)
        XCTAssertEqual(windows.first?.name, "国庆节")
        XCTAssertEqual(len(windows.first!), 8)
    }

    func testSpringFestivalWindowStartingLateJanuary() {
        // 春节最早 1/21 前后：2028 春节 = 1/26，窗口 1/25（除夕）起 → 春节
        let dates: Set<String> = ["2028-01-25", "2028-01-26", "2028-01-27",
                                  "2028-01-28", "2028-01-29", "2028-01-30", "2028-01-31"]
        let windows = HolidayCountdownLogic.makeWindows(dates: dates, calendar: bjCalendar)
        XCTAssertEqual(windows.count, 1)
        XCTAssertEqual(windows.first?.name, "春节")
        XCTAssertEqual(windows.first?.start, bj(2028, 1, 25))
        XCTAssertEqual(windows.first?.end, bj(2028, 1, 31))
    }

    func testJanuaryMidMonthWindowFallsBackToGeneric() {
        // 1 月中旬（元旦窗口至多 1/3、春节最早除夕 ~1/20 之间）：宁缺毋滥回退「节假日」
        let dates: Set<String> = ["2028-01-10", "2028-01-11"]
        let windows = HolidayCountdownLogic.makeWindows(dates: dates, calendar: bjCalendar)
        XCTAssertEqual(windows.count, 1)
        XCTAssertEqual(windows.first?.name, "节假日")
    }

    func testDecemberWindowWithoutJan1MapsToNewYear() {
        // 12 月末窗口未含 1/1（国办实际安排必含 1/1，此为双保险分支）：仍判元旦
        let dates: Set<String> = ["2028-12-29", "2028-12-30", "2028-12-31"]
        let windows = HolidayCountdownLogic.makeWindows(dates: dates, calendar: bjCalendar)
        XCTAssertEqual(windows.count, 1)
        XCTAssertEqual(windows.first?.name, "元旦")
        XCTAssertEqual(windows.first?.start, bj(2028, 12, 29))
        XCTAssertEqual(windows.first?.end, bj(2028, 12, 31))
    }

    // MARK: - 工具

    /// 构造窗口（首日/末日，闭区间，name 占位由 holidayName 判定）。
    private func win(_ sy: Int, _ sm: Int, _ sd: Int, _ ey: Int, _ em: Int, _ ed: Int) -> HolidayCountdownLogic.Window {
        HolidayCountdownLogic.Window(name: "", start: bj(sy, sm, sd), end: bj(ey, em, ed))
    }

    /// 窗口天数（闭区间长度）。
    private func len(_ w: HolidayCountdownLogic.Window) -> Int {
        bjCalendar.dateComponents([.day], from: w.start, to: w.end).day! + 1
    }
}
