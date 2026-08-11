import XCTest
@testable import LyricsMTMR

/// ITER-6 + ITER-8: isMarketOpen(at:) (StockBarItem.swift) 边界单元测试。
/// 节假日/补班断言不再手工复制锚点，改为从 StockBarItem 内
/// aShareHolidays / aShareMakeupDates 单一数据源生成（ITER-8）——
/// 表里新增或修订日期时测试自动覆盖，杜绝表与断言两处漂移；
/// 时间边界用例（9:15/11:30/13:00/15:00）与普通周末规则保留。
/// 所有日期按 Asia/Shanghai 时区构造。
class StockMarketHoursTests: XCTestCase {

    /// 构造北京时间（Asia/Shanghai）的指定日期时刻。
    private func bj(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    /// 北京时间日历（用于星期与次日推导）。
    private var beijingCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return cal
    }

    /// 解析表键 "yyyy-MM-dd" → (year, month, day)。
    private func parse(_ key: String) -> (year: Int, month: Int, day: Int)? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return (parts[0], parts[1], parts[2])
    }

    /// 表键在交易时段内（10:00）的时刻。
    private func atTradingTime(_ key: String) -> Date {
        let (y, m, d) = parse(key)!
        return bj(y, m, d, 10, 0)
    }

    /// 是否为周末（周六/周日）。
    private func isWeekend(_ date: Date) -> Bool {
        guard let weekday = beijingCalendar.dateComponents([.weekday], from: date).weekday else { return false }
        return weekday == 1 || weekday == 7  // Calendar.weekday: 1=周日, 7=周六
    }

    // MARK: - 周末

    func testRegularWeekendClosed() {
        // 2026-08-15 周六、2026-08-16 周日（非补班日，不在节假日表内）
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 8, 15, 10, 0)), "普通周六应休市")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 8, 16, 10, 0)), "普通周日应休市")
    }

    // MARK: - 调休补班（数据源：aShareMakeupDates，ITER-8）

    func testMakeupWeekendIsTradingDay() {
        // 遍历补班表全表：任一补班日在交易时段内（10:00）必须视为交易日
        XCTAssertFalse(StockBarItem.aShareMakeupDates.isEmpty, "补班表不应为空")
        for key in StockBarItem.aShareMakeupDates {
            XCTAssertTrue(StockBarItem.isMarketOpen(at: atTradingTime(key)),
                          "表内补班日应视为交易日: \(key)")
        }
    }

    func testMakeupDayStillRespectsSessionHours() {
        // 补班日只是“算交易日”，时段规则不变：午休与盘后仍休市（日期取自表内）
        guard let key = StockBarItem.aShareMakeupDates.sorted().first else {
            return XCTFail("补班表不应为空")
        }
        let (y, m, d) = parse(key)!
        XCTAssertTrue(StockBarItem.isMarketOpen(at: bj(y, m, d, 10, 0)), "补班日早盘应开市")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(y, m, d, 12, 0)), "补班日午休应休市")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(y, m, d, 15, 30)), "补班日收盘后应休市")
    }

    // MARK: - 法定节假日（数据源：aShareHolidays，ITER-8）

    func testHolidaysClosed2026Official() {
        // 2026 官方表（国办发明电〔2025〕7 号）全量遍历断言休市
        let keys = StockBarItem.aShareHolidays.filter { $0.hasPrefix("2026-") }
        XCTAssertFalse(keys.isEmpty, "2026 节假日表不应为空")
        for key in keys {
            XCTAssertFalse(StockBarItem.isMarketOpen(at: atTradingTime(key)),
                           "2026 表内节假日应休市: \(key)")
        }
    }

    func testHolidayWindowIncludesWeekend() {
        // 假期窗口内落在周末的日期也在表内并休市（整窗一致，不依赖周末规则兜底）
        let weekendKeys = StockBarItem.aShareHolidays.filter { key in
            guard let (y, m, d) = parse(key),
                  let date = beijingCalendar.date(from: DateComponents(year: y, month: m, day: d)) else { return false }
            return isWeekend(date)
        }
        XCTAssertFalse(weekendKeys.isEmpty, "节假日表应包含窗口内的周末日期")
        for key in weekendKeys {
            XCTAssertFalse(StockBarItem.isMarketOpen(at: atTradingTime(key)),
                           "假期窗口内的周末应休市: \(key)")
        }
    }

    func testHolidaysClosed2027Estimated() {
        // 2027 预估表（待国办 2026-11 通知核对）全量遍历断言休市
        let keys = StockBarItem.aShareHolidays.filter { $0.hasPrefix("2027-") }
        XCTAssertFalse(keys.isEmpty, "2027 节假日表不应为空")
        for key in keys {
            XCTAssertFalse(StockBarItem.isMarketOpen(at: atTradingTime(key)),
                           "2027 表内节假日应休市: \(key)")
        }
    }

    func testHolidayAfterWindowEndsReopens() {
        // 从表推导（无手工锚点）：假期窗口结束后的下一个普通工作日应开市
        var found = false
        for key in StockBarItem.aShareHolidays.sorted() {
            guard let (y, m, d) = parse(key),
                  let date = beijingCalendar.date(from: DateComponents(year: y, month: m, day: d)),
                  let next = beijingCalendar.date(byAdding: .day, value: 1, to: date) else { continue }
            let ny = beijingCalendar.component(.year, from: next)
            let nm = beijingCalendar.component(.month, from: next)
            let nd = beijingCalendar.component(.day, from: next)
            let nextKey = String(format: "%04d-%02d-%02d", ny, nm, nd)
            // 下一日为普通工作日（非周末、非节假日、非补班）→ 应开市
            if !isWeekend(next) && !StockBarItem.aShareHolidays.contains(nextKey)
                && !StockBarItem.aShareMakeupDates.contains(nextKey) {
                XCTAssertTrue(StockBarItem.isMarketOpen(at: bj(ny, nm, nd, 10, 0)),
                              "假期窗口结束次日应开市: \(key) → \(nextKey)")
                found = true
            }
        }
        XCTAssertTrue(found, "表中至少应有一个假期窗口后接普通工作日")
    }

    // MARK: - 数据源一致性（ITER-8 新增守卫）

    func testHolidayAndMakeupTablesDisjoint() {
        // 同一日期不可能既休市又补班
        let overlap = StockBarItem.aShareHolidays.intersection(StockBarItem.aShareMakeupDates)
        XCTAssertTrue(overlap.isEmpty, "节假日表与补班表不应重叠: \(overlap.sorted())")
    }

    // MARK: - 交易时段边界（2026-05-06 周三，普通交易日）

    func testCallAuctionStartsAtQuarterPastNine() {
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 5, 6, 9, 14)), "9:14 未到集合竞价，休市")
        XCTAssertTrue(StockBarItem.isMarketOpen(at: bj(2026, 5, 6, 9, 15)), "9:15 集合竞价起算交易")
    }

    func testMorningSession() {
        XCTAssertTrue(StockBarItem.isMarketOpen(at: bj(2026, 5, 6, 10, 0)), "早盘应开市")
    }

    func testLunchBreakBoundaries() {
        XCTAssertTrue(StockBarItem.isMarketOpen(at: bj(2026, 5, 6, 11, 29)), "11:29 仍在早盘")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 5, 6, 11, 30)), "11:30 午休开始，休市")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 5, 6, 12, 0)), "午休中，休市")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 5, 6, 12, 59)), "12:59 仍在午休，休市")
        XCTAssertTrue(StockBarItem.isMarketOpen(at: bj(2026, 5, 6, 13, 0)), "13:00 午后开盘")
    }

    func testAfternoonSessionCloseBoundary() {
        XCTAssertTrue(StockBarItem.isMarketOpen(at: bj(2026, 5, 6, 14, 59)), "14:59 尾盘仍交易")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 5, 6, 15, 0)), "15:00 收盘，休市")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 5, 6, 15, 30)), "收盘后休市")
    }

    func testBeforeOpenClosed() {
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 5, 6, 8, 0)), "盘前休市")
        XCTAssertFalse(StockBarItem.isMarketOpen(at: bj(2026, 5, 6, 9, 0)), "9:00 集合竞价前休市")
    }
}
